package com.example.map1

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Process-local vehicle Wi-Fi session. It never binds the process: AMap and normal internet traffic
 * keep using Android's default network, while vehicle TCP sockets use [selectedNetwork].
 */
object VehicleWifiManager {
    sealed interface State {
        data object Idle : State
        data class ApprovalPending(val ssid: String) : State
        data class Available(val ssid: String) : State
        data class Lost(val ssid: String) : State
        data class Error(val error: WifiError) : State
    }

    private val mutableState = MutableStateFlow<State>(State.Idle)
    val state: StateFlow<State> = mutableState

    private var connectivityManager: ConnectivityManager? = null
    private var callback: ConnectivityManager.NetworkCallback? = null
    private var generation = 0L
    @Volatile private var network: Network? = null

    val selectedNetwork: Network? get() = network

    @Synchronized
    fun connect(context: Context, config: VehicleQrProtocol.Config) {
        disconnect()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            mutableState.value = State.Error(WifiError.LegacyAndroid)
            return
        }
        val appContext = context.applicationContext
        val wifiManager = appContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        if (!wifiManager.isWifiEnabled) {
            mutableState.value = State.Error(WifiError.WifiOff)
            return
        }

        val manager = appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        connectivityManager = manager
        val currentGeneration = ++generation
        val specifier = try {
            WifiNetworkSpecifier.Builder()
                .setSsid(config.ssid)
                .setWpa2Passphrase(config.password)
                .build()
        } catch (_: IllegalArgumentException) {
            mutableState.value = State.Error(WifiError.InvalidCredentials)
            return
        }
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specifier)
            .build()
        val ssid = config.ssid
        val newCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(availableNetwork: Network) {
                synchronized(this@VehicleWifiManager) {
                    if (generation != currentGeneration) return
                    network = availableNetwork
                    mutableState.value = State.Available(ssid)
                }
            }

            override fun onLost(lostNetwork: Network) {
                synchronized(this@VehicleWifiManager) {
                    if (generation != currentGeneration || network != lostNetwork) return
                    network = null
                    mutableState.value = State.Lost(ssid)
                }
            }

            override fun onUnavailable() {
                synchronized(this@VehicleWifiManager) {
                    if (generation != currentGeneration) return
                    network = null
                    mutableState.value = State.Error(WifiError.Unavailable)
                }
            }
        }
        callback = newCallback
        mutableState.value = State.ApprovalPending(ssid)
        try {
            // Android will show its system approval UI. The request must remain registered for the session.
            manager.requestNetwork(request, newCallback, REQUEST_TIMEOUT_MS)
        } catch (e: SecurityException) {
            callback = null
            mutableState.value = State.Error(WifiError.MissingPermission)
        } catch (_: RuntimeException) {
            callback = null
            mutableState.value = State.Error(WifiError.CannotRequest)
        }
    }

    @Synchronized
    fun disconnect() {
        generation++
        network = null
        val oldCallback = callback
        callback = null
        if (oldCallback != null) {
            try {
                connectivityManager?.unregisterNetworkCallback(oldCallback)
            } catch (_: RuntimeException) {
                // Callback may already have been removed by Android.
            }
        }
        connectivityManager = null
        mutableState.value = State.Idle
    }

    private const val REQUEST_TIMEOUT_MS = 45_000
}
