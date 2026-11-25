package com.example.map1.i18n

import com.example.map1.BleError
import com.example.map1.CastStatus
import com.example.map1.FrameFailure
import com.example.map1.TcpStatus
import com.example.map1.navi.NaviPerfStats
import com.example.map1.QrError
import com.example.map1.WifiError

/** Simplified Chinese copy. Kept byte-identical to the strings that used to be inline. */
object ZhHansStrings : AppStrings {

    override val cancel = "取消"
    override val confirm = "确认"
    override val back = "返回"
    override val connect = "连接"
    override val disconnect = "断开"
    override val rescan = "重新扫描"
    override val gotIt = "知道了"

    override val languageMenuDescription = "语言"
    override val languageFollowSystem = "跟随系统"
    override val languageZhHans = "简体中文"
    override val languageEn = "English"

    override val dashboardTitle = "高德模拟导航"
    override val scanQrCode = "扫一扫"

    override fun bleConnecting(address: String) = "BLE 仪表：正在连接 $address"
    override fun bleConnected(modelId: String, address: String) = "BLE 仪表：已连接 $modelId ($address)"
    override fun bleNaviReady(modelId: String) = "BLE 仪表：投屏就绪 $modelId"
    override fun bleDisconnected(address: String) = "BLE 仪表：$address 已断开"
    override fun bleError(error: BleError) = "BLE 仪表：${bleErrorText(error)}"

    override fun bleErrorText(error: BleError) = when (error) {
        BleError.NoBluetoothAdapter -> "此设备不支持蓝牙"
        BleError.BluetoothOff -> "蓝牙未开启，请开启后重试"
        BleError.InvalidAddress -> "二维码中的蓝牙地址无效"
        is BleError.ConnectFailed -> "BLE 连接失败，GATT 状态：${error.gattStatus}"
        BleError.ServiceDiscoveryRejected -> "已连接，但无法发现 GATT 服务，已断开"
        is BleError.ServiceDiscoveryFailed -> "无法读取仪表服务，已断开（GATT ${error.gattStatus}）"
        BleError.HmisServiceMissing -> "该设备未提供 HMIS 导航服务（0xFFC1/0xFFC2），已断开"
        BleError.NotifyEnableFailed -> "无法启用 BLE 通知，仪表不可用，已断开"
        BleError.CannotStart -> "无法发起 BLE 连接"
        BleError.MissingPermission -> "缺少附近设备权限，无法连接 BLE 仪表"
        BleError.PlatformRejected -> "Android 无法发起 BLE 连接"
        is BleError.HandshakeTimeout -> "仪表未在 ${error.seconds} 秒内完成握手，已断开"
    }

    override val bleIdle = "BLE 仪表：—"
    override fun wifiApprovalPending(ssid: String) = "车辆 Wi-Fi：等待系统批准并连接 $ssid"
    override fun wifiConnected(ssid: String) = "车辆 Wi-Fi：已连接 $ssid"
    override fun wifiLost(ssid: String) = "车辆 Wi-Fi：$ssid 已断开"
    override fun wifiError(error: WifiError) = "车辆 Wi-Fi：${wifiErrorText(error)}"

    override fun wifiErrorText(error: WifiError) = when (error) {
        WifiError.LegacyAndroid ->
            "Android 10 以下无法安全地自动选择车辆 Wi-Fi；请手动连接后重试。为保护移动网络，不会进行全进程网络绑定。"
        WifiError.WifiOff -> "Wi-Fi 未开启，请开启后重试"
        WifiError.InvalidCredentials -> "SSID 或 Wi-Fi 密码不被 Android 接受"
        WifiError.Unavailable -> "车辆 Wi-Fi 不可用、连接超时，或用户取消了系统连接确认"
        WifiError.MissingPermission -> "缺少附近 Wi-Fi/位置权限，无法请求车辆网络"
        WifiError.CannotRequest -> "Android 无法发起车辆 Wi-Fi 请求"
    }

    override val wifiIdle = "车辆 Wi-Fi：—"
    override val noConnection = "连接仪表：未连接（扫一扫，或点「+ 连接」搜索设备）"

