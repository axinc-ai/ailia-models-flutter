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

  void open(File model){
    int nCtx = 8192; // 0 for modelDefault
    _ailiaLLMModel.open(model.path, nCtx);
  }

  void setSystemPrompt(String prompt){
    messages.add({"role": "system", "content": prompt});
  }

  String chat(String inputText){
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
