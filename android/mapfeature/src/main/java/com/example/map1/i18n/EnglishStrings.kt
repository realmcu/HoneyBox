package com.example.map1.i18n

import com.example.map1.BleError
import com.example.map1.CastStatus
import com.example.map1.FrameFailure
import com.example.map1.TcpStatus
import com.example.map1.navi.NaviPerfStats
import com.example.map1.QrError
import com.example.map1.WifiError

/** English copy. Wording stays close to the Chinese original so field tests read the same. */
object EnglishStrings : AppStrings {

    override val cancel = "Cancel"
    override val confirm = "Confirm"
    override val back = "Back"
    override val connect = "Connect"
    override val disconnect = "Disconnect"
    override val rescan = "Scan again"
    override val gotIt = "Got it"

    override val languageMenuDescription = "Language"
    override val languageFollowSystem = "Follow system"
    override val languageZhHans = "简体中文"
    override val languageEn = "English"

    override val dashboardTitle = "AMap navi"
    override val scanQrCode = "Scan"

    override fun bleConnecting(address: String) = "BLE meter: connecting to $address"
    override fun bleConnected(modelId: String, address: String) = "BLE meter: connected $modelId ($address)"
    override fun bleNaviReady(modelId: String) = "BLE meter: casting ready $modelId"
    override fun bleDisconnected(address: String) = "BLE meter: $address disconnected"
    override fun bleError(error: BleError) = "BLE meter: ${bleErrorText(error)}"

    override fun bleErrorText(error: BleError) = when (error) {
        BleError.NoBluetoothAdapter -> "Bluetooth is not supported on this device"
        BleError.BluetoothOff -> "Bluetooth is off, turn it on and try again"
        BleError.InvalidAddress -> "The QR code carries an invalid Bluetooth address"
        is BleError.ConnectFailed -> "BLE connection failed, GATT status: ${error.gattStatus}"
        BleError.ServiceDiscoveryRejected -> "Connected, but GATT service discovery could not start; link closed"
        is BleError.ServiceDiscoveryFailed ->
            "Could not read the meter services; link closed (GATT ${error.gattStatus})"
        BleError.HmisServiceMissing ->
            "This device exposes no HMIS navigation service (0xFFC1/0xFFC2); link closed"
        BleError.NotifyEnableFailed -> "Could not enable BLE notifications, the meter is unusable; link closed"
        BleError.CannotStart -> "Could not start the BLE connection"
        BleError.MissingPermission -> "Nearby-devices permission is missing, the BLE meter cannot be connected"
        BleError.PlatformRejected -> "Android refused to start the BLE connection"
        is BleError.HandshakeTimeout ->
            "The meter did not finish the handshake within ${error.seconds} s; link closed"
    }

    override val bleIdle = "BLE meter: —"
    override fun wifiApprovalPending(ssid: String) = "Vehicle Wi-Fi: waiting for system approval of $ssid"
    override fun wifiConnected(ssid: String) = "Vehicle Wi-Fi: connected $ssid"
    override fun wifiLost(ssid: String) = "Vehicle Wi-Fi: $ssid disconnected"
    override fun wifiError(error: WifiError) = "Vehicle Wi-Fi: ${wifiErrorText(error)}"

    override fun wifiErrorText(error: WifiError) = when (error) {
        WifiError.LegacyAndroid ->
            "Automatic vehicle Wi-Fi selection is unsafe below Android 10; join the vehicle Wi-Fi manually and retry."
        WifiError.WifiOff -> "Wi-Fi is off, turn it on and try again"
        WifiError.InvalidCredentials -> "Android rejected the SSID or the Wi-Fi password"
        WifiError.Unavailable -> "Vehicle Wi-Fi unavailable, timed out, or the system prompt was dismissed"
        WifiError.MissingPermission -> "Nearby-Wi-Fi/location permission is missing, the vehicle network cannot be requested"
        WifiError.CannotRequest -> "Android refused to start the vehicle Wi-Fi request"
    }

    override val wifiIdle = "Vehicle Wi-Fi: —"
    override val noConnection = "Meter link: not connected (scan a code, or tap + Connect to search)"

