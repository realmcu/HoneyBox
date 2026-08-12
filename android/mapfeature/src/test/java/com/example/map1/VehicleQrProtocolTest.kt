package com.example.map1

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class VehicleQrProtocolTest {
    private val wifiSample = "https://github.com/realmcu/HoneyBox/releases/download/v0.8.7/HoneyBox.apk" +
        "?modelid=RTL8782&sn=0529&action=513&ssid=ECTinyPlus_RTL8782&pwd=12345678" +
        "&ip=192.168.43.1&port=5004"
    private val bleSample = "https://github.com/realmcu/HoneyBox/releases/latest/download/HoneyBox.apk" +
        "?modelid=RTL8773G&sn=0529&addr=C2%3A18%3A3F%3A91%3A72%3A44"

    @Test
    fun parsesWifiSampleAsCombinedFlags() {
        val result = VehicleQrProtocol.parse(wifiSample)
        assertTrue(result is VehicleQrProtocol.Result.WifiSuccess)
        val config = (result as VehicleQrProtocol.Result.WifiSuccess).config
        assertEquals(0x201, config.action)
        assertTrue(config.connectsVehicleAp)
        assertTrue(config.customLocalAp)
        assertEquals("0529", config.serialNumber)
    }

    @Test
    fun acceptsExplicitHexAction() {
        val result = VehicleQrProtocol.parse(wifiSample.replace("action=513", "action=0x201"))
        assertEquals(0x201, (result as VehicleQrProtocol.Result.WifiSuccess).config.action)
    }

    @Test
    fun parsesRtl8773ModelsWithStaticAddress() {
        val g = VehicleQrProtocol.parse(bleSample)
        assertTrue(g is VehicleQrProtocol.Result.BleSuccess)
        val config = (g as VehicleQrProtocol.Result.BleSuccess).config
        assertEquals("RTL8773G", config.modelId)
        assertEquals("C2:18:3F:91:72:44", config.address)
        assertEquals(
            "https://github.com/realmcu/HoneyBox/releases/latest/download/HoneyBox.apk",
            config.apkUrl,
        )

        val e = VehicleQrProtocol.parse(bleSample.replace("RTL8773G", "RTL8773E"))
        assertTrue(e is VehicleQrProtocol.Result.BleSuccess)
    }

    @Test
    fun acceptsPublicAndStaticAddressesButRejectsReservedValues() {
        val publicAddress = VehicleQrProtocol.parse(bleSample.replace("C2%3A", "42%3A"))
        assertTrue(publicAddress is VehicleQrProtocol.Result.BleSuccess)
        assertTrue(
            VehicleQrProtocol.parse(bleSample.replace("C2%3A18%3A3F%3A91%3A72%3A44", "00%3A00%3A00%3A00%3A00%3A00")) is VehicleQrProtocol.Result.Failure,
        )
        assertTrue(VehicleQrProtocol.parse("$bleSample&port=5004") is VehicleQrProtocol.Result.Failure)
    }

    @Test
    fun rejectsInvalidWifiInputsAndDuplicateFields() {
        assertTrue(
            VehicleQrProtocol.parse(wifiSample.replace("action=513", "action=503")) is VehicleQrProtocol.Result.Failure,
        )
        assertTrue(
            VehicleQrProtocol.parse(wifiSample.replace("modelid=RTL8782", "modelid=59301")) is VehicleQrProtocol.Result.Failure,
        )
        assertTrue(VehicleQrProtocol.parse("$wifiSample&port=5005") is VehicleQrProtocol.Result.Failure)
    }
}