    override val startPoint = "起点"
    override val endPoint = "终点"
    override val pickPlaceHint = "点击搜索地点"
    override val speedLabel = "速度 km/h"
    override val receiverHostLabel = "接收端 IP（留空不发）"
    override fun localIp(ip: String) = "本机局域网 IP：$ip"
    override val localIpUnknown = "未检测到局域网 IP"
    override val scanLanDevices = "扫描局域网设备"
    override fun scanningLan(percent: Int) = "扫描中… $percent%"
    override fun pickDevice(count: Int) = "选择设备 ($count)"
    override val portLabel = "端口"
    override val fpsLabel = "FPS"
    override val resolutionSection = "投屏分辨率（宽×高，像素）"
    override val widthLabel = "宽"
    override val heightLabel = "高"
    override val presetLabel = "预设"
    override fun zoomLabel(dpi: Int) = "导航 UI 缩放：$dpi（越大 UI 越小，160=原始）"
    override val startBleCasting = "BLE 投屏"
    override val startWifiCasting = "开始虚拟屏导航 (WiFi)"
    override val startPreviewCasting = "开始虚拟屏导航 (仅预览)"
    override val endBleCasting = "结束 BLE 投屏"
    override val endVirtualNavi = "结束虚拟屏导航"

    override val previewDescription = "投屏 JPG 预览"
    override val previewPlaceholder = "投屏预览"

    override val pickStartTitle = "选择起点"
    override val pickEndTitle = "选择终点"
    override val searchHint = "搜索地点 / 地址"

    override val connectFailedTitle = "连接失败"
    override val confirmVehicleTitle = "确认车辆连接"
    override fun fieldModel(value: String) = "型号：$value"
    override fun fieldSn(value: String) = "SN：$value"
    override fun fieldAction(value: String, hex: String) = "Action：$value ($hex)"
    override fun fieldSsid(value: String) = "SSID：$value"
    override fun fieldEndpoint(value: String) = "端点：$value"
    override val fieldPasswordHidden = "密码：已隐藏"
    override val wifiApprovalNotice = "确认后 Android 将显示系统 Wi-Fi 连接批准界面。"
    override val localApNotice =
        "0x001：本地无互联网 AP；仅车辆 TCP 使用此 Wi-Fi，地图/互联网保留默认移动网络。"
    override val bleDetectedTitle = "已识别 BLE 仪表"
    override fun fieldBleAddress(value: String) = "BLE 地址：$value"
    override fun fieldApk(value: String) = "APK：$value"
    override val bleGattNotice = "确认后将建立 BLE GATT 连接；专用传图 Profile 将在协议确定后接入。"
    override val invalidQrTitle = "车辆二维码无效"
    override fun scanRejected(reason: String) = "$reason。当前配置未更改，也未发起连接。"

    override fun qrErrorText(error: QrError) = when (error) {
        QrError.TooLong -> "二维码内容过长"
        QrError.NotAUrl -> "二维码不是有效 URL"
        QrError.NotAbsoluteUrl -> "二维码必须是绝对 URL"
        QrError.ForbiddenFragmentOrUserInfo -> "二维码 URL 包含不允许的片段或用户信息"
        QrError.MissingQuery -> "二维码缺少车辆参数"
        QrError.EmptyParameter -> "二维码包含空参数"
        QrError.MalformedParameter -> "二维码参数格式错误"
        QrError.UndecodableParameter -> "二维码参数编码错误"
        is QrError.UnknownParameter -> "二维码包含未知参数：${error.key}"
        is QrError.DuplicateParameter -> "二维码参数重复：${error.key}"
        is QrError.MissingParameter -> "缺少 ${error.key}"
        QrError.InvalidSerialNumber -> "sn 无效"
        is QrError.UnexpectedBleParameter -> "BLE 车型包含不适用参数：${error.key}"
        QrError.InvalidAddressFormat -> "addr 必须是 BLE 地址，例如 C2:18:3F:91:72:44"
        QrError.ReservedAddress -> "addr 不能是全 0 或广播地址"
        is QrError.UnsupportedModel -> "不支持的车型型号：${error.modelId}"
        is QrError.UnexpectedWifiParameter -> "RTL8782 包含不适用参数：${error.key}"
        QrError.InvalidAction -> "action 必须是十进制或 0x 十六进制非负整数"
        QrError.UnsupportedActionFlags -> "action 包含当前不支持的标志位"
        QrError.StandardVehicleApNotImplemented ->
            "0x200 标准车辆 AP 参数推导尚未实现；需要 0x001 自定义 AP 参数"
        QrError.MissingEndpointParameters -> "当前 action 需要 ssid、pwd、ip 和 port"
        QrError.InvalidSsid -> "SSID 必须为 1–32 个 UTF-8 字节"
        QrError.InvalidPassword -> "Wi-Fi 密码必须为 8–63 个字符或 64 位十六进制"
        QrError.NonNumericIp -> "ip 必须是数字 IP 地址"
        QrError.NonLocalIp -> "ip 必须是车辆局域网地址"
        QrError.InvalidPort -> "port 必须在 1–65535 范围内"
    }

