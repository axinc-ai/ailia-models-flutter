//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import ailia
import ailia_audio
import ailia_llm
import ailia_speech
import ailia_tokenizer
import ailia_voice
import audioplayers_darwin
import path_provider_foundation

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AiliaPlugin.register(with: registry.registrar(forPlugin: "AiliaPlugin"))
  AiliaAudioPlugin.register(with: registry.registrar(forPlugin: "AiliaAudioPlugin"))
  AiliaLlmPlugin.register(with: registry.registrar(forPlugin: "AiliaLlmPlugin"))
  AiliaSpeechPlugin.register(with: registry.registrar(forPlugin: "AiliaSpeechPlugin"))
  AiliaTokenizerPlugin.register(with: registry.registrar(forPlugin: "AiliaTokenizerPlugin"))
  AiliaVoicePlugin.register(with: registry.registrar(forPlugin: "AiliaVoicePlugin"))
  AudioplayersDarwinPlugin.register(with: registry.registrar(forPlugin: "AudioplayersDarwinPlugin"))
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
}
