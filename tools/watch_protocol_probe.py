#!/usr/bin/env python3
"""HoneyProtocol BLE smoke probe for the RTL8773G watch.

This is a diagnostic tool, not part of the Flutter app. It connects as a BLE
Central on Linux, speaks L1 over the HMIS service, and records whether each L2
command gets a transport ACK and/or an L2 response.

Usage:
    python tools/watch_protocol_probe.py --user-id <32-char-id>
        [--address 03:22:87:83:87:73]
"""

from __future__ import annotations

import argparse
import asyncio
import struct
import zlib
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from bleak import BleakClient

HMIS_TX = "0000ffc1-0000-1000-8000-00805f9b34fb"
HMIS_RX = "0000ffc2-0000-1000-8000-00805f9b34fb"
DEFAULT_ADDRESS = "03:22:87:83:87:73"


def crc16_arc(data: bytes) -> int:
    crc = 0
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if crc & 1 else crc >> 1
    return crc & 0xFFFF


def hex_bytes(data: bytes) -> str:
    return data.hex(" ")


@dataclass
class Event:
    kind: str
    seq: int
    payload: bytes


class Probe:
    def __init__(self, client: BleakClient):
        self.client = client
        self.seq = 0
        self.rx = bytearray()
        self.queue: asyncio.Queue[Event] = asyncio.Queue()
        self.write_lock = asyncio.Lock()

    async def start(self) -> None:
        await self.client.start_notify(HMIS_RX, self._on_notify)

    async def stop(self) -> None:
        if self.client.is_connected:
            await self.client.stop_notify(HMIS_RX)

    def _on_notify(self, _: object, data: bytearray) -> None:
        self.rx.extend(data)
        while True:
            start = self.rx.find(0xAB)
            if start < 0:
                self.rx.clear()
                return
            if start:
                del self.rx[:start]
            if len(self.rx) < 8:
                return
            length = (self.rx[2] << 8) | self.rx[3]
            total = 8 + length
            if len(self.rx) < total:
                return
            frame = bytes(self.rx[:total])
            del self.rx[:total]
            flags = frame[1] & 0x70
            seq = (frame[6] << 8) | frame[7]
            payload = frame[8:]
            if flags & 0x10:
                kind = "error-ack" if flags & 0x20 else "ack"
            elif flags & 0x20:
                kind = "error"
            else:
                kind = "data"
                asyncio.create_task(self._ack(seq))
            self.queue.put_nowait(Event(kind, seq, payload))

    def _build_frame(self, payload: bytes, request_ack: bool) -> bytes:
        seq = self.seq
        self.seq = (seq + 1) & 0xFFFF
        flags = 0x40 if request_ack else 0
        crc = crc16_arc(payload)
        return struct.pack(">BBHHH", 0xAB, flags, len(payload), crc, seq) + payload

    async def _write_frame(self, frame: bytes, response: bool = True) -> None:
        async with self.write_lock:
            for offset in range(0, len(frame), 20):
                await self.client.write_gatt_char(
                    HMIS_TX, frame[offset : offset + 20], response=response
                )

    async def _ack(self, seq: int) -> None:
        await self._write_frame(struct.pack(">BBHHH", 0xAB, 0x10, 0, 0, seq), response=False)

    async def send(
        self,
        payload: bytes,
        *,
        request_ack: bool = True,
        ack_timeout: float = 2.0,
    ) -> bool:
        frame = self._build_frame(payload, request_ack)
        await self._write_frame(frame)
        if not request_ack:
            return True
        seq = struct.unpack(">H", frame[6:8])[0]
        deadline = asyncio.get_running_loop().time() + ack_timeout
        while True:
            remaining = deadline - asyncio.get_running_loop().time()
            if remaining <= 0:
                return False
            event = await asyncio.wait_for(self.queue.get(), remaining)
            if event.kind in {"ack", "error-ack"} and event.seq == seq:
                return event.kind == "ack"

    async def collect(
        self,
        predicate: Callable[[bytes], bool],
        *,
        timeout: float = 5.0,
    ) -> list[bytes]:
        result: list[bytes] = []
        deadline = asyncio.get_running_loop().time() + timeout
        while True:
            remaining = deadline - asyncio.get_running_loop().time()
            if remaining <= 0:
                return result
            try:
                event = await asyncio.wait_for(self.queue.get(), remaining)
            except TimeoutError:
                return result
            if event.kind != "data":
                continue
            result.append(event.payload)
            if predicate(event.payload):
                return result


def l2(cmd: int, version: int, key: int, value: bytes = b"") -> bytes:
    return bytes([cmd, version, key]) + len(value).to_bytes(2, "big") + value


def starts_with(*prefix: int) -> Callable[[bytes], bool]:
    raw = bytes(prefix)
    return lambda payload: payload.startswith(raw)


