import 'dart:io';
import 'dart:isolate';

import 'package:ailia_llm/ailia_llm_model.dart';
import 'package:http/http.dart' as http;

/// Everything the inference isolate needs, passed as the spawn argument.
class _VlmRequest {
  final SendPort sendPort;
  final String modelPath;
  final String mmprojPath;
  final String backend;
  final int nCtx;
  final String systemPrompt;
  final String inputText;
  final String imagePath;

  const _VlmRequest({
    required this.sendPort,
    required this.modelPath,
    required this.mmprojPath,
    required this.backend,
    required this.nCtx,
    required this.systemPrompt,
    required this.inputText,
    required this.imagePath,
  });
}

/// Runs one open -> generate -> close cycle off the UI thread, streaming
/// each token back as {"delta": ...} and ending with {"done": fullText}
/// or {"error": message}.
void _vlmIsolateFunc(_VlmRequest request) {
  final llm = AiliaLLMModel();
  try {
    List<String> backendList = AiliaLLMModel.getBackendList();
    if (!backendList.contains(request.backend)) {
      throw Exception(
          "Backend '${request.backend}' not available. Available: $backendList");
    }

    llm.open(request.modelPath, request.nCtx, backend: request.backend);
    llm.openMultimodalProjectorFile(request.mmprojPath);

    Map<String, bool> capabilities = llm.getMultimodalCapabilities();
    if (capabilities['vision'] != true) {
      throw Exception("Vision capabilities not available");
    }

    final messages = <Map<String, dynamic>>[];
    if (request.systemPrompt.isNotEmpty) {
      messages.add({"role": "system", "content": request.systemPrompt});
    }
    messages.add({
      "role": "user",
      "content": "${request.inputText} <__media__>",
      "media_data": [
        {
          "media_type": "image",
          "file_path": request.imagePath,
          "width": 0,
          "height": 0
        }
      ]
    });
    llm.setPrompt(messages);

    final text = StringBuffer();
    while (true) {
      String? deltaText = llm.generate();
      if (deltaText == null) {
        break;
      }
      text.write(deltaText);
      request.sendPort.send({"delta": deltaText});
    }
    request.sendPort.send({"done": text.toString()});
  } catch (e) {
    request.sendPort.send({"error": "$e"});
  } finally {
    llm.close();
  }
}

/// Multimodal (image + text) LLM inference. The heavy native calls
/// (model load and token generation) run in a spawned isolate so the UI
/// thread never blocks; tokens stream back through [chatWithImage]'s
/// onDelta callback.
class MultimodalLargeLanguageModel {
  Isolate? _isolate;
  ReceivePort? _receivePort;

  static String modelFileName(String type) {
    if (type == 'gemma4-e2b-multimodal') {
      return "gemma-4-E2B-it-Q4_K_M.gguf";
    }
    return "gemma-3-4b-it-Q4_K_M.gguf";
  }

  static String mmprojFileName(String type) {
    if (type == 'gemma4-e2b-multimodal') {
      return "gemma-4-E2B-it-mmproj-F16.gguf";
    }
    return "gemma-3-4b-it-GGUF_mmproj-model-f16.gguf";
  }

  static int contextSize(String type) {
    if (type == 'gemma4-e2b-multimodal') {
      return 16384;
    }
    return 8192;
  }

  List<String> getModelList([String type = 'gemma3-multimodal']) {
    List<String> modelList = List<String>.empty(growable: true);

    modelList.add("gemma");
    modelList.add(modelFileName(type));
    modelList.add("gemma");
    modelList.add(mmprojFileName(type));

    return modelList;
  }

  /// Describes [imagePath] guided by [inputText], reporting each
  /// generated token through [onDelta]. Cancelling with [cancel]
  /// resolves the future with the text generated so far.
  Future<String> chatWithImage({
    required File model,
    required File mmproj,
    required String backend,
    required int nCtx,
    required String systemPrompt,
    required String inputText,
    required String imagePath,
    void Function(String delta)? onDelta,
  }) async {
    final receivePort = ReceivePort();
    _receivePort = receivePort;
    _isolate = await Isolate.spawn(
      _vlmIsolateFunc,
      _VlmRequest(
        sendPort: receivePort.sendPort,
        modelPath: model.path,
        mmprojPath: mmproj.path,
        backend: backend,
        nCtx: nCtx,
        systemPrompt: systemPrompt,
        inputText: inputText,
        imagePath: imagePath,
      ),
      onExit: receivePort.sendPort,
    );

    final text = StringBuffer();
    try {
      await for (final message in receivePort) {
        if (message == null) {
          // onExit fired without a result: the isolate died.
          throw Exception("Inference isolate exited unexpectedly");
        }
        final map = message as Map;
        if (map.containsKey("delta")) {
          final delta = map["delta"] as String;
          text.write(delta);
          onDelta?.call(delta);
        } else if (map.containsKey("done")) {
          return map["done"] as String;
        } else if (map.containsKey("error")) {
          throw Exception(map["error"]);
        }
      }
      // cancel() closed the port mid-run.
      return text.toString();
    } finally {
      receivePort.close();
      _receivePort = null;
      _isolate = null;
    }
  }

  /// Kills a run in flight (e.g. the page was disposed).
  void cancel() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort?.close();
    _receivePort = null;
  }

  // Helper method to download a file
  static Future<File> downloadFile(String url, String filename) async {
    final response = await http.get(Uri.parse(url));
    final file = File(filename);
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }
}
