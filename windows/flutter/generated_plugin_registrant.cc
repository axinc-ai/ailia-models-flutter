//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <ailia/ailia_plugin_c_api.h>
#include <ailia_audio/ailia_audio_plugin_c_api.h>
#include <ailia_llm/ailia_llm_plugin_c_api.h>
#include <ailia_speech/ailia_speech_plugin_c_api.h>
#include <ailia_tokenizer/ailia_tokenizer_plugin_c_api.h>
#include <ailia_voice/ailia_voice_plugin_c_api.h>
#include <audioplayers_windows/audioplayers_windows_plugin.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  AiliaPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AiliaPluginCApi"));
  AiliaAudioPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AiliaAudioPluginCApi"));
  AiliaLlmPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AiliaLlmPluginCApi"));
  AiliaSpeechPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AiliaSpeechPluginCApi"));
  AiliaTokenizerPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AiliaTokenizerPluginCApi"));
  AiliaVoicePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AiliaVoicePluginCApi"));
  AudioplayersWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AudioplayersWindowsPlugin"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
}
