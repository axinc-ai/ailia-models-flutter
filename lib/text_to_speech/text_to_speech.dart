﻿import 'package:ailia_voice/ailia_voice.dart' as ailia_voice_dart;
import 'package:ailia_voice/ailia_voice_model.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wav/wav.dart';

import 'package:flutter/services.dart';

import 'dart:typed_data';

class Speaker {
  void play(AiliaVoiceResult audio, String outputPath) async {
    Float64List channel = Float64List(audio.pcm.length);
    for (int i = 0; i < channel.length; i++) {
      channel[i] = audio.pcm[i];
    }

    List<Float64List> channels = List<Float64List>.empty(growable: true);
    channels.add(channel);

    Wav wav = Wav(channels, audio.sampleRate, WavFormat.pcm16bit);

    await wav.writeFile(outputPath);

    final player = AudioPlayer();
    await player.play(DeviceFileSource(outputPath));
  }
}

class TextToSpeech {
  final _speaker = Speaker();
  final _ailiaVoiceModel = AiliaVoiceModel();

  List<String> getModelList(int modelType){
    List<String> modelList = List<String>.empty(growable: true);

    modelList.add("open_jtalk/open_jtalk_dic_utf_8-1.11");
    modelList.add("open_jtalk_dic_utf_8-1.11/char.bin");

    modelList.add("open_jtalk/open_jtalk_dic_utf_8-1.11");
    modelList.add("open_jtalk_dic_utf_8-1.11/COPYING");

    modelList.add("open_jtalk/open_jtalk_dic_utf_8-1.11");
    modelList.add("open_jtalk_dic_utf_8-1.11/left-id.def");

    modelList.add("open_jtalk/open_jtalk_dic_utf_8-1.11");
    modelList.add("open_jtalk_dic_utf_8-1.11/matrix.bin");

    modelList.add("open_jtalk/open_jtalk_dic_utf_8-1.11");
    modelList.add("open_jtalk_dic_utf_8-1.11/pos-id.def");

    modelList.add("open_jtalk/open_jtalk_dic_utf_8-1.11");
    modelList.add("open_jtalk_dic_utf_8-1.11/rewrite.def");

    modelList.add("open_jtalk/open_jtalk_dic_utf_8-1.11");
    modelList.add("open_jtalk_dic_utf_8-1.11/right-id.def");

    modelList.add("open_jtalk/open_jtalk_dic_utf_8-1.11");
    modelList.add("open_jtalk_dic_utf_8-1.11/sys.dic");

    modelList.add("open_jtalk/open_jtalk_dic_utf_8-1.11");
    modelList.add("open_jtalk_dic_utf_8-1.11/unk.dic");

    if (modelType == ailia_voice_dart.AILIA_VOICE_MODEL_TYPE_TACOTRON2){
      modelList.add("tacotron2");
      modelList.add("encoder.onnx");

      modelList.add("tacotron2");
      modelList.add("decoder_iter.onnx");

      modelList.add("tacotron2");
      modelList.add("postnet.onnx");

      modelList.add("tacotron2");
      modelList.add("waveglow.onnx");
    }

    if (modelType == ailia_voice_dart.AILIA_VOICE_MODEL_TYPE_GPT_SOVITS){
      modelList.add("gpt-sovits");
      modelList.add("t2s_encoder.onnx");

      modelList.add("gpt-sovits");
      modelList.add("t2s_fsdec.onnx");

      modelList.add("gpt-sovits");
      modelList.add("t2s_sdec.onnx");

      modelList.add("gpt-sovits");
      modelList.add("vits.onnx");

      modelList.add("gpt-sovits");
      modelList.add("cnhubert.onnx");
    }

    return modelList;
  }

  Future<void> inference(String targetText, String outputPath, String encoderFile, String decoderFile, String postnetFile, String waveglowFile, String ?sslFile, String dicFolder, int modelType) async{
    // Open and Inference
    _ailiaVoiceModel.open(
      encoderFile,
      decoderFile,
      postnetFile,
      waveglowFile,
      sslFile,
      dicFolder,
      modelType,
      ailia_voice_dart.AILIA_VOICE_CLEANER_TYPE_BASIC,
      ailia_voice_dart.AILIA_VOICE_DICTIONARY_TYPE_OPEN_JTALK,
      ailia_voice_dart.AILIA_ENVIRONMENT_ID_AUTO
    );

    if (modelType == ailia_voice_dart.AILIA_VOICE_MODEL_TYPE_GPT_SOVITS){
      ByteData data = await rootBundle.load("assets/reference_audio_girl.wav");
      final wav = Wav.read(data.buffer.asUint8List());

      List<double> pcm = List<double>.empty(growable: true);

      for (int i = 0; i < wav.channels[0].length; ++i) {
        for (int j = 0; j < wav.channels.length; ++j){
          pcm.add(wav.channels[j][i]);
        }
      }

      String referenceFeature = _ailiaVoiceModel.g2p("水をマレーシアから買わなくてはならない。", ailia_voice_dart.AILIA_VOICE_TEXT_POST_PROCESS_APPEND_PUNCTUATION);
      _ailiaVoiceModel.setReference(pcm, wav.samplesPerSecond, wav.channels.length, referenceFeature);
    }

    // Get Audio and Play
    String targetFeature = targetText;
    if (modelType == ailia_voice_dart.AILIA_VOICE_MODEL_TYPE_GPT_SOVITS){
      targetFeature = _ailiaVoiceModel.g2p(targetText, ailia_voice_dart.AILIA_VOICE_TEXT_POST_PROCESS_APPEND_PUNCTUATION);
    }
    final audio = _ailiaVoiceModel.inference(targetFeature);
    _speaker.play(audio, outputPath);

    // Terminate
    _ailiaVoiceModel.close();

  }
}
