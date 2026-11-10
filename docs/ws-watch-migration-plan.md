# 手表工程迁移：连接、帧通信与 SDK 组合

> 2026-11-10 修订。JW / WS 两个 SDK 独立，拆分连接方式与当前共用的 L0/L1 帧通信；不再建立 `watch_core`。本文记录**目标边界、已落地结果与当前收尾态**（非仅计划草案）。

阅读顺序：第 1–6 节确定整体边界；第 7–12 节说明接口与各批迁移；第 13–16 节说明兼容、验收、回退和清单；§17–§19 为 T1–T3 实施记录；**§20 为 T4 与 Demo 当前态**。源码路径默认相对 HoneyBox 根目录。

**当前进度（2026-11）**：T1–T3 **已完成**（见 §17–§19）。**T4.0–T4.5 已在分支 `feat/ws-watch-sdk-skeleton` 交付主体能力**（`jw_watch_sdk` + `jw_watch_demo`，HoneyBox 已挂载 JW 入口）；JW SDK **接近完成**，后续以**真机观察与按需 bugfix** 为主。原码云 **T4.6 / T4.7 子任务已删除**（独立 example、全量切换不再单列里程碑，能力并入当前 Demo 与迭代验证）。**WS 侧 M1–M6 已废止**：`ws_watch_sdk` / `ws_watch_demo` 整包删除，**W5.1 Greenfield 自 JW 复制**（见 [ws-watch-implementation-plan.md §0](ws-watch-implementation-plan.md)）。WS M7 仍等固件；OTA/采集/七牛为并列工作流。Windows 等平台项按环境补验。

