#!/usr/bin/env python3
"""GATT 服务表探针(电脑端,bleak)。

用途:连上设备,把它**实际暴露**的每个 service / characteristic / descriptor
连属性一起打出来,然后断开。只回答一个问题:「这台固件到底有哪几根特征」。

为什么要有电脑端这一份(手机端已有 tool/gatt_dump.dart):

- **不用编译、不用装 APK**。改一行跑一次是秒级的,排查时的反馈回路比
  `flutter run` 短得多,而且完全绕开了「上次编译的残留有没有进来」这个疑问。
- 它连 Flutter 和项目代码都不依赖,于是**与被测版本彻底无关** —— 手机端探针至少
  还要跟着某个 checkout 编出来,这份不用。查「旧版本能投屏、新版本不能」时,
  一个绝对不变的参照点很有用。

前提:电脑有蓝牙适配器,且设备**没有**被别的东西连着(手机 App 占着 GATT 时
这里连不上 —— GATT 连接是独占的,先把手机上的 App 退干净)。

跑法(项目根目录):

    python tool/gatt_dump.py                      # 扫名字含 eBadge 的第一台
    python tool/gatt_dump.py --name ""            # 不挑名字,列出全部再连第一台
    python tool/gatt_dump.py --list               # 只扫描列表,不连接
    python tool/gatt_dump.py --addr AA:BB:CC:DD:EE:FF   # 直连,跳过扫描
    python tool/gatt_dump.py --check              # 额外报一句投屏/命令通道能力判定

Windows 上地址是 MAC 形式;macOS 上 CoreBluetooth 给的是 UUID 形式的
address(系统不暴露 MAC),照抄 --list 打出来的那串即可。
"""

from __future__ import annotations

import argparse
import asyncio
import sys

try:
    from bleak import BleakClient, BleakScanner
except ImportError:
    sys.exit("缺少依赖:pip install bleak")


# 关心的几根特征 —— 只用于 --check 的能力判定,dump 本身不做任何匹配。
# 值取自 lib/services/ble_manager.dart 的同名常量。
STREAM_TX, STREAM_RX = "ffc4", "ffc5"          # 投屏:KS_OPEN/FRAME/CLOSE + ACK/CREDIT
COMMAND_TX, COMMAND_RX = "ffc1", "ffc2"        # 命令通道(L1):传图 / 配网 / 相机互控


def _props(char) -> str:
    """特征属性列表,原样照抄 bleak 给的顺序。"""
    return ",".join(char.properties) if char.properties else "none"


async def scan(name_filter: str, timeout: float, list_only: bool):
    """扫描并返回选中的设备;[list_only] 时只打印不选。"""
    hint = "不挑名字" if not name_filter else f"找名字含「{name_filter}」的"
    print(f"扫描中({hint},{timeout:g}s)…")

    # return_adv 拿到 AdvertisementData,顺带报 RSSI —— 信号太弱时连接失败率高,
    # 这个数能省掉一轮「为什么连不上」的猜测。
    found = await BleakScanner.discover(timeout=timeout, return_adv=True)
    if not found:
        print("✗ 一台设备都没扫到 —— 确认电脑蓝牙已开、设备在广播")
        return None

    picked = None
    for _addr, (dev, adv) in sorted(found.items(), key=lambda kv: -(kv[1][1].rssi or -999)):
        name = (adv.local_name or dev.name or "").strip()
        shown = name if name else "(无名)"
        mark = ""
        needle = name_filter.lower()
        hit = bool(name) if not needle else needle in name.lower()
        if hit and picked is None and not list_only:
            picked = dev
            mark = "  ← 选中"
        print(f"  · {shown:<24} {dev.address}  {adv.rssi:>4} dBm{mark}")

    if list_only:
        return None
    if picked is None:
        print("✗ 没有匹配的设备 —— 用 --name \"\" 看全部,或 --addr 直连")
    return picked