    override val snackCameraDenied = "相机权限被拒绝，无法扫一扫。请在系统设置中允许相机权限。"
    override val snackNearbyDeniedForScan = "附近设备权限被拒绝，无法搜索仪表。请在系统设置中授权后重试。"
    override val snackNearbyDeniedForBle = "附近设备权限被拒绝，无法连接 BLE 仪表。"
    override val snackWifiDenied = "Wi-Fi 权限被拒绝，未连接车辆。请在系统设置中授权后重试。"
    override val snackActionWithoutVehicleAp = "action 不含 0x200：仅填入车辆端点，不连接 Wi-Fi"
    override val snackEnableWifiFirst = "请先打开 Wi-Fi，开启后返回并再次确认连接"
    override val errorLegacyWifiSelection =
        "Android 10 以下不支持安全的自动车辆 Wi-Fi 选择；接收端已填入，请手动连接车辆 Wi-Fi。"
    override val qrScannerPrompt = "扫描车辆二维码"
    override val missingApiKeyToast = "未配置高德 API Key：地图与地点搜索不可用，BLE 连接不受影响"

    override val navRouteStartFailed = "发起算路失败，请检查起终点坐标"
    override val navInitFailed = "导航初始化失败"
    override fun navRouteFailed(code: Int?, description: String?, detail: String?) =
        "路线规划失败[$code]：${description ?: ""} ${detail ?: ""}"
    override val navArrived = "已到达目的地"
    override val navEmulatorStopped = "模拟导航结束"
    override fun navInstanceFailed(reason: String?) = "获取导航实例失败：${reason ?: ""}"
    override val navCaptureDenied = "未授权屏幕截图，JPG TCP 不发送"
    override val navFastCaptureOn = "已启用快速屏幕截图"

    override fun castStatus(status: CastStatus) = when (status) {
        CastStatus.Initializing -> "BLE 投屏初始化中…"
        CastStatus.MtuTooSmall -> "BLE MTU 过小，无法启动投屏"
        CastStatus.Started -> "BLE 投屏已启动 (0x10 流式)"
        CastStatus.Stopped -> "BLE 投屏已停止"
        CastStatus.DeviceDisconnected -> "设备已断开，投屏中断"
        CastStatus.DeviceNoResponse -> "设备无响应（BEGIN）"
        is CastStatus.DeviceRejected -> "设备拒绝投屏 status=${status.status}"
        is CastStatus.DeviceAborted -> "设备中止传输 reason=${status.reason}"
        is CastStatus.FramesDropped ->
            "投屏异常：连续 ${status.failStreak} 帧未送达（${frameFailureText(status.reason)}），正在重试"
        CastStatus.Recovered -> "投屏已恢复"
        is CastStatus.DeviceArea -> "设备投屏区域 ${status.width}x${status.height}"
    }

