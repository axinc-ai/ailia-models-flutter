import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wav/wav.dart';

import 'package:flutter/services.dart';
import 'package:ailia_speech/ailia_speech.dart' as ailia_speech_dart;
import 'package:ailia_speech/ailia_speech_model.dart';

class AudioProcessingWhisper {
  final AiliaSpeechModel _ailiaSpeechModel = AiliaSpeechModel();

  List<String> getModelList(String type){
    List<String> modelList = List<String>.empty(growable: true);

    modelList.add("silero_vad");
    modelList.add("silero_vad.onnx");

    if (type == "whisper_tiny"){
      modelList.add("whisper");
      modelList.add("encoder_tiny.opt3.onnx");
      modelList.add("whisper");
      modelList.add("decoder_tiny_fix_kv_cache.opt3.onnx");
    }
    if (type == "whisper_small"){
      modelList.add("whisper");
      modelList.add("encoder_small.opt3.onnx");
      modelList.add("whisper");
      modelList.add("decoder_small_fix_kv_cache.opt3.onnx");
    }
    if (type == "whisper_medium"){
      modelList.add("whisper");
      modelList.add("encoder_medium.opt3.onnx");
      modelList.add("whisper");
      modelList.add("decoder_medium_fix_kv_cache.opt3.onnx");
    }
    if (type == "whisper_large_v3_turbo"){
      modelList.add("whisper");
      modelList.add("encoder_large_v3_turbo.onnx");
      modelList.add("whisper");
      modelList.add("decoder_large_v3_turbo_fix_kv_cache.opt3.onnx");
      modelList.add("whisper");
      modelList.add("encoder_large_v3_turbo_weights.pb");
    }

    return modelList;
  }
  void _intermediateCallback(String text){
  }

  Future<String> transcribe(Wav wav, File onnx_encoder_file, File onnx_decoder_file, File vad_file, int env_id, String type) async{
    _ailiaSpeechModel.create(false, false, env_id);
    int typeId = 0;
    if (type == "whisper_tiny"){
      typeId = ailia_speech_dart.AILIA_SPEECH_MODEL_TYPE_WHISPER_MULTILINGUAL_TINY;
    }
    if (type == "whisper_small"){
      typeId = ailia_speech_dart.AILIA_SPEECH_MODEL_TYPE_WHISPER_MULTILINGUAL_SMALL;
    }
    if (type == "whisper_medium"){
      typeId = ailia_speech_dart.AILIA_SPEECH_MODEL_TYPE_WHISPER_MULTILINGUAL_MEDIUM;
    }
    if (type == "whisper_large_v3_turbo"){
      typeId = ailia_speech_dart.AILIA_SPEECH_MODEL_TYPE_WHISPER_MULTILINGUAL_LARGE_V3;
    }
    String lang = "auto"; // auto or ja
    _ailiaSpeechModel.open(onnx_encoder_file, onnx_decoder_file, vad_file, lang, typeId);

    List<double> pcm = List<double>.empty(growable: true);

    for (int i = 0; i < wav.channels[0].length; ++i) {
      for (int j = 0; j < wav.channels.length; ++j){
        pcm.add(wav.channels[j][i]);
      }
    }

    //_ailiaSpeechModel.setIntermediateCallback(_intermediateCallback);

    _ailiaSpeechModel.pushInputData(pcm, wav.samplesPerSecond, wav.channels.length);
    _ailiaSpeechModel.finalizeInputData(); // for one shot

    String transcribe_result = "";

    List<SpeechText> texts = _ailiaSpeechModel.transcribeBatch();
    for (int i = 0; i < texts.length; i++){
      transcribe_result = transcribe_result + texts[i].text;
    }

    _ailiaSpeechModel.close();

    return transcribe_result;
  }

}
