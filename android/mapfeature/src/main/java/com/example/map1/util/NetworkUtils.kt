package com.example.map1.util

import java.net.Inet4Address
import java.net.InetAddress
import java.net.NetworkInterface
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * 局域网中发现的一台设备。
 *
 * @param ip       IPv4 地址，如 "172.20.10.6"
 * @param hostName 反向解析得到的设备名；解析不到时与 [ip] 相同
 */
data class LanDevice(
    val ip: String,
    val hostName: String,
) {
    /** 下拉框中展示用的标签：有设备名时显示「名称 (ip)」，否则只显示 ip。 */
    val label: String
        get() = if (hostName.isNotBlank() && hostName != ip) "$hostName ($ip)" else ip
}

/**
 * 网络相关工具：获取本机在局域网（WLAN）中的 IPv4 地址，用于推断接收端同网段地址。
 */
object NetworkUtils {

    /**
     * 返回本机第一个非回环的 IPv4 局域网地址，例如 "172.20.10.3"。
     * 优先选择 wlan（WiFi）接口；找不到时返回 null。
     */
    fun getLocalIpv4(): String? {
        return try {
            val interfaces = NetworkInterface.getNetworkInterfaces()?.toList().orEmpty()
            // 优先 wlan，再其他非回环接口
            val ordered = interfaces.sortedByDescending { it.name.startsWith("wlan") }
            for (nif in ordered) {
                if (!nif.isUp || nif.isLoopback) continue
                for (addr in nif.inetAddresses) {
                    if (addr is Inet4Address && !addr.isLoopbackAddress && addr.isSiteLocalAddress) {
                        return addr.hostAddress
                    }
                }
            }
            null
        } catch (_: Exception) {
            null
        }
    }

    /**
     * 根据本机 IP 推断同网段的默认接收端地址：保留前三段，最后一段用 [lastOctet]。
     * 例如本机 "172.20.10.3" -> "172.20.10.6"。无法获取本机 IP 时返回 [fallback]。
     */
    fun guessSameSubnetHost(lastOctet: Int = 6, fallback: String = ""): String {
        val ip = getLocalIpv4() ?: return fallback
        val parts = ip.split(".")
        if (parts.size != 4) return fallback
        return "${parts[0]}.${parts[1]}.${parts[2]}.$lastOctet"
    }

    /**
     * 扫描本机所在的 /24 网段（前三段相同，最后一段 1..254），并发探测哪些 IP 在线，
     * 再尝试反向解析设备名。
     *
     * 仅适用于常见的 /24 家用/热点网络（如 192.168.x.x、172.20.10.x）。这是一个耗时操作，
     * **必须在后台线程调用**（如 Dispatchers.IO）。
     *
     * @param timeoutMs    单个 IP 的可达性探测超时（毫秒）
     * @param onProgress   进度回调（已探测数 / 总数），在工作线程触发，UI 更新需自行切主线程
     * @return 在线设备列表，按 IP 末段升序排列；本机 IP 也会包含在内
     */
    fun scanLan(
        timeoutMs: Int = 300,
        onProgress: ((scanned: Int, total: Int) -> Unit)? = null,
    ): List<LanDevice> {
        val localIp = getLocalIpv4() ?: return emptyList()
        val parts = localIp.split(".")
        if (parts.size != 4) return emptyList()
        val prefix = "${parts[0]}.${parts[1]}.${parts[2]}."

        val total = 254
        val pool = Executors.newFixedThreadPool(64)
        val found = java.util.concurrent.ConcurrentLinkedQueue<LanDevice>()
        val scanned = java.util.concurrent.atomic.AtomicInteger(0)
        try {
            for (i in 1..254) {
                val host = "$prefix$i"
                pool.execute {
                    try {
                        val addr = InetAddress.getByName(host)
                        if (addr.isReachable(timeoutMs)) {
                            // 设备名解析优先级：NetBIOS 名（对 Windows/部分设备有效）> 反向 DNS > IP
                            val name = queryNetbiosName(host)
                                ?: runCatching { addr.canonicalHostName }.getOrNull()
                                ?: host
                            found.add(LanDevice(ip = host, hostName = name))
                        }
                    } catch (_: Exception) {
                        // 忽略单个地址的探测异常
                    } finally {
                        onProgress?.invoke(scanned.incrementAndGet(), total)
                    }
                }
            }
            pool.shutdown()
            // 最长等待：全部任务串行最坏情况，给足余量
            pool.awaitTermination((timeoutMs.toLong() * total / 8) + 5_000, TimeUnit.MILLISECONDS)
        } catch (_: Exception) {
            // 忽略
        } finally {
            pool.shutdownNow()
        }
        return found.sortedBy { it.ip.substringAfterLast('.').toIntOrNull() ?: 999 }
    }

    /**
     * 通过 NetBIOS 名称服务（UDP 137）查询设备名。对 Windows、群晖、部分智能设备有效；
     * Linux/Mac/Android 设备通常不响应，返回 null。这是一个尽力而为的查询。
     */
    private fun queryNetbiosName(ip: String, timeoutMs: Int = 200): String? {
        return try {
            // NBSTAT 查询包（标准 NetBIOS node status request，查询名 "*"）
            val query = byteArrayOf(
                0xA2.toByte(), 0x48, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x20, 0x43, 0x4B, 0x41,
                0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
                0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
                0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
                0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
                0x41, 0x00, 0x00, 0x21, 0x00, 0x01,
            )
            java.net.DatagramSocket().use { socket ->
                socket.soTimeout = timeoutMs
                val addr = InetAddress.getByName(ip)
                socket.send(java.net.DatagramPacket(query, query.size, addr, 137))
                val buf = ByteArray(1024)
                val resp = java.net.DatagramPacket(buf, buf.size)
                socket.receive(resp)
                parseNetbiosResponse(buf, resp.length)
            }
        } catch (_: Exception) {
            null
        }
    }

    /** 从 NBSTAT 响应中提取第一个 NetBIOS 名（去掉尾部空格与服务后缀）。 */
    private fun parseNetbiosResponse(data: ByteArray, length: Int): String? {
        return try {
            // 响应头 + 名字数量字节位置（标准 NBSTAT 响应结构）
            val numNamesOffset = 56
            if (length <= numNamesOffset) return null
            val numNames = data[numNamesOffset].toInt() and 0xFF
            if (numNames <= 0) return null
            var offset = numNamesOffset + 1
            // 每条记录 18 字节：15 字节名 + 1 字节后缀 + 2 字节标志
            val nameBytes = data.copyOfRange(offset, offset + 15)
            val name = String(nameBytes, Charsets.US_ASCII).trim()
            name.ifBlank { null }
        } catch (_: Exception) {
            null
        }
    }
}
