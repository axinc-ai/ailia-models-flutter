import 'dart:io';

import 'package:ailia_llm/ailia_llm_model.dart';

class LargeLanguageModel {
  final AiliaLLMModel _ailiaLLMModel = AiliaLLMModel();

  List<String> getModelList(){
    List<String> modelList = List<String>.empty(growable: true);

    modelList.add("gemma");
    modelList.add("gemma-2-2b-it-Q4_K_M.gguf");

    return modelList;
  }

  List<Map<String, dynamic>> messages = List<Map<String, dynamic>>.empty(growable:true);
  String systemPrompt = "";

  void open(File model){
    int nCtx = 8192; // 0 for modelDefault
    _ailiaLLMModel.open(model.path, nCtx);
  }

  void setSystemPrompt(String prompt){
    systemPrompt = prompt;
    _addSystemPrompt();
  }

  void _addSystemPrompt(){
    if (systemPrompt == ""){
      return;
    }
    messages.add({"role": "system", "content": systemPrompt});
  }

  String chat(String inputText){
    if (_ailiaLLMModel.contextFull()){
      messages = List<Map<String, dynamic>>.empty(growable:true);
      _addSystemPrompt();
    }

    messages.add({"role": "user", "content": inputText});
    
    _ailiaLLMModel.setPrompt(messages);
    String text = "";
    while(true){
      String? deltaText = _ailiaLLMModel.generate();
      if (deltaText == null){
        break;
      }
      text = text + deltaText;
    }

    messages.add({"role": "assistant", "content": text});
    return text;
  }

  void close(){
    _ailiaLLMModel.close();
  }
}
