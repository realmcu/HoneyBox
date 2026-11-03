//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_blue_plus_winrt/flutter_blue_plus_plugin.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>
#include <watch_transport_ble/watch_transport_ble_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterBluePlusPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterBluePlusPlugin"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
  WatchTransportBlePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WatchTransportBlePluginCApi"));
}
