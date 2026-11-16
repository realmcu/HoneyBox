package com.example.map1.i18n

import com.example.map1.BleError
import com.example.map1.CastStatus
import com.example.map1.FrameFailure
import com.example.map1.QrError
import com.example.map1.TcpStatus
import com.example.map1.navi.NaviPerfStats
import com.example.map1.WifiError

/**
 * Every user-visible string of the native dashboard (`MapHomeActivity`) and its
 * "add device" page (`AddBleDeviceActivity`).
 *
 * Implementations are plain objects rather than Android string resources: the
 * dashboard is launched from Flutter and ships as a Compose-only library module
 * without AppCompat, so an in-app language override has to work on minSdk 24
 * without per-app locale APIs. Keeping the text in Kotlin also makes the switch
 * instantaneous — swapping the [LocalAppStrings] value recomposes the tree,
 * no activity restart required.
 *
 * Adding a language means adding one object here; the compiler flags every
 * missing member.
 */
interface AppStrings {

    // ── Shared actions ──────────────────────────────────────────────────────

    val cancel: String
    val confirm: String
    val back: String
    val connect: String
    val disconnect: String
    val rescan: String
    val gotIt: String

    // ── Language menu ───────────────────────────────────────────────────────

    val languageMenuDescription: String
    val languageFollowSystem: String
    val languageZhHans: String
    val languageEn: String

    // ── Dashboard header ────────────────────────────────────────────────────

    val dashboardTitle: String
    val scanQrCode: String

    // ── Connection banner ───────────────────────────────────────────────────

    fun bleConnecting(address: String): String
    fun bleConnected(modelId: String, address: String): String
    fun bleNaviReady(modelId: String): String
    fun bleDisconnected(address: String): String

    /** Status-line form: "BLE meter: <reason>". */
    fun bleError(error: BleError): String

    /** Dialog-body form: the reason alone. */
    fun bleErrorText(error: BleError): String
    val bleIdle: String
    fun wifiApprovalPending(ssid: String): String
    fun wifiConnected(ssid: String): String
    fun wifiLost(ssid: String): String

    /** Status-line form: "Vehicle Wi-Fi: <reason>". */
    fun wifiError(error: WifiError): String

    /** Dialog-body form: the reason alone. */
    fun wifiErrorText(error: WifiError): String
    val wifiIdle: String
    val noConnection: String

    // ── Route and casting parameters ────────────────────────────────────────

    val startPoint: String
    val endPoint: String
    val pickPlaceHint: String
    val speedLabel: String
    val receiverHostLabel: String
    fun localIp(ip: String): String
    val localIpUnknown: String
    val scanLanDevices: String
    fun scanningLan(percent: Int): String
    fun pickDevice(count: Int): String
    val portLabel: String
    val fpsLabel: String
    val resolutionSection: String
    val widthLabel: String
    val heightLabel: String
    val presetLabel: String
    fun zoomLabel(dpi: Int): String
    val startBleCasting: String
    val startWifiCasting: String
    val startPreviewCasting: String
    val endBleCasting: String
    val endVirtualNavi: String

    // ── Cast preview window ─────────────────────────────────────────────────

    val previewDescription: String
    val previewPlaceholder: String

    // ── Place search page ───────────────────────────────────────────────────

    val pickStartTitle: String
    val pickEndTitle: String
    val searchHint: String

    // ── Dialogs ─────────────────────────────────────────────────────────────

    val connectFailedTitle: String
    val confirmVehicleTitle: String
    fun fieldModel(value: String): String
    fun fieldSn(value: String): String
    fun fieldAction(value: String, hex: String): String
    fun fieldSsid(value: String): String
    fun fieldEndpoint(value: String): String
    val fieldPasswordHidden: String
    val wifiApprovalNotice: String
    val localApNotice: String
    val bleDetectedTitle: String
    fun fieldBleAddress(value: String): String
    fun fieldApk(value: String): String
    val bleGattNotice: String
    val invalidQrTitle: String

    /** Reason for a rejected QR code, already translated. */
    fun scanRejected(reason: String): String

    /** Bare reason for a rejected QR code. */
    fun qrErrorText(error: QrError): String

    // ── Snackbars, toasts, scanner UI ───────────────────────────────────────

    val snackCameraDenied: String
    val snackNearbyDeniedForScan: String
    val snackNearbyDeniedForBle: String
    val snackWifiDenied: String
    val snackActionWithoutVehicleAp: String
    val snackEnableWifiFirst: String
    val errorLegacyWifiSelection: String
    val qrScannerPrompt: String
    val missingApiKeyToast: String

    // ── Navigation page (native AMap UI, toasts) ────────────────────────────

    val navRouteStartFailed: String
    val navInitFailed: String
    fun navRouteFailed(code: Int?, description: String?, detail: String?): String
    val navArrived: String
    val navEmulatorStopped: String
    fun navInstanceFailed(reason: String?): String
    val navCaptureDenied: String
    val navFastCaptureOn: String

    // ── Casting status lines ────────────────────────────────────────────────

    fun castStatus(status: CastStatus): String
    fun frameFailureText(reason: FrameFailure): String
    fun tcpStatus(status: TcpStatus): String

    // ── Cast pipeline diagnostics overlay ───────────────────────────────────

    /** Frame-rate / per-stage timing overlay drawn on the cast preview. */
    fun perfOverlayText(snapshot: NaviPerfStats.Snapshot): String

    // ── Projection entry + foreground notification ──────────────────────────

    val overlayPermissionRequired: String
    val overlayPermissionDenied: String
    val projectionStarted: String
    val naviChannelName: String
    val naviNotificationTitle: String
    fun naviNotificationText(width: Int, height: Int): String

    // ── Standalone QR scanner page ──────────────────────────────────────────

    val scannerPageTitle: String
    val scannerFrameHint: String

    // ── Add-device page ─────────────────────────────────────────────────────

    val addDeviceTitle: String
    val showAllLabel: String
    val ruleHintShowAll: String
    val ruleHintFiltered: String
    val scanningNearbyDevices: String
    val scanningHintShowAll: String
    val scanningHintDefault: String
    val notScanning: String
    val notScanningHint: String
    val cannotStartScan: String
    fun scanStartFailed(code: Int): String
    fun batteryLabel(percent: Int): String
    val charging: String
    val castReadyLabel: String
    val boundLabel: String
    fun matchedBadge(label: String): String
    val unmatchedBadge: String
    val matchHmisServiceUuid: String
    val matchHmisServiceData: String
    val matchRealtekVendor: String
    val fallbackHmisMeter: String
    val fallbackUnnamedDevice: String
}