    override val startPoint = "Start"
    override val endPoint = "Destination"
    override val pickPlaceHint = "Tap to search a place"
    override val speedLabel = "Speed km/h"
    override val receiverHostLabel = "Receiver IP (blank = don't send)"
    override fun localIp(ip: String) = "Local IP: $ip"
    override val localIpUnknown = "No local network IP detected"
    override val scanLanDevices = "Scan LAN devices"
    override fun scanningLan(percent: Int) = "Scanning… $percent%"
    override fun pickDevice(count: Int) = "Pick device ($count)"
    override val portLabel = "Port"
    override val fpsLabel = "FPS"
    override val resolutionSection = "Cast resolution (W×H, pixels)"
    override val widthLabel = "Width"
    override val heightLabel = "Height"
    override val presetLabel = "Presets"
    override fun zoomLabel(dpi: Int) = "Navi UI scale: $dpi (higher = smaller UI, 160 = original)"
    override val startBleCasting = "Cast over BLE"
    override val startWifiCasting = "Start virtual-display navigation (Wi-Fi)"
    override val startPreviewCasting = "Start virtual-display navigation (preview only)"
    override val endBleCasting = "Stop BLE casting"
    override val endVirtualNavi = "Stop virtual-display navigation"

    override val previewDescription = "Cast JPG preview"
    override val previewPlaceholder = "Cast preview"

    override val pickStartTitle = "Choose start"
    override val pickEndTitle = "Choose destination"
    override val searchHint = "Search place / address"

    override val connectFailedTitle = "Connection failed"
    override val confirmVehicleTitle = "Confirm vehicle connection"
    override fun fieldModel(value: String) = "Model: $value"
    override fun fieldSn(value: String) = "SN: $value"
    override fun fieldAction(value: String, hex: String) = "Action: $value ($hex)"
    override fun fieldSsid(value: String) = "SSID: $value"
    override fun fieldEndpoint(value: String) = "Endpoint: $value"
    override val fieldPasswordHidden = "Password: hidden"
    override val wifiApprovalNotice = "Android will ask you to approve the Wi-Fi connection after you confirm."
    override val localApNotice =
        "0x001: local AP without internet; only vehicle TCP uses this Wi-Fi, maps and internet stay on the default network."
    override val bleDetectedTitle = "BLE meter found"
    override fun fieldBleAddress(value: String) = "BLE address: $value"
    override fun fieldApk(value: String) = "APK: $value"
    override val bleGattNotice =
        "Confirming opens a BLE GATT connection; the image-transfer profile lands once the protocol is fixed."
    override val invalidQrTitle = "Invalid vehicle QR code"
    override fun scanRejected(reason: String) = "$reason. Current settings are unchanged and no connection was started."

    override fun qrErrorText(error: QrError) = when (error) {
        QrError.TooLong -> "The QR payload is too long"
        QrError.NotAUrl -> "The QR code is not a valid URL"
        QrError.NotAbsoluteUrl -> "The QR code must be an absolute URL"
        QrError.ForbiddenFragmentOrUserInfo -> "The QR URL carries a forbidden fragment or user info"
        QrError.MissingQuery -> "The QR code has no vehicle parameters"
        QrError.EmptyParameter -> "The QR code contains an empty parameter"
        QrError.MalformedParameter -> "A QR parameter is malformed"
        QrError.UndecodableParameter -> "A QR parameter is not valid percent-encoding"
        is QrError.UnknownParameter -> "Unknown QR parameter: ${error.key}"
        is QrError.DuplicateParameter -> "Duplicate QR parameter: ${error.key}"
        is QrError.MissingParameter -> "Missing ${error.key}"
        QrError.InvalidSerialNumber -> "sn is invalid"
        is QrError.UnexpectedBleParameter -> "This BLE model does not accept parameter: ${error.key}"
        QrError.InvalidAddressFormat -> "addr must be a BLE address, e.g. C2:18:3F:91:72:44"
        QrError.ReservedAddress -> "addr must not be all-zero or the broadcast address"
        is QrError.UnsupportedModel -> "Unsupported model: ${error.modelId}"
        is QrError.UnexpectedWifiParameter -> "RTL8782 does not accept parameter: ${error.key}"
        QrError.InvalidAction -> "action must be a non-negative decimal or 0x hex integer"
        QrError.UnsupportedActionFlags -> "action carries flags this build does not support"
        QrError.StandardVehicleApNotImplemented ->
            "Deriving AP parameters from standard 0x200 is not implemented; 0x001 custom AP parameters are required"
        QrError.MissingEndpointParameters -> "This action requires ssid, pwd, ip and port"
        QrError.InvalidSsid -> "SSID must be 1-32 UTF-8 bytes"
        QrError.InvalidPassword -> "The Wi-Fi password must be 8-63 characters or 64 hex digits"
        QrError.NonNumericIp -> "ip must be a numeric IP address"
        QrError.NonLocalIp -> "ip must be a vehicle LAN address"
        QrError.InvalidPort -> "port must be within 1-65535"
    }

