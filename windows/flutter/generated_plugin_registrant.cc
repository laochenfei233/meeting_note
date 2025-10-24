//
// Generated file. Do not edit.
//

#include "generated_plugin_registrant.h"

// Include flutter_webrtc plugin
extern "C" __declspec(dllexport) void FlutterWebRTCPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterWebRTCPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterWebRTCPlugin"));
}