def dump_table(client: BleakClient, check: bool) -> None:
    """把整张 GATT 表打出来。

    **不做 UUID 匹配、不加角色标注**(除了显式要求的 --check):探针只如实报告
    设备暴露了什么。要不要认、认成什么,是 App 那边的事 —— 标注混进 dump 里,
    读的人就分不清哪部分是设备说的、哪部分是我们猜的。
    """
    services = list(client.services)
    chars = [c for s in services for c in s.characteristics]

    print("── GATT ────────────────────────────────")
    print(f"{len(services)} 个服务,{len(chars)} 个特征")
    for s in services:
        print(f"┌ service {s.uuid}  ({len(s.characteristics)} char)")
        for c in s.characteristics:
            print(f"│  char {c.uuid}  [{_props(c)}]")
            for d in c.descriptors:
                print(f"│    descriptor {d.uuid}")
        print("└")
    print("────────────────────────────────────────")

    if check:
        _report_capabilities(chars)


def _report_capabilities(chars) -> None:
    """按 App 的匹配规则复核两条通道是否齐全。

    规则刻意与 `BleManager.connect()` 保持一致(短 UUID **子串**匹配 + 属性要求)
    —— 这样这里的判定与 App 的 `streamAvailable` / `commandAvailable` 同真同假。
    子串匹配是故意的:eBadge 固件的命令通道在 `f48affc1/f48affc2` 上,正是靠
    `contains("ffc1")` 认出来的。
    """
    def find(needle: str, *, need_write=False, need_notify=False):
        for c in chars:
            if needle not in c.uuid.lower():
                continue
            p = set(c.properties)
            if need_write and not (p & {"write", "write-without-response"}):
                continue
            if need_notify and not (p & {"notify", "indicate"}):
                continue
            return c
        return None

    stx = find(STREAM_TX, need_write=True)
    srx = find(STREAM_RX, need_notify=True)
    ctx = find(COMMAND_TX, need_write=True)
    crx = find(COMMAND_RX, need_notify=True)

    print("── 能力判定(与 App 的匹配规则一致)────")
    print(f"命令通道 {COMMAND_TX.upper()}/{COMMAND_RX.upper()}(传图 / 配网 / 相机互控):"
          f"{'可用' if ctx and crx else '不可用'}")
    if ctx or crx:
        print(f"    tx = {ctx.uuid if ctx else '缺'}")
        print(f"    rx = {crx.uuid if crx else '缺'}")
    print(f"投屏流服务 {STREAM_TX.upper()}/{STREAM_RX.upper()}(KS_OPEN/KS_FRAME):"
          f"{'可用' if stx and srx else '不可用'}")
    if stx or srx:
        print(f"    tx = {stx.uuid if stx else '缺'}")
        print(f"    rx = {srx.uuid if srx else '缺'}")
    if not (stx and srx):
        print("    → 这台固件不具备独立流服务,「拍照投屏」的蓝牙投屏无法握手;")
        print("      App 会提示「未连接可投屏设备(需支持流服务 FFC4/FFC5)」。")
    print("────────────────────────────────────────")


async def main() -> int:
    ap = argparse.ArgumentParser(description="打印蓝牙设备的全部 GATT 服务")
    ap.add_argument("--name", default="eBadge",
                    help='按名字挑设备(子串,大小写不敏感);传 "" 表示不挑')
    ap.add_argument("--addr", default="",
                    help="直连这个地址,跳过扫描(Windows 为 MAC,macOS 为系统 UUID)")
    ap.add_argument("--timeout", type=float, default=10.0, help="扫描超时秒数")
    ap.add_argument("--list", action="store_true", help="只扫描列表,不连接")
    ap.add_argument("--check", action="store_true",
                    help="dump 之后额外判定投屏 / 命令通道是否齐全")
    args = ap.parse_args()

    if args.addr:
        target = args.addr
        print(f"直连 {target}(跳过扫描)")
    else:
        dev = await scan(args.name, args.timeout, args.list)
        if dev is None:
            return 0 if args.list else 1
        target = dev

    print("连接中…")
    try:
        # bleak 连上之后服务发现是自动完成的,client.services 直接可读。
        async with BleakClient(target, timeout=20.0) as client:
            print("✓ 已连接")
            dump_table(client, args.check)
    except Exception as e:  # noqa: BLE001 —— 探针要把任何失败原样报出来
        print(f"✗ 连接/读取失败:{type(e).__name__}: {e}")
        print("  常见原因:设备已被手机 App 连着(GATT 独占)、距离太远、"
              "或设备需要先配对")
        return 1
    print("已断开")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(asyncio.run(main()))
    except KeyboardInterrupt:
        print("\n已中断")