    override val snackCameraDenied = "Camera permission denied, the scanner can't open. Allow camera access in system settings."
    override val snackNearbyDeniedForScan =
        "Nearby-devices permission denied, meters can't be searched. Grant it in system settings and try again."
    override val snackNearbyDeniedForBle = "Nearby-devices permission denied, the BLE meter can't be connected."
    override val snackWifiDenied =
        "Wi-Fi permission denied, vehicle not connected. Grant it in system settings and try again."
    override val snackActionWithoutVehicleAp =
        "Action lacks 0x200: only the vehicle endpoint was filled in, Wi-Fi was not connected"
    override val snackEnableWifiFirst = "Turn Wi-Fi on first, then come back and confirm the connection again"
    override val errorLegacyWifiSelection =
        "Automatic vehicle Wi-Fi selection is unsafe below Android 10; the endpoint was filled in, connect the vehicle Wi-Fi manually."
    override val qrScannerPrompt = "Scan the vehicle QR code"
    override val missingApiKeyToast =
        "No AMap API key: maps and place search are unavailable, BLE is unaffected"

    override val navRouteStartFailed = "Could not start route planning, check the start and destination coordinates"
    override val navInitFailed = "Navigation failed to initialise"
    override fun navRouteFailed(code: Int?, description: String?, detail: String?) =
        "Route planning failed [$code]: ${description ?: ""} ${detail ?: ""}".trim()
    override val navArrived = "Arrived at the destination"
    override val navEmulatorStopped = "Simulated navigation finished"
    override fun navInstanceFailed(reason: String?) = "Could not obtain the navigation instance: ${reason ?: ""}"
    override val navCaptureDenied = "Screen capture not granted, JPG frames are not sent over TCP"
    override val navFastCaptureOn = "Fast screen capture enabled"

    override fun castStatus(status: CastStatus) = when (status) {
        CastStatus.Initializing -> "Starting BLE casting…"
        CastStatus.MtuTooSmall -> "BLE MTU is too small to start casting"
        CastStatus.Started -> "BLE casting started (0x10 streaming)"
        CastStatus.Stopped -> "BLE casting stopped"
        CastStatus.DeviceDisconnected -> "Device disconnected, casting interrupted"
        CastStatus.DeviceNoResponse -> "Device did not answer (BEGIN)"
        is CastStatus.DeviceRejected -> "Device rejected casting, status=${status.status}"
        is CastStatus.DeviceAborted -> "Device aborted the transfer, reason=${status.reason}"
        is CastStatus.FramesDropped ->
            "Casting degraded: ${status.failStreak} frames in a row not delivered " +
                "(${frameFailureText(status.reason)}), retrying"
        CastStatus.Recovered -> "Casting recovered"
        is CastStatus.DeviceArea -> "Device casting area ${status.width}x${status.height}"
    }

