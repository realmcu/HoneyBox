package com.example.map1

import java.net.InetAddress
import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

/** Vehicle QR query protocol. The URL scheme, host, and path are transport metadata only. */
object VehicleQrProtocol {
    const val MODEL_ID_RTL8782 = "RTL8782"

    const val MODEL_ID_RTL8773G = "RTL8773G"
    const val MODEL_ID_RTL8773E = "RTL8773E"

    const val ACTION_CUSTOM_LOCAL_AP = 0x001
    const val ACTION_PHONE_CONNECTS_VEHICLE_AP = 0x200
    // Combined flags are 0x201 == decimal 513. “503 == 0x201” is a producer prompt typo.

    private const val MAX_PAYLOAD_BYTES = 4096
    private const val MAX_SN_LENGTH = 64
    private val wifiKeys = setOf("modelid", "sn", "action", "ssid", "pwd", "ip", "port")
    private val bleKeys = setOf("modelid", "sn", "addr")
    private val allowedKeys = wifiKeys + bleKeys
    private val bleAddress = Regex("^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$")

    data class Config(
        val modelId: String,
        val serialNumber: String,
        val action: Int,
        val ssid: String,
        val password: String,
        val ip: String,
        val port: Int,
    ) {
        val connectsVehicleAp: Boolean get() = action and ACTION_PHONE_CONNECTS_VEHICLE_AP != 0
        val customLocalAp: Boolean get() = action and ACTION_CUSTOM_LOCAL_AP != 0
        val actionHex: String get() = "0x${action.toString(16).uppercase()}"
    }

    data class BleConfig(
        val modelId: String,
        val serialNumber: String,
        val address: String,
        val apkUrl: String,
    )

    sealed interface Result {
        data class WifiSuccess(val config: Config) : Result
        data class BleSuccess(val config: BleConfig) : Result
        data class Failure(val error: QrError) : Result
    }

