package com.example.map1

import android.annotation.SuppressLint
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanRecord
import android.os.ParcelUuid
import java.util.UUID

/**
 * Advertising-data admission rule for the dashboard's manual "add device" scan.
 *
 * HoneyProtocol only specifies the GATT side (HMIS service 484D4953-...). The
 * advertisement layout is NOT normative, so this rule is deliberately tolerant:
 * a device is admitted when either
 *   1) the HMIS service UUID shows up in AdvData / ScanResponse (as an advertised
 *      service UUID or as a service-data field), or
 *   2) any manufacturer-specific data carries Realtek's SIG company id 0x005D.
 *
 * Both conditions are pushed to the framework as [ScanFilter]s. Android ORs the
 * filters, so the callback receives the union. The GATT discovery in
 * [VehicleBleManager] is still the final proof: a device that merely matched the
 * advertisement but lacks HMIS / 0xFFC1 / 0xFFC2 ends up in State.Error.
 */
object VehicleAdvFilter {

    /** HoneyProtocol 2.2.1 "BLE HMIS private service". */
    val HMIS_SERVICE_UUID: UUID = UUID.fromString("484D4953-0000-1000-8000-00805F9B34FB")

    /** Bluetooth SIG company identifier: Realtek Semiconductor Corporation. */
    const val REALTEK_COMPANY_ID = 0x005D

    /** Which rule admitted the device — surfaced in the list so field tests are debuggable. */
    sealed interface Match {
        val label: String

        data object HmisService : Match {
            override val label: String = "HMIS 服务 UUID"
        }

        data object HmisServiceData : Match {
            override val label: String = "HMIS 服务数据"
        }

        data object RealtekManufacturer : Match {
            override val label: String = "Realtek 厂商 ID"
        }
    }

    /**
     * The 6-byte manufacturer payload the firmware is expected to broadcast
     * (docs/vehicle-adv-spec.md). Every field is best-effort: a device that only
     * carries the company id still lists, it just has no readable detail.
     */
    data class AdvInfo(
        val version: Int,
        val modelCode: Int,
        val modelName: String?,
        val capabilities: Int,
        val batteryPercent: Int?,
        val shortId: Int?,
    ) {
        val naviReady: Boolean get() = (capabilities and CAP_NAVI_READY) != 0
        val bound: Boolean get() = (capabilities and CAP_BOUND) != 0
        val charging: Boolean get() = (capabilities and CAP_CHARGING) != 0
    }

    private const val CAP_NAVI_READY = 0x01
    private const val CAP_BOUND = 0x02
    private const val CAP_CHARGING = 0x04

    private const val PAYLOAD_VERSION = 0x01
    private const val MIN_PAYLOAD_BYTES = 6
    private const val BATTERY_UNKNOWN = 0xFF

    private val modelNames = mapOf(
        0x01 to "RTL8773G",
        0x02 to "RTL8773E",
        0x03 to "RTL8782",
    )

    /**
     * Framework-level filters (OR semantics). Passing `null` data/mask to
     * [ScanFilter.Builder.setManufacturerData] means "any payload for this id".
     */
    fun scanFilters(): List<ScanFilter> = listOf(
        ScanFilter.Builder()
            .setServiceUuid(ParcelUuid(HMIS_SERVICE_UUID))
            .build(),
        ScanFilter.Builder()
            .setManufacturerData(REALTEK_COMPANY_ID, null, null)
            .build(),
    )

    /** Software-side re-check of the same rule; used for badges and for "show all" sessions. */
    fun match(record: ScanRecord?): Match? {
        if (record == null) return null

        record.serviceUuids?.forEach { advertised ->
            if (advertised.uuid == HMIS_SERVICE_UUID) return Match.HmisService
        }
        record.serviceData?.keys?.forEach { serviceDataUuid ->
            if (serviceDataUuid.uuid == HMIS_SERVICE_UUID) return Match.HmisServiceData
        }
        if (record.getManufacturerSpecificData(REALTEK_COMPANY_ID) != null) {
            return Match.RealtekManufacturer
        }
        return null
    }

    /**
     * Decodes the 6-byte manufacturer payload described in docs/vehicle-adv-spec.md.
     * Returns null when the device carries no Realtek payload (or one that is too
     * short to be ours) — callers then fall back to the raw hex digest.
     */
    fun parseInfo(record: ScanRecord?): AdvInfo? {
        val payload = record?.getManufacturerSpecificData(REALTEK_COMPANY_ID) ?: return null
        if (payload.size < MIN_PAYLOAD_BYTES) return null
        if ((payload[0].toInt() and 0xFF) != PAYLOAD_VERSION) return null

        val modelCode = payload[1].toInt() and 0xFF
        val battery = payload[3].toInt() and 0xFF
        return AdvInfo(
            version = payload[0].toInt() and 0xFF,
            modelCode = modelCode,
            modelName = modelNames[modelCode],
            capabilities = payload[2].toInt() and 0xFF,
            batteryPercent = if (battery == BATTERY_UNKNOWN || battery > 100) null else battery,
            shortId = ((payload[4].toInt() and 0xFF) shl 8) or (payload[5].toInt() and 0xFF),
        )
    }

    /** One-line digest of everything the advertisement carries, for the device row. */
    @SuppressLint("MissingPermission")
    @Suppress("DEPRECATION")
    fun describe(record: ScanRecord?): String {
        if (record == null) return "无广播数据"
        val parts = mutableListOf<String>()

        record.serviceUuids?.forEach { parts += "SVC ${shortUuid(it.uuid)}" }
        record.serviceData?.forEach { (uuid, data) ->
            parts += "SD ${shortUuid(uuid.uuid)}=${hex(data)}"
        }
        record.manufacturerSpecificData?.let { manufacturer ->
            for (i in 0 until manufacturer.size()) {
                val id = manufacturer.keyAt(i)
                val prefix = "MFG 0x${id.toString(16).uppercase().padStart(4, '0')}"
                parts += "$prefix=${hex(manufacturer.valueAt(i))}"
            }
        }
        return if (parts.isEmpty()) "无广播内容" else parts.joinToString("   ")
    }

    private fun shortUuid(uuid: UUID): String {
        val text = uuid.toString().uppercase()
        return if (text.length == 36 &&
            text.startsWith("0000") &&
            text.endsWith("-0000-1000-8000-00805F9B34FB")
        ) {
            "0x${text.substring(4, 8)}"
        } else {
            text
        }
    }

    private fun hex(bytes: ByteArray?): String {
        if (bytes == null || bytes.isEmpty()) return "-"
        return bytes.joinToString(separator = "") { "%02X".format(it) }
    }
}