    override fun frameFailureText(reason: FrameFailure) = when (reason) {
        FrameFailure.AckMissing -> "设备未回确认"
        FrameFailure.BeginWriteFailed -> "BEGIN 写入失败"
        FrameFailure.BeginRejected -> "BEGIN 被拒绝"
        FrameFailure.DataWriteFailed -> "DATA 写入失败"
        FrameFailure.EndWriteFailed -> "END 写入失败"
        is FrameFailure.Rejected -> "设备未接受（status=${reason.status}/${reason.error}）"
    }

    override fun tcpStatus(status: TcpStatus) = when (status) {
        is TcpStatus.Connected -> "TCP 已连接 ${status.host}:${status.port}, sndbuf=${status.sendBuffer}"
        is TcpStatus.Disconnected ->
            "TCP 断开：${status.reason ?: ""}，${status.retryDelayMs}ms 后重连"
        TcpStatus.Stopped -> "TCP 已停止"
    }

    override fun perfOverlayText(snapshot: NaviPerfStats.Snapshot): String = buildString {
        append("目标FPS=${snapshot.targetFps}")
        append(" 采集=${"%.1f".format(snapshot.captureFps)}")
        append(" 发送=${"%.1f".format(snapshot.sendFps)}\n")
        append("acquire=${snapshot.acquireMs}ms(avg ${"%.1f".format(snapshot.avgAcquireMs)})")
        append(" 空采=${snapshot.emptyAcquireCount}\n")
        append("bitmap=${snapshot.toBitmapMs}ms(avg ${"%.1f".format(snapshot.avgToBitmapMs)})\n")
        append("encode=${snapshot.encodeMs}ms(avg ${"%.1f".format(snapshot.avgEncodeMs)})\n")
        append("send=${snapshot.sendMs}ms(avg ${"%.1f".format(snapshot.avgSendMs)})")
        append(" q=${snapshot.sendQueueSize}\n")
        append("loop=${snapshot.loopIntervalMs}ms")
        append(" kbps=${snapshot.bytesPerSecond * 8 / 1000}")
        append(" seq=${snapshot.lastSeq}")
    }

    override val overlayPermissionRequired = "请授予『悬浮窗/显示在其他应用上层』权限后返回再试"
    override val overlayPermissionDenied = "未授予悬浮窗权限，无法启动导航投屏"
    override val projectionStarted = "导航虚拟屏已在后台启动"
    override val naviChannelName = "导航投屏"
    override val naviNotificationTitle = "导航投屏运行中"
    override fun naviNotificationText(width: Int, height: Int) =
        "正在将 ${width}×$height 导航画面发送到设备"

    override val scannerPageTitle = "扫描接收端二维码"
    override val scannerFrameHint = "将二维码放入取景框内"

    override val addDeviceTitle = "添加设备"
    override val showAllLabel = "显示全部"
    override val ruleHintShowAll = "已显示全部广播设备。仅用于排查：不符合过滤规则的设备也会出现在列表里。"
    override val ruleHintFiltered =
        "仅显示广播中含 HMIS 服务（484D4953…）或 Realtek 厂商 ID（0x005D）的设备。"
    override val scanningNearbyDevices = "正在搜索附近的仪表…"
    override val scanningHintShowAll = "可打开「显示全部」核对广播内容"
    override val scanningHintDefault = "请让仪表上电并靠近手机"
    override val notScanning = "未在扫描"
    override val notScanningHint = "点右上角刷新重新开始扫描"
    override val cannotStartScan = "无法开始扫描。请确认蓝牙已开启，且已授予「附近的设备」权限。"
    override fun scanStartFailed(code: Int) = "扫描启动失败（错误码 $code），请关闭蓝牙后重试。"
    override fun batteryLabel(percent: Int) = "电量 $percent%"
    override val charging = "充电中"
    override val castReadyLabel = "可投屏"
    override val boundLabel = "已绑定"
    override fun matchedBadge(label: String) = "匹配：$label"
    override val unmatchedBadge = "未匹配过滤规则"
    override val matchHmisServiceUuid = "HMIS 服务 UUID"
    override val matchHmisServiceData = "HMIS 服务数据"
    override val matchRealtekVendor = "Realtek 厂商 ID"
    override val fallbackHmisMeter = "HMIS 仪表"
    override val fallbackUnnamedDevice = "未命名设备"
}