    fun parse(raw: String): Result {
        if (raw.toByteArray(StandardCharsets.UTF_8).size > MAX_PAYLOAD_BYTES) return failure(QrError.TooLong)
        val uri = runCatching { URI(raw) }.getOrNull() ?: return failure(QrError.NotAUrl)
        if (!uri.isAbsolute || uri.scheme.isNullOrBlank() || uri.host.isNullOrBlank()) return failure(QrError.NotAbsoluteUrl)
        if (uri.rawFragment != null || uri.userInfo != null) return failure(QrError.ForbiddenFragmentOrUserInfo)

        val values = linkedMapOf<String, String>()
        val rawQuery = uri.rawQuery ?: return failure(QrError.MissingQuery)
        for (part in rawQuery.split('&')) {
            if (part.isEmpty()) return failure(QrError.EmptyParameter)
            val separator = part.indexOf('=')
            if (separator <= 0) return failure(QrError.MalformedParameter)
            val key = decode(part.substring(0, separator)) ?: return failure(QrError.UndecodableParameter)
            val value = decode(part.substring(separator + 1)) ?: return failure(QrError.UndecodableParameter)
            if (key !in allowedKeys) return failure(QrError.UnknownParameter(key))
            if (values.put(key, value) != null) return failure(QrError.DuplicateParameter(key))
        }

        fun required(name: String): String? = values[name]
        val modelId = required("modelid") ?: return failure(QrError.MissingParameter("modelid"))
        val sn = required("sn") ?: return failure(QrError.MissingParameter("sn"))
        if (sn.isBlank() || sn.length > MAX_SN_LENGTH || sn.any(Char::isISOControl)) return failure(QrError.InvalidSerialNumber)

        if (modelId == MODEL_ID_RTL8773G || modelId == MODEL_ID_RTL8773E) {
            val unexpected = values.keys - bleKeys
            if (unexpected.isNotEmpty()) return failure(QrError.UnexpectedBleParameter(unexpected.first()))
            val address = required("addr") ?: return failure(QrError.MissingParameter("addr"))
            if (!bleAddress.matches(address)) return failure(QrError.InvalidAddressFormat)
            if (address.equals("00:00:00:00:00:00", ignoreCase = true) ||
                address.equals("FF:FF:FF:FF:FF:FF", ignoreCase = true)
            ) return failure(QrError.ReservedAddress)
            return Result.BleSuccess(
                BleConfig(modelId, sn, address.uppercase(), "${uri.scheme}://${uri.rawAuthority}${uri.rawPath.orEmpty()}"),
            )
        }
        if (modelId != MODEL_ID_RTL8782) return failure(QrError.UnsupportedModel(modelId))

        val unexpected = values.keys - wifiKeys
        if (unexpected.isNotEmpty()) return failure(QrError.UnexpectedWifiParameter(unexpected.first()))
        val actionText = required("action") ?: return failure(QrError.MissingParameter("action"))
        val action = parseAction(actionText) ?: return failure(QrError.InvalidAction)
        val supportedActionMask = ACTION_PHONE_CONNECTS_VEHICLE_AP or ACTION_CUSTOM_LOCAL_AP
        if (action and supportedActionMask.inv() != 0) return failure(QrError.UnsupportedActionFlags)
        val connects = action and ACTION_PHONE_CONNECTS_VEHICLE_AP != 0
        val custom = action and ACTION_CUSTOM_LOCAL_AP != 0
        if (connects && !custom) return failure(QrError.StandardVehicleApNotImplemented)

        val needsEndpoint = connects || custom
        val ssid = required("ssid").orEmpty()
        val password = required("pwd").orEmpty()
        val ip = required("ip").orEmpty()
        val portText = required("port").orEmpty()
        if (needsEndpoint) {
            if (listOf("ssid", "pwd", "ip", "port").any { it !in values }) return failure(QrError.MissingEndpointParameters)
            val ssidBytes = ssid.toByteArray(StandardCharsets.UTF_8).size
            if (ssidBytes !in 1..32 || ssid.any(Char::isISOControl)) return failure(QrError.InvalidSsid)
            val validPassword = (password.length in 8..63 ||
                password.length == 64 && password.all { it.isDigit() || it.lowercaseChar() in 'a'..'f' }) &&
                password.none(Char::isISOControl)
            if (!validPassword) return failure(QrError.InvalidPassword)
            if (!isNumericIp(ip)) return failure(QrError.NonNumericIp)
            if (!isLocalVehicleAddress(ip)) return failure(QrError.NonLocalIp)
        }
        val port = portText.toIntOrNull()
        if (needsEndpoint && (port == null || port !in 1..65535)) return failure(QrError.InvalidPort)

        return Result.WifiSuccess(Config(modelId, sn, action, ssid, password, ip, port ?: 0))
    }

    private fun parseAction(value: String): Int? {
        if (value.isEmpty() || value.startsWith('-')) return null
        val parsed = if (value.startsWith("0x", ignoreCase = true)) {
            value.drop(2).takeIf { it.isNotEmpty() }?.toLongOrNull(16)
        } else {
            value.takeIf { it.all(Char::isDigit) }?.toLongOrNull(10)
        }
        return parsed?.takeIf { it in 0..Int.MAX_VALUE }?.toInt()
    }

    private fun decode(value: String): String? = runCatching {
        URLDecoder.decode(value, StandardCharsets.UTF_8.name())
    }.getOrNull()

    private fun isNumericIp(value: String): Boolean {
        val ipv4 = value.split('.').let { parts ->
            parts.size == 4 && parts.all { part ->
                part.isNotEmpty() && part.all(Char::isDigit) && (part.toIntOrNull() ?: -1) in 0..255
            }
        }
        val ipv6 = value.contains(':') && value.all { it.isDigit() || it.lowercaseChar() in 'a'..'f' || it == ':' || it == '.' } &&
            runCatching { InetAddress.getByName(value).hostAddress }.isSuccess
        return ipv4 || ipv6
    }

    private fun isLocalVehicleAddress(value: String): Boolean {
        val address = runCatching { InetAddress.getByName(value) }.getOrNull() ?: return false
        return !address.isAnyLocalAddress && !address.isLoopbackAddress && !address.isMulticastAddress &&
            (address.isSiteLocalAddress || address.isLinkLocalAddress)
    }

    private fun failure(error: QrError) = Result.Failure(error)
}
