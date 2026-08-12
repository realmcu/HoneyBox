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
        data class Failure(val message: String) : Result
    }

    fun parse(raw: String): Result {
        if (raw.toByteArray(StandardCharsets.UTF_8).size > MAX_PAYLOAD_BYTES) return failure("二维码内容过长")
        val uri = runCatching { URI(raw) }.getOrNull() ?: return failure("二维码不是有效 URL")
        if (!uri.isAbsolute || uri.scheme.isNullOrBlank() || uri.host.isNullOrBlank()) return failure("二维码必须是绝对 URL")
        if (uri.rawFragment != null || uri.userInfo != null) return failure("二维码 URL 包含不允许的片段或用户信息")

        val values = linkedMapOf<String, String>()
        val rawQuery = uri.rawQuery ?: return failure("二维码缺少车辆参数")
        for (part in rawQuery.split('&')) {
            if (part.isEmpty()) return failure("二维码包含空参数")
            val separator = part.indexOf('=')
            if (separator <= 0) return failure("二维码参数格式错误")
            val key = decode(part.substring(0, separator)) ?: return failure("二维码参数编码错误")
            val value = decode(part.substring(separator + 1)) ?: return failure("二维码参数编码错误")
            if (key !in allowedKeys) return failure("二维码包含未知参数：$key")
            if (values.put(key, value) != null) return failure("二维码参数重复：$key")
        }

        fun required(name: String): String? = values[name]
        val modelId = required("modelid") ?: return failure("缺少 modelid")
        val sn = required("sn") ?: return failure("缺少 sn")
        if (sn.isBlank() || sn.length > MAX_SN_LENGTH || sn.any(Char::isISOControl)) return failure("sn 无效")

        if (modelId == MODEL_ID_RTL8773G || modelId == MODEL_ID_RTL8773E) {
            val unexpected = values.keys - bleKeys
            if (unexpected.isNotEmpty()) return failure("BLE 车型包含不适用参数：${unexpected.first()}")
            val address = required("addr") ?: return failure("缺少 addr")
            if (!bleAddress.matches(address)) return failure("addr 必须是 BLE 地址，例如 C2:18:3F:91:72:44")
            if (address.equals("00:00:00:00:00:00", ignoreCase = true) ||
                address.equals("FF:FF:FF:FF:FF:FF", ignoreCase = true)
            ) return failure("addr 不能是全 0 或广播地址")
            return Result.BleSuccess(
                BleConfig(modelId, sn, address.uppercase(), "${uri.scheme}://${uri.rawAuthority}${uri.rawPath.orEmpty()}"),
            )
        }
        if (modelId != MODEL_ID_RTL8782) return failure("不支持的车型型号：$modelId")

        val unexpected = values.keys - wifiKeys
        if (unexpected.isNotEmpty()) return failure("RTL8782 包含不适用参数：${unexpected.first()}")
        val actionText = required("action") ?: return failure("缺少 action")
        val action = parseAction(actionText) ?: return failure("action 必须是十进制或 0x 十六进制非负整数")
        val supportedActionMask = ACTION_PHONE_CONNECTS_VEHICLE_AP or ACTION_CUSTOM_LOCAL_AP
        if (action and supportedActionMask.inv() != 0) return failure("action 包含当前不支持的标志位")
        val connects = action and ACTION_PHONE_CONNECTS_VEHICLE_AP != 0
        val custom = action and ACTION_CUSTOM_LOCAL_AP != 0
        if (connects && !custom) return failure("0x200 标准车辆 AP 参数推导尚未实现；需要 0x001 自定义 AP 参数")

        val needsEndpoint = connects || custom
        val ssid = required("ssid").orEmpty()
        val password = required("pwd").orEmpty()
        val ip = required("ip").orEmpty()
        val portText = required("port").orEmpty()
        if (needsEndpoint) {
            if (listOf("ssid", "pwd", "ip", "port").any { it !in values }) return failure("当前 action 需要 ssid、pwd、ip 和 port")
            val ssidBytes = ssid.toByteArray(StandardCharsets.UTF_8).size
            if (ssidBytes !in 1..32 || ssid.any(Char::isISOControl)) return failure("SSID 必须为 1–32 个 UTF-8 字节")
            val validPassword = (password.length in 8..63 ||
                password.length == 64 && password.all { it.isDigit() || it.lowercaseChar() in 'a'..'f' }) &&
                password.none(Char::isISOControl)
            if (!validPassword) return failure("Wi-Fi 密码必须为 8–63 个字符或 64 位十六进制")
            if (!isNumericIp(ip)) return failure("ip 必须是数字 IP 地址")
            if (!isLocalVehicleAddress(ip)) return failure("ip 必须是车辆局域网地址")
        }
        val port = portText.toIntOrNull()
        if (needsEndpoint && (port == null || port !in 1..65535)) return failure("port 必须在 1–65535 范围内")

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

    private fun failure(message: String) = Result.Failure(message)
}