**码云总任务**：[【HoneyBox】【WS Watch SDK】基于 HoneyBox 搭建 Flutter SDK 与 Demo 工程（第一阶段）](https://e.gitee.com/priodigit/dashboard?issue=IKKGIB)（正文含 WS M1–M6 与下方主线/并列任务索引）。各批次对应 issue 见 §5、§12.1、§12.3。

## 1. 已确定的边界

正式协议只有两套：现有量产 JW，以及尚无正式固件的新 WS。旧 FFC Watch 是早期 WS 调试原型，不作为第三套产品协议长期维护。JW 行为对照 `../Cavo-Ble-SourceCode-Android/` Android SDK；Flutter 现有 JW 的覆盖范围仍需逐项核对。

```text
JW SDK                                WS SDK
JW L2 / 请求回应 / 业务 / 数据库        WS L2 / 请求回应 / 业务 / 数据库
JWHeartRate、JWBloodPressure            WSHeartRate、WSBloodPressure
       ↓ 组合所需帧通信与连接方式          ↓
            watch_frame_channel
      当前共用的 L0/L1，前 8 字节帧头
      帧队列 / 分片组包 / CRC / ACK / seq / 重传
                       ↓
                 watch_transport
        连接设备 / 发送字节 / 接收字节 / 断开
             ↙                       ↘
 watch_transport_ble        watch_transport_simulation
 真实 GATT 连接             内存连接 → 注入的模拟设备行为

后续可新增 UART / TCP transport，或另一种 frame channel 实现。
OTA 独立按需组合；采集 / 七牛 / 文件 / 平台工具属于调试应用。
```

JW、WS 当前 L0/L1 按同一套机制收敛，提取时用两套现有测试/抓包核对字节与时序。L2 完整字节由各 SDK 生成和解析。`watch_frame_channel` 不识别 command/key，也不解码健康数据；前 8 字节以外的数据作为不透明 payload，CRC 可覆盖这些字节但不解释其业务内容。

**健康数据模型与存储不进入公共依赖。** 两个 SDK 各自返回自己的公开数据类，拥有独立数据库、schema、身份与迁移策略；相同字段不要求继承公共健康数据类。保留现有 WS SQLite/身份、JW identity 与 history journal；不做跨 SDK 数据转换。应用若要统一展示，自行适配两个 SDK 的结果。

## 2. package 与依赖

| package | 职责与依赖 |
| --- | --- |
| `watch_transport` | 纯 Dart 最小连接/字节接口、目标/状态/错误模型；不依赖 FlutterBluePlus、帧协议或 SDK |
| `watch_transport_ble` | 实现 transport；BLE 扫描、连接、GATT/profile、订阅、MTU/写入上限、断连清理与设备资源协调；依赖 `watch_transport` 与 FlutterBluePlus，必要原生 BLE 桥随自身交付 |
| `watch_transport_simulation` | 实现 transport；虚拟设备发现、双向内存字节通道、连接生命周期、连接/写入失败及延迟/丢失等通用故障注入；依赖 `watch_transport`，不依赖 WS/JW 或其数据库 |
| `watch_frame_channel` | 当前共用 L0/L1 帧机制，依赖 `watch_transport`；不直接依赖 BLE/simulation，实现实例各自维护队列、seq、ACK 与组包状态 |
| `jw_watch_sdk`（**已有**） | JW L2、业务请求/回应匹配、设置/同步/测量/控制、公开模型与 `jw_watch.db`；组合公共帧通道与 BLE；不依赖 WS SDK |
| `ws_watch_sdk`（已有） | WS L2、业务请求/回应匹配、设置/同步、公开模型与存储；组合当前帧通道、BLE/simulation；不依赖 JW SDK |
| `watch_ota`（后续新增） | 独立升级核心与芯片后端；按需要使用 BLE 能力/原生厂商 SDK，不被迫经过 JW/WS 的日常帧协议 |
| `ws_watch_demo`（已有） | WS 专用示例和 Raw 联调；保持可独立运行，不强制引入 JW/七牛/采集 |
| `watch_lab_ui` | 共享 Watch Lab UI：传输诊断、能力页组件、JW transport 探针；WS/JW demo 与 HoneyBox 共用 |
| `jw_watch_demo`（**已有**） | **JW 完整 Demo**（连接、设置、数据首页与详情图表、控制/测量实验室等）；HoneyBox 日常真机走此包；`example/` 仍用于 path 依赖与集成测试 |
| `watch_debug_demo`（可选后续） | 若需 OTA/采集/七牛统一入口，可再合并进 Watch Lab 或独立 Tab；当前由 `watch_lab_ui` + 两 demo 包承担 |

初期只实现 BLE 与 simulation；UART/TCP 仅保留接口适配能力，不提前创建空包。SDK 默认组合由内部工厂提供，普通用户直接使用 JW 或 WS API；高级接入/测试可注入连接工厂。未来 WS 改 L0/L1 时新增独立帧机制实现，必要时调整 WS 内部 adapter，JW 继续使用当前实现，不把不兼容格式堆成一个大开关。

两个 SDK 可单独或同时依赖；共同依赖由 pub 解析到兼容版本。共用代码不等于共用会话：每条连接有独立的帧队列、序号与订阅。同一设备占用通过 BLE 资源协调，不同设备可并行。

## 3. transport 的精确定义

- 提供连接、发送字节、接收字节/断开事件和释放资源。`write` 完成表示底层写入完成，不表示 L0/L1 ACK 已收到，更不表示设备业务处理成功；接收不必与某次 write 一一对应，允许设备主动上报。
- transport connected 表示字节通道可用；SDK ready 要经过各自登录/绑定/初始化。自动业务重连由 SDK 策略驱动，transport 不在上层不知情时悄悄换一条连接。
- 同一份接口传递字节，不提供 L2 request/reply API。帧边界由 frame channel 识别；BLE 分片边界、TCP 读边界都不作为消息边界。
- 通用字段使用最大写入长度/能力，不把 MTU 作为所有 transport 的必填概念；BLE 实现据实际 MTU/平台限制计算上限，simulation 可配置上限来模拟小包。
- GATT 服务/特征、withResponse、BLE 权限/扫描属于 BLE 实现和配置；TCP/UART 不需要实现假的 GATT 或蓝牙扫描。设备发现可作为独立可选能力，连接接口本身不要求先扫描。
- 订阅在可能收到数据前建立；连接期间早到字节必须由 adapter 正确交付，不因切换 ready 状态静默丢弃。连接失败、取消、超时、dispose 与迟到回调均按连接代次清理。

BLE 的写入顺序/平台 API 约束由 adapter 保证；完整帧占用、ACK/seq、重传与帧级队列只在 frame channel 实现。L2 请求队列、回应匹配、业务超时继续由各 SDK 管理。

## 4. 如何整合现有模拟器

现有模拟器已经包含两个部分，迁移时保留这个边界：

| 当前实现 | 目标 |
| --- | --- |
| `SimWatchSession` 的 pair、prepare/write、received/disconnected、拷贝、释放和拦截投递 | 抽取到 `watch_transport_simulation`，去掉 WS 错误类型和固定 WS deviceId；通用连接不强制 BLE MTU 范围 |
| `SimWatchDevice` / `SimWatchState` 的绑定、语言/格式、历史同步及通知 | 继续归 WS SDK 的模拟设备实现，通过工厂注入 simulation 运行时；不让通用 simulation 包反向依赖 WS |
| 模拟设备当前内部使用 `WSLink` | frame channel 提取后，设备侧同样组合公共帧通道；WS L2 行为仍由模拟设备自己处理 |
| 丢 ACK、错误 ACK、迟到业务回应等脚本 | 原始字节丢失/延迟可由 simulation 注入；识别 ACK/业务命令的脚本属于帧测试或设备行为，通用 transport 不解析协议 |

实际路径仍然模拟完整设备通信：

```text
WS SDK → 主机帧通道 → simulation 主机端
                          ⇅ 双向字节
模拟 WS L2 ← 设备帧通道 ← simulation 设备端
```

模拟连接建立时由注入工厂创建设备端处理器；断开后关闭该次连接的计时器、订阅和待处理任务。设备绑定状态/设置可跨连接保留，连接和 seq 状态每次重新创建。设备主动上报也经同一字节路径返回，不直接完成 SDK 的业务 Future。

这样 `watch_transport_simulation` 确实承担“模拟连接设备并把数据交给模拟设备处理”，但协议行为是可插入的：初期接现有 WS 模拟设备，将来需要 JW 模拟设备时注册另一个行为即可。当前不承诺已实现 JW 模拟。

## 5. 迁移总览

| 批次 | 码云任务 | 交付与验收 |
| --- | --- | --- |
| **T1 连接抽象与 simulation** | [IKSKQV](https://e.gitee.com/priodigit/dashboard?issue=IKSKQV) | 新建 `watch_transport` / `watch_transport_simulation`，迁内存通道，WS 通过薄 adapter 接回现有 Link；默认身份/数据库/业务 API 不动。验证字节双向传输、主动推送、小包、断开/释放、跨重连设备状态，以及现有 WS M2–M6 回归（**已完成**，见 §17） |
| **T2 BLE transport** | [IKSKQX](https://e.gitee.com/priodigit/dashboard?issue=IKSKQX) | 新建 `watch_transport_ble`，提取已有真实连接能力、profile 和资源协调；迁 WS 真实扫描并提供真实连接 adapter，以现有 JW 真机做连接/命令冒烟。宿主/Capture/原生 OTA 的过渡入口加入同一设备占用协调；无 WS 固件时只验证 transport，不宣称完成 WS M7 |
| **T3 公共帧通道** | [IKSKQY](https://e.gitee.com/priodigit/dashboard?issue=IKSKQY) | 比对 JW/WS 当前 L0/L1，提取 `watch_frame_channel`，接两套 SDK 和 WS 模拟设备。验证前 8 字节、CRC/ACK/seq、重传/去重、跨分片、整帧不交错、断链清队列及双方现有行为（**已实现**，见 §19） |
| **T4 完整 JW SDK（主线）** | 总 [IKSKW1](https://e.gitee.com/priodigit/dashboard?issue=IKSKW1)，子任务 §12.1 | **T4.0–T4.5 已落地**（2026-11，见 §20）；独立 SDK、JW 数据库、设置/同步/测量/控制及 `jw_watch_demo`。非「搬目录即完成」；覆盖表缺口与型号差异仍按需补齐。**不再单列 T4.6/T4.7** |

实施顺序为 **T1 → T2 → T3 → T4.0–T4.5**（**T4.6/T4.7 已取消**，见 §12.1）。T1 只提取现有 simulation；T2/T3 使用 JW 真机验证；T4 在 `jw_watch_sdk` / `jw_watch_demo` 闭环。WS Link/Session 超时/重传在 T3 映射到公共实现，外部 API 保持兼容。

**WS M7 暂不作为近期交付目标**（跟踪 [IKSABE](https://e.gitee.com/priodigit/dashboard?issue=IKSABE)）。固件到位后，重点核对 WS UART/profile、L2/业务、能力与时序差异；JW 已验证的 transport/frame 基础可直接复用，但不能据此提前宣布 WS 真机已通过。并列业务不串在主线尾部，也不成为 T4 的验收前提，见第 12.3 节。

每批保留 root、SDK、Demo、example 回归；新增状态机/失败恢复测试和独立工程构建。Android/macOS/Windows 等只记录实际构建或实机结果，模拟通过不替代平台权限/GATT/固件验收。同事未迁模块继续在原目录开发，已迁模块只改 packages，并记录最后同步 commit。

## 6. 调试工具与原生能力归属

- Capture 是可配置 GATT 的多设备原始录制（含 Polar、重连、文件记录），不是健康数据库或协议 SDK 内置能力；七牛负责配置、文件、压缩上传和分享。这些归调试模块，使用公共 transport 或 SDK 观测 API。
- Windows BLE 调优目前注册在媒体插件内，提取到 BLE transport 时解除媒体依赖；不把 HoneyBox 的媒体/导航一起迁入。
- Realtek Dart DFU 与 Android AAR/桥归独立 OTA；升级支持按芯片/固件/profile 判断。超时不等于原生工作结束，停止核实前保留占用，正常模式→DFU→重连身份在升级事务内管理。
- 采集保活、文件导出、授权交互、窗口与应用壳归调试应用/工具插件；必要 BLE/OTA 原生注册跟随各自 package。不能笼统把“多平台”全部迁入 SDK。

### 6.1 调试 UI 单一来源（Watch Lab）

HoneyBox **JW Watch** 入口挂载 **`jw_watch_demo`**（连接向导、设置、数据、控制等完整流程）。**Watch Lab / `watch_lab_ui`** 仍承担扫描过滤、连接条与部分**传输/能力探针** UI，与 Demo 包分工而非重复造第二套业务 App。

| 包 | 职责 |
| --- | --- |
| `watch_lab_ui` | JW 扫描过滤、连接条、分组验收/探针组件 |
| `jw_watch_demo` | **主线 Demo**：`JWDemoController` + 设置/数据/测量/控制页；数据首页顶区对齐 `docs/jw-data-home-header-prototype.html` v0.4 |
| `ws_watch_demo` | WS SDK 能力页；Hub 第二按钮（WS Lab） |
| HoneyBox | `jw_watch_demo` path 依赖 + JW 入口路由 |

各 package 的 `example/` 与 `watch_transport_ble/example` 仍用于 **path 依赖、CI 与 BLE/帧 smoke**；**业务与设置/同步验收以 `jw_watch_demo` + 真机为主**。

## 7. 目标目录与依赖方向

```text
packages/
  watch_transport/
    lib/watch_transport.dart
    lib/src/{connection,target,state,errors,limits}.dart
    test/
  watch_transport_ble/
    lib/watch_transport_ble.dart
    lib/src/{adapter,connection,scanner,profile,coordinator}/
    test/
    example/                         最小连接诊断应用
    windows/                         需要自有 BLE 调优桥时加入
  watch_transport_simulation/
    lib/watch_transport_simulation.dart
    lib/src/{connection,pair,device_registry,runtime,faults}/
    test/
  watch_frame_channel/
    lib/watch_frame_channel.dart
    lib/src/{frame,codec,assembler,channel,queue,config,events}/
    test/{vectors,channel,assembler}/
  jw_watch_sdk/                         # 已存在：connection/settings/history/measure/control/today/storage
    lib/jw_watch_sdk.dart
    lib/src/{connection,settings,history,measure,control,today,storage,model,capability,debug}/
    test/
  jw_watch_demo/                        # 已存在：完整 JW Demo UI
    lib/src/
    test/
  ws_watch_sdk/                       保留现有包，按批次替换内部基础实现
    lib/src/simulation/               保留 WS 设备行为及场景
  watch_ota/
    lib/watch_ota.dart
    lib/src/{core,profiles,backends,storage}/
    android/                         厂商 AAR 与 Flutter plugin
    test/
  ws_watch_demo/                      保留现有 WS 页面与 example
  watch_debug_demo/
    lib/watch_debug_demo.dart
    lib/src/{jw,ota,capture,qiniu,files,platform}/
    example/
```

目录为目标示意，按能力实际迁入时创建；不要求所有类型各占一个文件。所有包放在同一 pub workspace，包内禁止相对路径跨出 package。基础包的运行时代码保持纯 Dart；当前 workspace 的测试统一使用 `flutter test`（测试工具版本约束说明见第 17 节），各自声明实际直接依赖。

依赖必须单向：`transport` 不知道任何实现；`frame_channel` 只知道 transport 接口；BLE/simulation 不知道 frame channel 与 SDK；SDK 组合具体连接实现与帧通道。模拟设备行为可以依赖 frame channel，但所在 WS SDK 不得被 simulation 包反向依赖。OTA 的厂商后端可自行管理物理连接，同时参与 BLE 占用协调，无须强行适配日常帧格式。

两套 SDK 的公开默认入口保持简单。首次提取允许内部薄 adapter 兼容既有 API；稳定后才公开明确的连接工厂注入入口，不把 FlutterBluePlus 类型、WS 内部 zone key 或一大组底层开关变成应用必须理解的参数。

## 8. transport 接口与生命周期约定

以下为接口草案，T1 落地时以类型检查与测试确定签名，语义先固定：

```dart
abstract interface class WatchTransportConnection {
  WatchDeviceTarget get target;
  WatchTransportState get state;
  Stream<WatchTransportState> get stateChanges;
  Stream<Uint8List> get received;
  Stream<WatchDisconnectEvent> get disconnected;
  WatchWriteLimits get writeLimits;

  Future<void> connect();
  Future<void> write(Uint8List bytes);
  Future<void> disconnect();
  Future<void> dispose();
}
```

连接由对应 transport 工厂按其类型化配置创建。连接对象先创建、再订阅事件、最后调用 connect；不采用“connect 返回后才有接收流”的接口，以便捕获初始化期间早到字节。发现设备是独立能力：BLE scanner 扫广播，simulation registry 列虚拟设备；UART/TCP 可以直接使用端点连接。

### 8.1 目标与状态

- target 至少区分 transport kind 与端点 ID，BLE 的 OS deviceId 保持不透明；同名 simulation 不得与真实设备混为同一连接目标。SDK 的数据库设备身份仍由各 SDK 自己定义，不能直接换成临时连接 ID。
- 单次连接对象按 `idle → connecting → connected → disconnecting → disconnected` 运行；失败包含阶段与原因，dispose 是最终状态。需要重连时创建新连接对象，原对象不复活。
- connect 阶段内部可包含系统连接、GATT 发现、profile 校验与通知订阅；只有字节链路可用才 connected。SDK 在其后再执行登录/绑定/初始化进入 ready。
- transport 错误中立化，如 connect/timeout/disconnected/write/profileUnavailable/unsupported；SDK adapter 映射回现有 JW/WS 错误类型与阶段，不在公共包中 import `WSException`。

### 8.2 数据与结束语义

- `write` 不等待帧 ACK，不替业务回应配对。接收字节可能分片、粘连、先于 write Future 完成，也可能是设备主动推送；frame channel 必须独立订阅处理。
- 数据在接收边界复制或不可变封装，调用者修改源数组不能改变已排队/已投递数据；不依赖 broadcast stream 保存无人订阅时的字节。
- 初期约定每条连接一个协议消费者；观测流可多订阅，但观测回调不能阻塞或改变通信语义。若需初始化缓冲，容量与溢出错误必须明确，不能无限缓存或静默丢弃。
- `writeLimits` 描述实际单次写入能力，BLE 根据平台/MTU/特征计算；simulation 独立配置。限制发生变化时，新分片应使用最新有效值，不能持有过期 MTU 继续写。
- disconnect/dispose 幂等；主动、意外断开均结束待执行写操作，disconnected 每次连接最多发一次。dispose 完成后无后续数据，关闭订阅/流并释放底层资源。
- 超时/取消后若系统连接迟到成功，必须断开迟到连接并释放对应租约；旧连接清理不得取消新连接的通知或扫描。

### 8.3 三种排队分别归谁

| 排队内容 | 所在层 | 等待完成的含义 |
| --- | --- | --- |
| 平台 write/read/订阅操作中必须串行的部分 | BLE adapter | 对应平台操作完成；不会自动追加 seq 或重发业务帧 |
| 整帧发送与 ACK/重传 | frame channel | 当前帧达到既定链路确认结果；帧的分片不可与其他帧交错 |
| 设置读取、同类回应匹配、同步事务 | JW/WS Session 与业务层 | 收到预期 L2 回应或完成业务事务；数据库提交/设备确认属于此层 |

## 9. simulation 提取细则（T1 · [IKSKQV](https://e.gitee.com/priodigit/dashboard?issue=IKSKQV)）

### 9.1 从现有代码迁移

1. 从 `packages/ws_watch_sdk/lib/src/simulation/sim_watch_session.dart` 提取内存 pair 与通用字节逻辑；替换 WS 专用错误与固定 deviceId，保留字节复制和拦截投递的能力。
2. 让现有 `WSTransportConnection` adapter 包装新连接，暂时不动 WS Link/Session；`connection/environment.dart` 与 `simulation/simulation_runtime.dart` 只改装配，测试注入仍可用。
3. `SimWatchDevice`、`SimWatchState` 留在 WS SDK。注册表中的端点由设备工厂附加到 peer；工厂 attach 完成后主机才连接成功，避免请求先于设备处理器建立。
4. 默认 WS simulator ID、显式开关、Demo 扫描显示及既有行为保持兼容；通用 simulation 包没有“默认 WS 设备”。SDK 注册自己的设备工厂后才出现该设备。
5. 一个虚拟设备默认只允许一个独占主机会话；多个虚拟设备可并行。物理设备状态由设备实例持有，连接计时器/seq/待发任务属于单次会话。

### 9.2 故障注入位置

| 故障 | 承担者 |
| --- | --- |
| 连接失败/超时、连接延迟、底层 write 抛错、断开 | simulation transport |
| 原始字节延迟、丢弃、拆分/合并、损坏 | simulation 字节投递脚本；保持双向独立配置 |
| 指定 seq 丢 ACK、ERR ACK、重传相同帧 | frame channel 测试对端/脚本，识别帧语义 |
| 拒绝绑定、迟到语言回应、历史条数不符/取消 | WS 模拟设备与 SDK 场景测试，识别 L2 业务 |

随机故障若存在必须可设种子；自动测试主要用确定性脚本。延迟/重排必须由配置明确触发，正常 simulation 保持字节顺序。断开时取消旧任务，不能在新连接中投递旧回应；状态持久性只保留设备模型，不保留旧链路缓存。

### 9.3 T1 交付与退出条件

- 两个新基础包可独立运行测试，不依赖 HoneyBox、JW/WS 或数据库。
- simulation 与薄 adapter 的契约测试覆盖字节双向/主动上报、写入上限、数组拷贝、失败、幂等清理、并行设备、旧代次隔离。
- WS M2–M6 原有测试及独立 Demo 的扫描连接→Raw→历史同步脚本保持通过，身份/数据库路径和内容不因提取改变。
- 首次提取不同时改 WS L2 编码、模拟数据或超时默认值，以便失败时能定位到 transport 替换。

## 10. BLE transport 接入细则（T2 · [IKSKQX](https://e.gitee.com/priodigit/dashboard?issue=IKSKQX)）

### 10.1 提取清单

| 来源 | 提取内容 | 保留原归属 |
| --- | --- | --- |
| `lib/services/ble_manager.dart` | 真实扫描/连接、服务发现、订阅、写入、断连清理的通用部分 | EBadge/导航/投屏业务分支、协议初始化不整块搬入 |
| `ble_gatt_profile.dart` | 特征描述、连接 generation/publish/retire 思路 | FFC1/2/4/5 固定选择规则属于原型/宿主 profile |
| `ble_mtu.dart` | MTU 合法范围、平台实际协商值与单次写入能力 | `(MTU-3)-13` 等投屏载荷公式不作通用规则 |
| `ble_write_queue.dart` | 平台操作串行与断连使旧任务失效 | 整帧 ACK 队列归 frame channel；投屏 pacer/calibrator 按实际用途保留 |
| SDK `scanner.dart` | WS 真实扫描部分改为公共 BLE 结果适配 | WS 模拟设备合并、业务过滤与 DTO 仍由 SDK 组织 |
| `services/jw/jw_scan_policy.dart` | 通用 BLE 广播字段可复用 | JW 候选判断、固件筛选与匹配策略保留在 JW |
| `ble_link_tuning.dart` + `windows/media/` BLE 通道 | BLE 调优桥、自动注册与构建声明 | 媒体插件/编码播放器留 HoneyBox |

BLE profile 通过配置明确服务 UUID、收/发特征、属性与写入模式。JW 使用 Realtek FF 服务，WS 使用 UART profile；不能自动尝试写两套协议来识别设备。JW 标准服务 read/Immediate Alert 等旁路能力仍可通过 BLE adapter 的扩展端口提供，不把 GATT read 方法强塞进所有通用连接接口。

### 10.2 资源与权限

- BLE runtime 内共享扫描协调器和设备租约管理器；默认实例在同一运行环境内复用，宿主显式注入时所有入口使用同一实例。协调器不是协议 Session 单例。
- 开始连接前原子获取设备租约，扫描接管与取消按 owner/generation 校验；旧扫描 stop 不能停止新 owner 的扫描。
- 过渡期 HoneyBox 普通连接、Capture、Dart DFU、Android native OTA 同时接入协调；仅检查 `isConnected` 无法避免并发竞争。不能迁完新包却让旧入口绕开占用。
- OTA 在正常与 DFU 标识切换时保留事务占用；平台明确要求全局排他时使用更大范围租约，普通双设备连接不默认全局互斥。
- 权限/蓝牙关闭由 BLE adapter 返回明确状态；授权弹窗、跳系统设置与文案由 Demo/宿主负责。Android Manifest、iOS/macOS plist、桌面蓝牙依赖在独立 example 中配置。
- plugin detach、连接失败、主动断开与意外断开均核对资源释放；原生 OTA 若仍运行，不能仅因 Dart Future 超时释放物理设备。

### 10.3 T2 交付与退出条件

- 假平台后端验证连接各阶段失败、通知早到、MTU 变化、写入失败、连接取消与迟到成功、旧清理不影响新连接、同设备竞争/双设备并行。
- 使用现有 JW 设备完成扫描、连接、已有命令收发和断连重连冒烟；这不等于要求在 T2 实现 JW 新功能或 WS 固件业务。
- BLE 最小 example 离开 HoneyBox 能连接并观察字节；Android/macOS 构建通过，Windows 原生桥在实际 Windows 环境验收。其他平台只有实际验证后才声明支持。
- WS 仍可完整使用 simulation；WS 实际 UART transport 可装配但没有固件时不以模拟通过宣布 M7 完成。

## 11. 公共帧通道提取细则（T3 · [IKSKQY](https://e.gitee.com/priodigit/dashboard?issue=IKSKQY)）

### 11.1 当前 8 字节帧头

| 偏移 | 长度 | 当前含义 |
| --- | --- | --- |
| 0 | 1 | 起始标记 `0xAB` |
| 1 | 1 | flags：ACK / ERR / 部分现有代码支持的 no-ACK 标志 |
| 2 | 2 | 不透明 payload 长度，大端 |
| 4 | 2 | payload CRC-16/ARC，大端存放；算法 reflected `0xA001`，init/xorout 为 0 |
| 6 | 2 | seq，大端，范围 0–65535 |

本节描述核实到的实现，不把它定义为所有未来协议都必须使用的格式。帧通道 API 围绕 `send(payload)`、收到 payload 的事件、帧观测与关闭/终止组织；发送需要在等待 ACK 前登记 pending，ACK 与主动上报可随时到达，不能被等待 L2 回应的任务阻塞。

### 11.2 需要保留的现有差异

| 项目 | 当前源码情况 | 提取策略 |
| --- | --- | --- |
| 长度限制 | JW `JwCodec` 总帧上限 244，WS payload 上限默认 65535 | 参数化实际限制，JW 不因公共层上限变大就发送更长业务帧；L2 自身长度校验留 SDK |
| flags | JW codec 有 `noAck` 位 `0x40`，WS 当前头校验只接受 data/ACK/ERR ACK | 按已确认的协议 profile 限定合法 flags，不默认替 WS 开启 no-ACK |
| 默认超时/重试 | JW ACK 3 秒/2 次；WS ACK 5 秒/3 次 | 由 SDK 映射既有配置，先保持默认值；统一代码不要求统一产品参数 |
| 回应证明收包 | JW `JwSession` 当前把匹配 L2 回应视作收包证据，即使 ACK 迟到 | 判断留在 JW；公共层提供有限的在途发送确认接口，由 JW 传入其已知的发送句柄，不能把 command/key 判断下沉。WS 不自动采用该规则 |
| 去重与错误 | 两份实现的容量/时间窗和错误传播存在差异；JW 当前 CRC 错误直接丢弃，WS assembler 可在可信 seq 下发 ERR ACK | 列出行为对照与测试后再替换；通过已确认 profile 保留策略，不凭“头格式一样”改变设备交互 |

发送句柄的提前确认只能结束当前对应帧等待，并校验连接代次；不能让任意业务消息确认下一帧。若对照测试发现帧级差异超出合理配置范围，先保留 SDK adapter，记录未统一项；保持同一协议族公共实现方向，不以增加全局开关掩盖不兼容。

### 11.3 队列、分片与恢复规则

- 一次发送序号只分配一次，重传使用相同 seq；连接代次变化后清空 pending/缓存，不接收旧 ACK。序号回绕行为以现有测试及固件约束核对。
- 按 transport 有效写入上限分片；任何帧的头与 payload 分片不可与另一个帧交错。控制 ACK 在当前帧写完后的安全边界及时发送，不被业务回应等待锁住。
- 收到重复数据帧仍按协议回 ACK，但 payload 不重复交付；去重缓存必须有容量/时效界限，不按 L2 数据库规则去重。
- CRC 错误只有在头与 seq 可信时按协议回复错误；损坏/未知头、超长长度、组包超时均有清理规则和缓冲上限。
- 部分帧写出后失败/取消，不继续在同一字节流拼接后续帧；终止或重建连接以恢复确定边界。关闭时所有排队/等待 ACK 的 Future 都完成为失败，不能悬挂。
- 公开观测保留收发帧、重试、seq、错误、连接代次；SDK 再追加 L2 名称与 trace。日志过滤/暂停/导出不得改变真实收发。

### 11.4 T3 交付与退出条件

- 从 `src/link/{frame,frame_assembler,link}.dart` 与 JW codec/session 的 L0/L1 部分提取公共实现；JW codec 的 L2 TLV 与 WS protocol 全部保留在各自 SDK。
- 使用独立字节向量核验 8 字节头、大小端、CRC、flags 与长度，再用两份既有测试回归；模拟客户端与设备共用编码器不能作为唯一正确性证据。
- 覆盖 ACK 早到/迟到/丢失、ERR ACK、重传、重复数据、seq 回绕、粘包/拆包、噪声头、最大长度、队列溢出、半帧写失败与断开清理。
- 主机和模拟设备都接公共帧通道，WS M2–M6 与 JW 已有命令/同步行为不变；默认超时及公开错误通过 adapter 兼容。

## 12. T4 主线：完整 JW SDK 与真机验证

码云总任务：[IKSKW1](https://e.gitee.com/priodigit/dashboard?issue=IKSKW1)（【HoneyBox】【WS Watch SDK】JW SDK 完整实现与真机验收（T4））。

JW Flutter SDK 以 `packages/jw_watch_sdk` 交付，对照 Android `UkProtocolLibary` V2 与量产真机；**不是**把 `lib/services/jw/` 原样搬包即结束。接口、数据库、Measure 透明缓存等细则见 [JW SDK 专项实施计划](jw-watch-sdk-implementation-plan.md)（含 §8.0）。**§20** 记录当前落地与初稿差异。

### 12.1 阶段拆分（T4.0–T4.5；T4.6/T4.7 已取消）

| 阶段 | 码云任务 | 交付内容 | 当前态（2026-11） |
| --- | --- | --- | --- |
| **T4.0 能力基线与 API** | [IKSKR0](https://e.gitee.com/priodigit/dashboard?issue=IKSKR0) | 覆盖表、`JWWatch` 门面与公开类型 | 已建表并随实现更新 |
| **T4.1 真机连接与包闭环** | [IKSKR2](https://e.gitee.com/priodigit/dashboard?issue=IKSKR2) | `jw_watch_sdk` 组合 T1–T3；扫描/连接/身份/ready | **已交付**；经公共 BLE + frame channel |
| **T4.2 设置与设备配置** | [IKSKR4](https://e.gitee.com/priodigit/dashboard?issue=IKSKR4) | 设置 codec、通讯录等主要配置项 | **主体已交付**；缺口按覆盖表/issue 补 |
| **T4.3 JW 模型与数据库** | [IKSKR5](https://e.gitee.com/priodigit/dashboard?issue=IKSKR5) | `jw_watch.db` + 类型化历史表 | **已交付**；与 WS 库隔离 |
| **T4.4 历史同步闭环** | [IKSKR7](https://e.gitee.com/priodigit/dashboard?issue=IKSKR7) | 同步→写库→确认→查询；异步写队列 | **已交付**；Demo 数据首页与同步 UX 见 §20 |
| **T4.5 测量、控制与通知** | [IKSKR9](https://e.gitee.com/priodigit/dashboard?issue=IKSKR9) | 点测/自动控制/控制实验室等 | **主体已交付**；心率 auto measure **透明缓存**先落地 |

**已取消（码云删除）**：**T4.6** 独立 example 收口、**T4.7** 全量宿主切换——改为 **`jw_watch_demo` 在 HoneyBox 内迭代 + 多轮真机联调**；宿主 `lib/services/jw/` 仍可能并存作过渡，**不以单独里程碑阻塞 JW SDK 收尾**。

依赖：**T4.0→T4.1→T4.2/T4.3→T4.4/T4.5**。Demo UI 从 T4.1 起随阶段叠加，最终集中在 `jw_watch_demo`，而非最后再建 T4.6 工程。

### 12.1.1 与初稿设计的主要差异

| 主题 | 初稿/旧迁移叙述 | 当前约定 |
| --- | --- | --- |
| Demo 收口 | T4.6 独立 `watch_debug_demo` + T4.7 宿主切换 | **`jw_watch_demo` 即主 Demo**；调试 smoke 保留在 BLE `example` / 集成测试 |
| Measure 读配置 | 部分叙述隐含「每次 read 都打设备」或可 `forceRefresh` | **§8.0 透明缓存**：会话内 merge 主动上报；不完整才 pull；**无** `forceRefresh`；重连清空 |
| 数据首页 | 步数目标环或同步坞长说明 | **v0.4**：标题下说明+条数+进度；KPI 仅单位；同步无「等计划」单独 UI |
| T4 完成定义 | T4.7 才宣布切换 | **T4.5 后主路径可用**；剩余为覆盖表缺口与 bugfix，见总任务 [IKKGIB](https://e.gitee.com/priodigit/dashboard?issue=IKKGIB) |

### 12.2 范围与数据库决定

- 目标覆盖现有 Android JW SDK 的有效能力，不限于当前 Flutter 已实现的子集。历史/废弃功能是否排除必须在覆盖表说明依据；待确认项保持未完成，不静默缩小范围。
- JW 对外返回自己的类型，如 `JWHeartRate` / `JWBloodPressure`；数据库采用 JW 自己的 drift/SQLite schema，初始名 `jw_watch.db`。复用的是 SQLite/drift 技术，不是 WS 的模型、表、实体或 migration。T4.3 的最终保留类型、联合主键和表字段见 [JW Watch SDK 数据库存储设计](jw-watch-database-design.md)。
- `jw_watch.db` 是全新数据库，不读取、迁移或兼容旧 `jw_history/v1` journal、旧数据库或 WS 数据库。T4.4 完成后生产主路径必须走 JW 数据库。JW 数据库不保存 raw 帧、批次/确认/隔离/上传日志。
- WS M2–M6 只做受影响回归，不为等待固件新建一整套模拟开发主线。T4 的 JW 真机会检验底层 BLE、队列、ACK、seq、重传与真实持久化；WS 固件到位后再验证自身协议差异。

### 12.3 并列业务：不占用 JW 主线里程碑

| 码云任务 | 交付 | 与主线的真实依赖 |
| --- | --- | --- |
| [IKSKRC](https://e.gitee.com/priodigit/dashboard?issue=IKSKRC) OTA 固件升级 | `watch_ota` 核心、Dart DFU、Android 厂商桥与 AAR；固件 profile、升级预检、进度、恢复/重连版本验证；UI 后续组合 | 只依赖公共 BLE/设备占用协调及必要芯片后端，不依赖 JW 数据库或 T4 全部完成 |
| [IKSKRD](https://e.gitee.com/priodigit/dashboard?issue=IKSKRD) 多设备 BLE 原始数据采集 | 多设备原始录制、Polar、重连续录、后台保活、文件导出及独立工具 UI | 依赖公共 transport/资源协调或 SDK 观测；不依赖健康数据库，不能另抢 SDK 已有连接 |
| [IKSKRG](https://e.gitee.com/priodigit/dashboard?issue=IKSKRG) 七牛云配置与采集文件上传 | 凭据配置、云端文件管理、压缩上传、取消与分享 | 云/文件工作流可独立；上传采集记录时依赖稳定的记录文件接口，不依赖 JW/WS 协议 |

三条工作流按实际需求独立安排，不能成为宣布 JW SDK **第一阶段可用**的阻塞项。JW 真机页面由 **`jw_watch_demo`** 承载；`watch_debug_demo` 仍为可选后续统一调试壳，**非 T4 关单前置**。

## 13. 数据、文件与兼容策略

| 现有资产 | 本轮约束 |
| --- | --- |
| WS `ws_watch.db`、schema v2、默认用户 ID | 保持文件路径、schema 与 SDK 语义；基础通信提取不触发重建数据库或换身份 |
| JW identity 文件、`jw_history/v1` | 不作为新 SDK 的运行时依赖或迁移源；新 SDK 仅使用宿主登录传入的 userID 与当前连接 MAC |
| `capture_profiles.json`、`capture_scan_settings.json`、`captures/*/raw.jsonl`、`device.json` / `upload.json` | 工具迁移保留格式读取与续录行为；独立 App 沙箱通过显式导出/导入，不假设能直接读取 HoneyBox 私有目录 |
| `ota_history/*.json`、`active.json` | 保留升级记录与脱敏；启动时先核对原生是否仍在运行，不自动重放升级命令 |
| SecureStorage `honeybox.qiniu.config.v1` | 同 App 可兼容旧 key；新 App/不同安全存储空间支持重新配置或显式导入，不能默认为可跨应用读取 |

不双写两套设备历史确认/游标，不为迁移启动自动删旧数据。确需路径/格式转换时单独提交：只读源、临时目标、校验、原子提交、导入记录；失败可重试，保留源文件。凭据和默认身份不出现在普通日志中。

## 14. 验证矩阵与独立接入

| 层次 | 必须提供的证据 |
| --- | --- |
| transport 契约 | 同一组基础用例跑 simulation 与 BLE 假后端：收发、主动上报、状态、失败/断开、拷贝、写入限制和释放 |
| frame channel | 独立规范/抓包向量、确定性故障测试、JW/WS 两套回归，不以两端同实现互测替代独立向量 |
| SDK | T4 以 Android JW 覆盖表逐项实现并真机验证；WS 保持已有回归。各自 protocol/session/连接/身份/设置/同步/存储隔离，支持两 SDK 独立及同时接入 |
| Demo | 原有 WS Widget 测试、独立 example 模拟连接→Raw→同步脚本；统一工具另测多设备与文件/云工作流 |
| 平台构建 | Android/macOS 与可用环境的 Windows/iOS/Linux 分别记录；必要 plugin 在独立 example 自动注册 |
| 实机 | T2/T3 做 JW BLE/命令冒烟，T4 做完整连接/设置/同步/测量/控制/通知及数据库验收；OTA/采集各自验收，WS 固件到位后再做 M7 |
| 外部接入 | workspace 外的最小工程分别只接 JW、只接 WS、同时接两者；按需加入 OTA。pub 依赖/平台声明/插件注册不能靠 HoneyBox 根配置补齐 |

新增纯 Dart 包执行 analyze，当前测试入口使用 `flutter test`；Flutter 包执行 analyze/test，根 workspace analyze 作为整体检查。CI 显式运行每个 package 的测试，不能假设根 `flutter test` 自动覆盖子包。基础阶段不改数据库生成代码；涉及后续 schema 变化时再运行对应生成一致性检查。

现有测试位置可直接作为迁移起点：WS `test/link/link_test.dart`、`test/session/session_test.dart`、`test/sim/*`、M3–M6 用例；根 `test/services/jw/jw_codec_test.dart`、`jw_session_test.dart`、`jw_raw_channel_test.dart` 与配置/历史/健康测试；`test/services/ble_manager_jw_ownership_test.dart`；独立 Demo `integration_test/m6_simulator_script_test.dart`。此清单表示可复用测试来源，不宣称本轮新包已经验证通过。

## 15. 提交、协作与回退

1. 每批先补可重复行为证据，再提取/替换。纯文件移动、接口 adapter、新功能与错误修正分开提交，便于定位回归与同步同事增量。
2. 每次切换记录旧路径、新路径、最后同步 commit、受影响入口、测试及待实机项；迁完的模块只在 package 修改，旧宿主实现删除或变为薄 adapter。
3. T1 回退只替换 WS transport 装配；T2 按整个连接入口回退 BLE backend；T3 按整个连接栈回退，不能两套帧通道同时监听/ACK 同一连接。回退前结束当前连接与待执行任务。
4. 旧实现仅在有明确回退需要的过渡批次保留；不无限期维护双实现。不将旧目录的新改动凭手工记忆同步，切换前核对源 commit 到当前的增量。
5. 迁移不包含对外发布 SDK 或清理用户历史数据。T1–T3 与 **`jw_watch_sdk` / `jw_watch_demo` 已存在**；JW T4 **进入收尾与 bugfix**，独立工具工作流自行安排；WS M7 仍不阻塞 JW 收尾。

## 16. 首次实施任务清单

T1–T3 与 T4 主体已按下列及 §20 推进；无需等待 WS 固件。T1 清单（已完成）：

- [x] 建立 `watch_transport` 的连接、目标、状态、写入限制与错误契约。
- [x] 建立 `watch_transport_simulation`，提取双向内存通道、现有 WS 设备工厂/注册及必要确定性故障钩子；不新增 JW 模拟设备。
- [x] 添加契约/生命周期测试，验证断开后无旧任务投递、双设备隔离、主动上报与写入失败。
- [x] 为现有 WS Link 添加薄 transport adapter，改 environment/runtime 装配；WS 设备行为留在原 SDK。
- [x] 保留模拟 ID、显式开关、默认身份/数据库和现有外部 API；验证所有 WS/Demo 回归。
- [x] 将两个新包加入 workspace、CI 与接入文档，完成单独依赖/测试验证。
- [x] 交付 T1 变更清单与实测结果，再按第 10 节开始 BLE 提取及 JW 真机冒烟。


## 17. T1 实施记录（2026-11-03 · [IKSKQV](https://e.gitee.com/priodigit/dashboard?issue=IKSKQV)）

### 17.1 本轮落地

- `watch_transport`：纯 Dart 连接/目标/状态/中立错误/写入限制契约，单次连接对象，先订阅再连接。
- `watch_transport_simulation`：双向字节 pair、设备注册及注入工厂、独占租约、会话清理、有限的无人订阅缓冲、确定性字节拦截钩子。默认注册表为空；设备状态由注入工厂保留，重连使用新 pair。
- WS 内部 `WSByteTransportAdapter` 保留原有 transport/error 接口；`SimWatchSession` 成为薄兼容层，environment 与 M2 runtime 接入新注册工厂。
- WS 模拟设备行为、Link/Session/L2、模拟 ID、身份和 SQLite 保留在 SDK；没有新增 JW 模拟设备、BLE 包或 frame channel 包。
- 两个基础包已加入 workspace/CI，包内 README 提供独立使用示例与生命周期说明。

### 17.2 已执行验证

- 新基础包：`watch_transport` 2 项、simulation 12 项；另新增 WS adapter 1 项，全部通过。
  覆盖双向字节/主动推送、小写入上限、数组隔离、顺序写入与失败恢复、断开取消在途与排队写入、无人订阅溢出、回调关闭、同设备独占/双设备并行、跨重连设备状态、迟到 attach/超时及清理失败释放租约。
- 既有回归：root 1065 项通过、2 项原有跳过；WS SDK 原有 130 项、Demo 13 项、example 1 项通过。
- Android 独立 example debug APK 构建通过；macOS 独立 example 构建与 M6 集成脚本通过：扫描/连接、Raw 请求、历史同步及持久化。
- 独立纯 Dart 消费工程直接通过 path 引用两个真实包，`dart pub get`、analyze、连接/echo/释放运行通过；解析依赖中没有 Flutter。
- workspace analyze 与改动格式检查通过。以上是本机 Flutter 3.47.5 / Dart 3.13.4 的实测，CI 配置已更新但尚未远端执行。

### 17.3 工具与边界

当前 Flutter 固定的 `test_api` / matcher 与工作区代码生成工具所需 analyzer 无法同时解析可用的 `package:test`，因此两个新包只在开发依赖中使用 `flutter_test`，CI 在各包目录执行 `flutter test`。没有添加 dependency override 或更改数据库生成依赖；库本身的运行时依赖仍是纯 Dart。

接收缓冲的 64 KiB 限制针对无人订阅期间；已暂停订阅的缓存由 Dart stream 管理，协议消费者须持续消费。取消/超时不能强制终止工厂的任意外部 Future，迟到行为句柄会被释放，关闭端点不会再投递字节。

下一步按 T2 提取 BLE transport，以 JW 真机验证真实连接与原始字节收发，再进入 T3 公共帧通道；本轮模拟回归不作为任何真实固件验收结论。


## 18. T2 实施记录（2026-11-03 · [IKSKQX](https://e.gitee.com/priodigit/dashboard?issue=IKSKQX)）

### 18.1 实际交付

- 新建 `watch_transport_ble`：中立广播 DTO / scanner、可注入平台 backend、类型化 GATT profile、真实 FlutterBluePlus adapter、单次连接对象、动态 MTU/写入限制、接收缓冲、通知订阅及清理。
- 平台写队列、MTU 协商和连接参数调优已迁入 BLE 包；HoneyBox 旧路径保留薄转导出。投屏帧开销、pacer/calibrator、导航及 JW 业务仍留宿主，未整块搬动 BleManager。
- `WatchBleCoordinator.shared` 为同 isolate 的合作入口共享租约；不同设备可并行，同设备在原生 connect 前占用。连接取消/超时立即结束调用者等待，但清理要等待迟到平台操作结束并确认断开，之后才释放；清理失败保留租约并允许重试。
- HoneyBox 普通连接、Capture 及其配置扫描、OTA 版本/设备探测、Dart DFU、Android native OTA 接入同一协调器。DFU 事务保留正常态 ID 并追加 DFU/重启 ID；Android native OTA 使用全局排他，只有原生 close 确认成功才释放，不因超时或 busy 关闭失败而释放。
- 扫描采用带 owner 的 token，连接主动撤销旧扫描，旧 token 重复清理不停止新 owner。平台 stop 失败保留预留，可显式重试。
- WS scanner 的真实广播改为公共 scanner 适配，模拟设备合并与 DTO 保持在 WS；默认连接工厂增加 UART profile，BLE 错误映射回原有 WS connect/error 类型。
- **（T2  interim）** `watch_transport_ble/example` 内实现了完整「BLE 连接诊断」UI 与 JW smoke；用于 CI/外部接入与真机脚本，**尚未按 §6.1 迁入 HoneyBox 可挂载的 Demo 库**（与 `ws_watch_demo` 模式不一致，属已知遗留）。诊断字节/帧逻辑在 example 组织，不引入 HoneyBox/JW/WS SDK 或数据库。
- Windows WinRT 调优工作线程、地址解析和 MethodChannel 已从媒体插件迁出，由 BLE 包自有插件自动注册；媒体插件不再注册 BLE 通道。地址解析有独立 CMake/CTest，Dart 通道绑定有测试。

### 18.2 实测结果

- 本机 Flutter 3.47.5 / Dart 3.13.4，workspace analyze 与全仓 Dart 格式检查通过。全仓检查发现既有 Demo `demo_home.dart` / `demo_raw_sheet.dart` 格式差异，已仅按 formatter 统一排版，不改逻辑。
- BLE 假平台/协调器/调优测试 29 项通过；新增宿主原生 OTA 占用边界 2 项通过，原有 BleManager JW 旧连接不干扰替换连接的测试继续通过并增加公共租约断言。
- root 1067 项通过、原有 2 项跳过；WS SDK 131 项、Demo 13 项、example 1 项通过；WS 独立 macOS M6 扫描/模拟连接→Raw→历史同步集成脚本通过。
- 回归过程曾在并行构建期间出现一项既有 Widget 的 `pumpAndSettle` 超时，单文件及后续完整 root 重跑均通过；WS macOS 脚本首次停留，终止后以原脚本重新运行通过，没有修改用例或放宽断言。
- 新诊断 example：Android debug APK、macOS 原生应用构建通过。独立消费工程不使用 HoneyBox workspace/override，直接依赖真实 BLE package 的 pub get 与测试通过。
- 用户指定 **GHW-01D**，使用 Mac 内置蓝牙实测：扫描到目标，连续两轮创建新连接，均成功校验 Realtek FF profile、协商 MTU 247、订阅 FF03、经 FF02 发送 `02/4f` 语言查询并收到 CRC 正确的 `02/50` 回应（语言编码 1），标准 Battery Service `180f/2a19` 读到 52%，每轮结束释放后可再次连接。
- 真机脚本位于 `example/integration_test/jw_ble_smoke_test.dart`，指定 `--dart-define=BLE_DEVICE_ID=<当前平台ID>` 执行。多候选不自动挑选其他设备；未登录/绑定或修改设置/历史/固件。
- 初次使用 OTA BWPS 电量命令在该固件上只收到 ACK，无业务回应；核对旧 Android JW SDK 后改为标准 Battery Service，并另用语言读请求验证完整通知回应。该差异仅影响诊断用例，不将 BWPS 不支持解释为 transport 失败。
- BLE 原生地址解析独立 CMake/CTest 通过；这不是 Windows WinRT 插件编译或调优效果的验收结果。CI 已加入 BLE 包测试，远端 CI 尚未运行。

### 18.3 边界与后续

Windows plugin 的自动注册、独立 CMake 与源码已交付，但当前只有 Mac 环境，**Windows 编译、真实扫描/连接与调优效果待实测**；Android 本轮只有构建，没有手机连接验收。WS 无正式固件，UART 装配不等于 M7 完成。

SDK/宿主均不使用共享租约自动接管其他应用已经连接的设备。协调器限同 isolate 的合作入口；自定义 runtime 必须统一注入，不能声称跨进程锁住系统蓝牙。OTA/Capture 本轮接入资源管理，没有将整个模块搬入 SDK，也未执行升级或采集验收。

下一主线为 T3 公共 L0/L1 帧通道。继续使用 JW 真机检查 ACK/seq/重传/分片/旧代次隔离，随后进入 T4 完整 JW SDK 和独立数据库，不增加模拟器业务投入。


## 19. T3 实施记录（2026-11-03 · [IKSKQY](https://e.gitee.com/priodigit/dashboard?issue=IKSKQY)）

### 19.1 实际交付与依赖

新建纯 Dart `packages/watch_frame_channel`，运行时只依赖 `watch_transport`。
公开入口包括 `WatchFrame` / `WatchFrameAssembler`、`WatchFrameChannel`、配置、错误、
payload/帧观测、发送句柄与 `WatchFramePort`。`fromConnection` 适配公共 transport；
回调 port 允许旧连接复用现有租约，不重复连接或订阅 GATT。

- WS `frame.dart` / `frame_assembler.dart` / `link.dart` 成为兼容 adapter，保留原有类型、
  配置、异常、generation/requestId/traceId 与原始事件时间；主机和 `SimWatchDevice`
  经同一个 adapter 使用公共实现。WS 不使用业务回应提前确认。
- 现有 JW `JwCodec` 的 CRC/帧编码、`JwFrameDecoder` 的增量解码改用公共实现；
  `JwSession` 将 ACK、seq、重试、分片/控制队列和去重交给 channel。
  L2 TLV、串行业务队列、回应匹配/超时、未匹配 key 分流、健康数据和存储仍留 JW。
- JW 在 L2 确认匹配后调用 `confirmReceived`；句柄只确认本连接当前在途发送，
  不允许确认其他连接、排队或已结束的发送。先收到 NACK 后同轮收到真实回应仍能证明收包，
  但不能掩盖平台 write 失败。公共层不包含 JW command/key 判断。
- BLE 独立 example 的语言探针移除自写 CRC/帧解析与 ACK，使用公共 channel。
  真机集成脚本再注入 5 字节写入上限和一次丢 ACK，只发送语言读请求。
- 新包加入 workspace 与 CI 单独测试步骤；SDK、宿主和 BLE example 声明直接依赖。
  各包边界和 API/生命周期示例见 [watch_frame_channel README](../packages/watch_frame_channel/README.md)。

### 19.2 行为对照与恢复边界

| 项目 | WS adapter | JW adapter |
| --- | --- | --- |
| payload 上限 | 沿用配置，默认 65535 | 236，总帧 244；L2 仍自行校验 |
| ACK 超时 / 重试 | 5 秒 / 3 次，保持可配置 | 3 秒 / 2 次，保持每命令 retry override |
| flags | 仅 `00/10/30` | 明确接收 `00/10/30/40/50/70`；未知保留位不再按普通数据解释 |
| CRC / 可信头组包超时 | ERR ACK | 静默丢弃；CRC 坏帧内继续寻找新帧头 |
| 去重 | 原有 64 项 / 30 秒 | 保留 128 项容量，新增 30 秒时效；避免同连接 seq 复用一直被旧缓存压住 |
| 组包间隔 | 保留配置，默认 5 秒 | 新增 5 秒清理，避免旧半帧长期阻塞后续数据 |
| 错误 | 映射回 WS 原有异常，底层写错误保留原始对象 | 保留 JW stage 和既有错误文字 |

公共发送队列默认限制 64 个在途/排队发送，控制队列限制 64 个待写 ACK；
SDK 的业务队列仍独立。发送溢出拒绝新提交，控制队列溢出终止连接，不能静默丢 ACK。
接收缓存最大为一帧，使用队列从头移除噪声，避免最大 WS 帧上限下逐字节搬移整个数组。

完整帧的分片串行，动态读取 transport 写入限制，ACK 在帧边界优先。首次写入前登记 pending，
重试复用 seq/完整字节；新 channel 默认从 1 开始，65535 后回绕到 0。
重复数据仍回 ACK，只有首次 payload 交给 SDK；相同 seq 不同 payload 交付并产生冲突观测。

分片写入失败/超时立即失败所有发送并终止字节流，不继续追加帧；关闭取消订阅、组包计时器和缓存。
JW 对完整帧 ACK/业务回应超时仍按原有方式终止会话、拒绝后续业务，物理连接由拥有者关闭；
半帧写失败、通知错误或控制队列溢出则主动断开以恢复边界。宿主识别这次失败清理，
保留原始失败原因，不让随后的主动断开把页面错误覆盖成普通“已断开”。

JW provider 的重复点击测试增加一次异步调度等待，等待初始化回应的控制 ACK 与公共帧队列完成交接，
仍断言只发送一次业务命令。既有健康 UI fixture 修正就绪判断：等待目标页面挂载且没有待绘制帧，
再判断加载条消失，避免页面尚未挂载就提前退出真实 I/O 等待、随后在 fake clock 中一直等进度动画。
没有放宽用例的循环/超时或业务结果断言。

### 19.3 验证

- 公共帧通道 26 项测试通过：独立 CRC 标准检查值/固定字节向量、JW 抓包、严格 flags、
  数组快照、每个拆包边界/粘包/大段噪声、最大长度、早到/迟到/错 seq ACK、ERR/丢失 ACK、
  原字节重传、精确句柄确认、ACK 优先/整帧不交错、动态分片、重复/冲突、队列溢出、
  半帧/挂起写失败、通知错误与断开清理。
- root **1067 项通过、原有 2 项跳过**；WS SDK 131 项、Demo 13 项、独立 example 1 项通过。
  transport 2 项、simulation 12 项、BLE 29 项回归通过。
- workspace analyze 无问题；全仓 Dart 格式检查、`git diff --check` 通过。
- 独立纯 Dart 消费工程不使用 HoneyBox workspace 或 override，直接引用真实 frame/transport/simulation
  包，pub get、analyze 和两个 channel 在 7 字节写入上限上的发送/ACK/释放运行通过；
  运行时仅解析这三个纯 Dart 包。
- WS 独立 Demo macOS M6 脚本通过：模拟扫描/连接→Raw L2/ACK→历史同步及持久化。
  HoneyBox Android debug APK 构建通过；无 Android 手机连接验收，Windows 编译/真机状态仍见 §18。
- 真机过程先沿用上一轮确认的 GHW-01D，验证了 MTU 247、语言编码 1、电量 52%、
  两次新连接；追加 5 字节写入/丢一次真实 ACK 后，同字节同 seq 重传探针成功，
  随后重连在原生 BLE connect 阶段超时。
- 用户随后明确本轮目标应是 **2616_GHDBSC，MAC 69:2D:0C:AD:00:1D**。
  脚本增加名称/MAC/平台 ID 的精确筛选及可配置扫描时长，避免把 macOS UUID 当 MAC。
  本机先按名称+MAC、再仅按 MAC 延长到 25 秒扫描，均未发现该目标；没有连接其他候选替代。
  后续在 Android 上对 **2616_GHDBSC / 69:2D:0C:AD:00:1D** 执行同一 `jw_ble_smoke_test.dart`（名称+MAC 筛选）已通过：MTU 247、语言 1、电量 48%、帧探针与重连通过（脚本仍在 example 壳，**日常 UI 应改经 HoneyBox 挂载统一 Demo，见 §6.1**）。

### 19.4 后续

T3 不迁移健康模型、数据库或 OTA/采集/七牛，不新增 JW 模拟设备；这些边界未变。

**后续（2026-11）**：T4 见 **§20**；BLE/帧 smoke 仍可走 `watch_transport_ble/example` 与集成测试，业务 Demo 走 **`jw_watch_demo`**（§6.1 已更新，不再等待 T4.6 统一壳）。

---

## 20. T4 与 JW Demo 实施记录（2026-11）

### 20.1 已落地包与入口

- **`jw_watch_sdk`**：连接与会话、`JWSettings`、`JWHistorySync` + `jw_watch.db`、今日活动 `0x0B`、控制/测量门面、`JWMeasure`（含配置 ingest）。
- **`jw_watch_demo`**：HoneyBox JW 入口；连接向导、设置（含健康与监测）、数据首页（类型卡片 + App 风格图表）、控制实验室、点测等。
- **分支**：`feat/ws-watch-sdk-skeleton`（与 GitHub `realmcu/HoneyBox` 同步策略以仓库为准）。

### 20.2 子阶段与真机范围（摘要）

| 子阶段 | 典型真机/工程证据 |
| --- | --- |
| T4.1–T4.2 | FF 服务连接、绑定/初始化、主要设置读写、通讯录等 |
| T4.3–T4.4 | 历史同步写库、异步队列、数据首页同步进度、各类型详情页图表 |
| T4.5 | 点测与自动监测（心率透明缓存 + 间隔选项）、控制项联调 |

覆盖表未清零项、特定型号能力缺口 **不阻塞** 宣布「JW SDK 第一阶段可用」；以 issue / 覆盖表跟踪。

### 20.3 流程与 UX 变更（相对本文初稿）

1. **同步 UI**：数据顶区 v0.4——「今日活动」下说明文案 + `received/total` + 进度条；点同步后 loading，**不单独展示等设备同步计划**；详见 `docs/jw-data-home-header-prototype.html`。
2. **健康与监测**：Demo 心率间隔列表走 `readHeartRateIntervalOptions()`；SDK 侧见实施计划 **§8.0**（`JWMeasureConfigCache` / `JWMeasureConfigIngest`，重连清空）。
3. **里程碑裁剪**：删除 T4.6/T4.7；不再等待「独立 example 收口」或「全量切换」才使用新 SDK——**当前 HoneyBox + `jw_watch_demo` 即验收面**。
4. **收尾模式**：多轮真机已在迭代中完成；后续 **观察使用 + bugfix**，总任务 [IKKGIB](https://e.gitee.com/priodigit/dashboard?issue=IKKGIB) 已同步表述。

### 20.4 仍开放 / 非 JW SDK 主线

- 宿主 `lib/services/jw/` 与 package SDK **可能并存**；完全删除旧链路由业务切换节奏决定，**非当前关单条件**。
- `watch_debug_demo`、宿主全面移除旧 JW UI：可选工程，不列入 T4 必须项。
- WS M7、Windows BLE 全平台声明、OTA/采集/七牛：仍按并列 issue 跟踪。

### 20.5 建议回归（维护期）

1. HoneyBox → JW Watch：连接 → 设置（含健康与监测心率读写）→ 数据首页同步与顶区进度 → 任选类型详情。
2. 断连重连后 `readHeartRateAutoMeasure` 应触发 pull（缓存已清空）。
3. `flutter test`：`jw_watch_sdk`、`jw_watch_demo` 包内与 workspace 相关用例。

---

## 21. WS 第二阶段（W5，2026-11 起）

与 JW T4 **并行**：JW 收尾/bugfix；WS 按 **[ws-watch-implementation-plan.md](ws-watch-implementation-plan.md)** 推进。

| 要点 | 说明 |
| --- | --- |
| 门面 | **`WSWatch` + `WSWatchSession`**，对齐 `JWWatch` + `JWWatchSession` |
| L2 | HoneyProtocol；**全量 `0x05` 历史类型** |
| 无真机 | Sim 为主验收，至 **W5.5** |
| 数据 | **W5.3**：0x01–0x1F 一次 codec+表+同步 |
| 业务 | **W5.4**：设置+测量+控制+通知 |
| Demo | **W5.5** · `ws_watch_demo` |
| 真机 | **W5.6** · IKSABE，不阻塞 W5.0–5.5 |

码云总任务：[IKUCE2](https://e.gitee.com/priodigit/dashboard?issue=IKUCE2)（【HoneyBox】【WS Watch SDK】W5 完整实现与模拟器验收）；子任务索引见 [实施计划 §9](ws-watch-implementation-plan.md#9-码云范围)。
