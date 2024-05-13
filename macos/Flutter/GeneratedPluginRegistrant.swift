//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import ailia
import ailia_audio
import ailia_speech
import ailia_tokenizer
import path_provider_foundation

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AiliaPlugin.register(with: registry.registrar(forPlugin: "AiliaPlugin"))
  AiliaAudioPlugin.register(with: registry.registrar(forPlugin: "AiliaAudioPlugin"))
  AiliaSpeechPlugin.register(with: registry.registrar(forPlugin: "AiliaSpeechPlugin"))
  AiliaTokenizerPlugin.register(with: registry.registrar(forPlugin: "AiliaTokenizerPlugin"))
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
}
