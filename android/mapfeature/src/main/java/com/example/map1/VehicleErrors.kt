package com.example.map1

/**
 * Machine-readable failure reasons for the native vehicle stack.
 *
 * Managers and the QR parser must not invent user-facing text: they publish one
 * of these values and the i18n layer turns it into copy, so every language
 * stays in sync and reasons stay testable.
 */

/** GATT / BLE link failures raised by [VehicleBleManager]. */
sealed interface BleError {
    /** No Bluetooth adapter on this device (emulator, Wi-Fi-only tablet). */
    data object NoBluetoothAdapter : BleError

    /** Radio is switched off by the user or a system policy. */
    data object BluetoothOff : BleError

    /** QR payload's address could not be turned into a [android.bluetooth.BluetoothDevice]. */
    data object InvalidAddress : BleError

    /** The stack reported a non-success status while disconnecting. */
    data class ConnectFailed(val gattStatus: Int) : BleError

    /** [android.bluetooth.BluetoothGatt.discoverServices] returned false. */
    data object ServiceDiscoveryRejected : BleError

    /** Service discovery completed with a non-success status. */
    data class ServiceDiscoveryFailed(val gattStatus: Int) : BleError

    /** Connected device lacks the HMIS service / 0xFFC1 + 0xFFC2 characteristics. */
    data object HmisServiceMissing : BleError

    /** CCCD write for the notify characteristic failed. */
    data object NotifyEnableFailed : BleError

    /** connectGatt() returned null. */
    data object CannotStart : BleError

    /** BLUETOOTH_CONNECT / fine-location permission missing. */
    data object MissingPermission : BleError

    /** The framework threw while starting the connection. */
    data object PlatformRejected : BleError

    /** Connected but never reached NaviReady inside the handshake window. */
    data class HandshakeTimeout(val seconds: Int) : BleError
}

/** Vehicle Wi-Fi session failures raised by [VehicleWifiManager]. */
sealed interface WifiError {
    /** WifiNetworkSpecifier requires Android 10; older devices need a manual join. */
    data object LegacyAndroid : WifiError

    data object WifiOff : WifiError

    /** SSID / passphrase rejected by WifiNetworkSpecifier.Builder. */
    data object InvalidCredentials : WifiError

    /** Request timed out, network went away, or the user dismissed the system prompt. */
    data object Unavailable : WifiError

    /** Nearby-Wi-Fi / location permission missing. */
    data object MissingPermission : WifiError

    /** requestNetwork() threw for a non-permission reason. */
    data object CannotRequest : WifiError
}

/** QR query failures raised by [VehicleQrProtocol]. */
sealed interface QrError {
    data object TooLong : QrError
    data object NotAUrl : QrError
    data object NotAbsoluteUrl : QrError
    data object ForbiddenFragmentOrUserInfo : QrError

    /** No query string at all. */
    data object MissingQuery : QrError
    data object EmptyParameter : QrError
    data object MalformedParameter : QrError
    data object UndecodableParameter : QrError
    data class UnknownParameter(val key: String) : QrError
    data class DuplicateParameter(val key: String) : QrError

    /** A required key is absent; [key] is the query parameter name. */
    data class MissingParameter(val key: String) : QrError
    data object InvalidSerialNumber : QrError

    /** BLE payload carries keys outside the BLE key set. */
    data class UnexpectedBleParameter(val key: String) : QrError
    data object InvalidAddressFormat : QrError
    data object ReservedAddress : QrError

    data class UnsupportedModel(val modelId: String) : QrError

    /** Wi-Fi payload carries keys outside the Wi-Fi key set. */
    data class UnexpectedWifiParameter(val key: String) : QrError
    data object InvalidAction : QrError
    data object UnsupportedActionFlags : QrError

    /** 0x200 alone cannot derive AP parameters; 0x001 custom AP data is required. */
    data object StandardVehicleApNotImplemented : QrError

    /** action needs ssid/pwd/ip/port but at least one is missing. */
    data object MissingEndpointParameters : QrError
    data object InvalidSsid : QrError
    data object InvalidPassword : QrError
    data object NonNumericIp : QrError
    data object NonLocalIp : QrError
    data object InvalidPort : QrError
}
