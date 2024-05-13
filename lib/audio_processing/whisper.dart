import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wav/wav.dart';

import 'package:flutter/services.dart';
import 'package:ailia_speech/ailia_speech.dart' as ailia_speech_dart;
import 'package:ailia_speech/ailia_speech_model.dart';

class AudioProcessingWhisper {
  final AiliaSpeechModel _ailiaSpeechModel = AiliaSpeechModel();

  void _intermediateCallback(String text){
  }

  Future<String> transcribe(Wav wav, File onnx_encoder_file, File onnx_decoder_file) async{
    _ailiaSpeechModel.create(false, false, ailia_speech_dart.AILIA_ENVIRONMENT_ID_AUTO);
    _ailiaSpeechModel.open(onnx_encoder_file, onnx_decoder_file, null, "auto", ailia_speech_dart.AILIA_SPEECH_MODEL_TYPE_WHISPER_MULTILINGUAL_TINY);

    List<double> pcm = List<double>.empty(growable: true);

    for (int i = 0; i < wav.channels[0].length; ++i) {
      for (int j = 0; j < wav.channels.length; ++j){
        pcm.add(wav.channels[j][i]);
      }
    }

    //_ailiaSpeechModel.setIntermediateCallback(_intermediateCallback);
    _ailiaSpeechModel.pushInputData(pcm, wav.samplesPerSecond, wav.channels.length);

    _ailiaSpeechModel.finalizeInputData();

    String transcribe_result = "";

    List<SpeechText> texts = _ailiaSpeechModel.transcribeBatch();
    for (int i = 0; i < texts.length; i++){
      transcribe_result = transcribe_result + texts[i].text;
    }
    

    _ailiaSpeechModel.close();

    return transcribe_result;
  }

}
