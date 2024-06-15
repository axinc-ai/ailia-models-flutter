import 'dart:io';

import 'package:ailia_speech/ailia_speech_model.dart';

class NaturalLanguageProcessingFuguMT {
  final AiliaSpeechModel _ailiaSpeechModel = AiliaSpeechModel();

  List<String> getModelList(bool jaEn){
    List<String> modelList = List<String>.empty(growable: true);

    if (jaEn){
      modelList.add("fugumt-ja-en");
      modelList.add("fugumt-ja-en/encoder_model.onnx");

      modelList.add("fugumt-ja-en");
      modelList.add("fugumt-ja-en/decoder_model.onnx");

      modelList.add("fugumt-ja-en");
      modelList.add("fugumt-ja-en/source.spm");

      modelList.add("fugumt-ja-en");
      modelList.add("fugumt-ja-en/target.spm");
    }else{
      modelList.add("fugumt-en-ja");
      modelList.add("fugumt-en-ja/seq2seq-lm-with-past.onnx");

      modelList.add("fugumt-en-ja");
      modelList.add("fugumt-en-ja/source.spm");

      modelList.add("fugumt-en-ja");
      modelList.add("fugumt-en-ja/target.spm");
    }

    return modelList;
  }

  String translate(String inputText, File encoder, File? decoder, File source, File target, bool jaEn, int envId){
    _ailiaSpeechModel.create(false, false, envId);
    _ailiaSpeechModel.postprocess(encoder, decoder, source, target, jaEn);
    String text = _ailiaSpeechModel.translate(inputText);
    _ailiaSpeechModel.close();
    return text;
  }
}
