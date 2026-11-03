#ifndef FLUTTER_PLUGIN_WATCH_TRANSPORT_BLE_PLUGIN_C_API_H_
#define FLUTTER_PLUGIN_WATCH_TRANSPORT_BLE_PLUGIN_C_API_H_
#include <flutter_plugin_registrar.h>
#ifdef FLUTTER_PLUGIN_IMPL
#define WATCH_BLE_EXPORT __declspec(dllexport)
#else
#define WATCH_BLE_EXPORT __declspec(dllimport)
#endif
#ifdef __cplusplus
extern "C" {
#endif
WATCH_BLE_EXPORT void WatchTransportBlePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);
#ifdef __cplusplus
}
#endif
#endif