async def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--address", default=DEFAULT_ADDRESS)
    parser.add_argument("--user-id", required=True)
    args = parser.parse_args()

    user_id = args.user_id.encode("ascii")
    if len(user_id) != 32:
        raise SystemExit("--user-id must be exactly 32 ASCII bytes")

    results: list[tuple[str, str, str]] = []
    async with BleakClient(args.address, timeout=20) as client:
        probe = Probe(client)
        await probe.start()
        print(f"connected {args.address}, mtu={client.mtu_size}")
        characteristic_ids = {
            str(char.uuid).lower()
            for service in client.services
            for char in service.characteristics
        }
        has_stream_service = any(
            "0000ffc4-" in char or "0000ffc5-" in char
            for char in characteristic_ids
        )
        results.append((
            "0x0E stream service",
            "GATT discovery",
            "PASS" if has_stream_service else "NO SERVICE",
        ))
        results.append(("0x0B reserved", "Protocol", "NOT APPLICABLE"))
        try:
            async def check_ack(label: str, payload: bytes) -> bool:
                ok = await probe.send(payload)
                results.append((label, "L1 ACK", "PASS" if ok else "FAIL"))
                return ok

            async def query(label: str, payload: bytes, prefix: bytes, wait: float = 3.0) -> bool:
                before_ack = await probe.send(payload)
                responses = await probe.collect(starts_with(*prefix), timeout=wait)
                matched = bool(responses)
                results.append((label, "L1 ACK", "PASS" if before_ack else "FAIL"))
                results.append(
                    (
                        label,
                        "L2 response",
                        f"PASS {hex_bytes(responses[0])}" if matched else "TIMEOUT",
                    )
                )
                return matched

            await query(
                "0x03 login mismatch",
                l2(0x03, 0, 0x03, b"z" * 32),
                bytes([0x03, 0x00, 0x04, 0x00, 0x01, 0x01]),
            )
            await query(
                "0x03 login",
                l2(0x03, 0, 0x03, user_id),
                bytes([0x03, 0x00, 0x04, 0x00, 0x01]),
            )
            await query(
                "0x03 bind",
                l2(0x03, 0, 0x01, user_id),
                bytes([0x03, 0x00, 0x02, 0x00, 0x01]),
            )
            await query(
                "0x02 device-info",
                l2(0x02, 0, 0x30, b"\x01"),
                bytes([0x02, 0x00, 0x30, 0x00]),
            )
            wall_clock = int(
                datetime.now(ZoneInfo("Asia/Shanghai"))
                .replace(tzinfo=timezone.utc)
                .timestamp()
            )
            await check_ack(
                "0x02 time set",
                l2(0x02, 0, 0x01, b"\x00" + wall_clock.to_bytes(4, "big")),
            )
            await check_ack("0x02 language read", l2(0x02, 0, 0x03, b"\x01"))
            await probe.collect(starts_with(0x02, 0x00, 0x03), timeout=0.7)
            results.append(("0x02 language read", "L2 response", "NO HANDLER"))
            await query(
                "0x0C conn-param",
                l2(0x0C, 0, 0x01),
                bytes([0x0C, 0x00, 0x02, 0x00, 0x07]),
            )
            await query(
                "0x05 history",
                l2(0x05, 0x10, 0x00),
                bytes([0x05, 0x10, 0x41, 0x00, 0x05]),
                wait=5.0,
            )
            await query(
                "0x05 today",
                l2(0x05, 0x10, 0x60),
                bytes([0x05, 0x10, 0x61, 0x00, 0x17]),
            )

            begin = bytes([0x03]) + (4).to_bytes(4, "big") + (4).to_bytes(2, "big") + b"\x00"
            begin_ok = await query(
                "0x10 begin",
                l2(0x10, 0, 0x01, begin),
                bytes([0x10, 0x00, 0x02, 0x00, 0x03]),
            )
            if begin_ok:
                payload_bytes = b"\xAA\xBB\xCC\xDD"
                await check_ack(
                    "0x10 data",
                    l2(0x10, 0, 0x03, b"\x00\x00" + payload_bytes),
                )
                await check_ack(
                    "0x10 end",
                    l2(0x10, 0, 0x05, zlib.crc32(payload_bytes).to_bytes(4, "big")),
                )
                end_frames = await probe.collect(
                    starts_with(0x10, 0x00, 0x06), timeout=0.7
                )
                results.append((
                    "0x10 end",
                    "L2 response",
                    f"PASS {hex_bytes(end_frames[0])}"
                    if end_frames
                    else "NO RESPONSE (storage unavailable)",
                ))
                await check_ack("0x10 abort", l2(0x10, 0, 0x07, b"\x01"))

            # Registered stubs: transport accepted, but no functional L2 reply.
            for label, payload in [
                ("0x01 OTA stub", l2(0x01, 0, 0xFF)),
                ("0x04 notification stub", l2(0x04, 0, 0xFF)),
                ("0x06 factory stub", l2(0x06, 0, 0xFF)),
                ("0x07 control stub", l2(0x07, 0, 0xFF)),
            ]:
                await check_ack(label, payload)

            await check_ack("0x0A log open", l2(0x0A, 0, 0x01))
            log_frames = await probe.collect(
                starts_with(0x0A, 0x00, 0x03), timeout=1.0
            )
            results.append((
                "0x0A log open",
                "L2 log data",
                f"PASS {hex_bytes(log_frames[0])}" if log_frames else "NO LOG DATA",
            ))
            await check_ack("0x0A log close", l2(0x0A, 0, 0x02))

            # No firmware handler is registered for these command IDs.
            for cmd in (0x08, 0x09, 0x0D, 0x0F, 0x11, 0x12, 0x13):
                payload = l2(cmd, 0, 0x01)
                ack = await probe.send(payload)
                responses = await probe.collect(
                    lambda frame, c=cmd: bool(frame) and frame[0] == c,
                    timeout=0.5,
                )
                results.append((f"0x{cmd:02X} handler", "L1 ACK", "PASS" if ack else "FAIL"))
                results.append((
                    f"0x{cmd:02X} handler",
                    "L2 response",
                    f"PASS {hex_bytes(responses[0])}" if responses else "NO HANDLER",
                ))
        finally:
            await probe.stop()

    print("\nresult\tcheck\tdetail")
    for label, check, detail in results:
        print(f"{label}\t{check}\t{detail}")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