    override fun frameFailureText(reason: FrameFailure) = when (reason) {
        FrameFailure.AckMissing -> "no acknowledgement from the device"
        FrameFailure.BeginWriteFailed -> "BEGIN write failed"
        FrameFailure.BeginRejected -> "BEGIN rejected"
        FrameFailure.DataWriteFailed -> "DATA write failed"
        FrameFailure.EndWriteFailed -> "END write failed"
        is FrameFailure.Rejected ->
            "device did not accept the frame (status=${reason.status}/${reason.error})"
    }

    override fun tcpStatus(status: TcpStatus) = when (status) {
        is TcpStatus.Connected ->
            "TCP connected ${status.host}:${status.port}, sndbuf=${status.sendBuffer}"
        is TcpStatus.Disconnected ->
            "TCP closed: ${status.reason ?: ""}, retrying in ${status.retryDelayMs}ms"
        TcpStatus.Stopped -> "TCP stopped"
    }

    override fun perfOverlayText(snapshot: NaviPerfStats.Snapshot): String = buildString {
        append("target ${snapshot.targetFps} fps")
        append(" · capture ${"%.1f".format(snapshot.captureFps)}")
        append(" · send ${"%.1f".format(snapshot.sendFps)}\n")
        append("acquire=${snapshot.acquireMs}ms(avg ${"%.1f".format(snapshot.avgAcquireMs)})")
        append(" · empty=${snapshot.emptyAcquireCount}\n")
        append("bitmap=${snapshot.toBitmapMs}ms(avg ${"%.1f".format(snapshot.avgToBitmapMs)})\n")
        append("encode=${snapshot.encodeMs}ms(avg ${"%.1f".format(snapshot.avgEncodeMs)})\n")
        append("send=${snapshot.sendMs}ms(avg ${"%.1f".format(snapshot.avgSendMs)})")
        append(" · q=${snapshot.sendQueueSize}\n")
        append("loop=${snapshot.loopIntervalMs}ms")
        append(" · ${snapshot.bytesPerSecond * 8 / 1000} kbps")
        append(" · seq ${snapshot.lastSeq}")
    }

    override val overlayPermissionRequired =
        "Grant the \"display over other apps\" permission, then come back and retry"
    override val overlayPermissionDenied =
        "Overlay permission not granted, navigation casting cannot start"
    override val projectionStarted = "Navigation virtual display started in the background"
    override val naviChannelName = "Navigation casting"
    override val naviNotificationTitle = "Navigation casting is running"
    override fun naviNotificationText(width: Int, height: Int) =
        "Sending the ${width}×$height navigation picture to the device"

    override val scannerPageTitle = "Scan the receiver QR code"
    override val scannerFrameHint = "Place the QR code inside the frame"

    override val addDeviceTitle = "Add device"
    override val showAllLabel = "Show all"
    override val ruleHintShowAll =
        "Showing every advertising device. Troubleshooting only: devices outside the filter rule are listed too."
    override val ruleHintFiltered =
        "Only devices advertising the HMIS service (484D4953…) or Realtek vendor ID (0x005D) are listed."
    override val scanningNearbyDevices = "Searching for nearby meters…"
    override val scanningHintShowAll = "Turn on Show all to inspect the raw advertisements"
    override val scanningHintDefault = "Power the meter on and hold it close to the phone"
    override val notScanning = "Not scanning"
    override val notScanningHint = "Tap refresh in the top bar to scan again"
    override val cannotStartScan =
        "Can't start scanning. Make sure Bluetooth is on and the Nearby devices permission is granted."
    override fun scanStartFailed(code: Int) = "Scan failed to start (error $code). Toggle Bluetooth and try again."
    override fun batteryLabel(percent: Int) = "Battery $percent%"
    override val charging = "Charging"
    override val castReadyLabel = "Cast ready"
    override val boundLabel = "Bound"
    override fun matchedBadge(label: String) = "Match: $label"
    override val unmatchedBadge = "No filter match"
    override val matchHmisServiceUuid = "HMIS service UUID"
    override val matchHmisServiceData = "HMIS service data"
    override val matchRealtekVendor = "Realtek vendor ID"
    override val fallbackHmisMeter = "HMIS meter"
    override val fallbackUnnamedDevice = "Unnamed device"
}
