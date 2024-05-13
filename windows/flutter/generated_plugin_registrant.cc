//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <ailia/ailia_plugin_c_api.h>
#include <ailia_audio/ailia_audio_plugin_c_api.h>
#include <ailia_speech/ailia_speech_plugin_c_api.h>
#include <ailia_tokenizer/ailia_tokenizer_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  AiliaPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AiliaPluginCApi"));
  AiliaAudioPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AiliaAudioPluginCApi"));
  AiliaSpeechPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AiliaSpeechPluginCApi"));
  AiliaTokenizerPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AiliaTokenizerPluginCApi"));
}
