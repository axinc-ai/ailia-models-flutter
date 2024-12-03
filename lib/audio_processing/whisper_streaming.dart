// Whisper Speech To Text Streaming Processing

import 'dart:isolate';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import 'package:ailia_speech/ailia_speech.dart' as ailia_speech_dart;
import 'package:ailia_speech/ailia_speech_model.dart';
import 'package:ailia/ailia_model.dart';

void speechToTextIsolateFunc(SendPort initialReplyTo) {
  final receivePort = ReceivePort();
  final interruptPort = ReceivePort();
  initialReplyTo.send({
    "sendPort": receivePort.sendPort,
    "interruptPort": interruptPort.sendPort
  });

  late AiliaSpeechModel ailiaSpeechToText;

  // 終了の割り込みメッセージ
  bool interrupt = false;
  interruptPort.listen((message) {
    interrupt = true;
  });

  // 音声認識ジョブの処理
  receivePort.listen((message) {
    SendPort answerPort = message["answerPort"];

    if (message["cmd"] == "initialize") {
      ailiaSpeechToText = AiliaSpeechModel();
      ailiaSpeechToText.create(
        message["liveTranscribe"],
        false,
        message["envId"],
        virtualMemory:message["virtualMemory"],
      );
      ailiaSpeechToText.open(
        message["encoderFile"],
        message["decoderFile"],
        message["vadEnable"] ? message["vadFile"] : null,
        message["language"],
        message["modelType"],
      );
      return;
    }

    if (message["cmd"] == "terminate") {
      ailiaSpeechToText.finalizeInputData();
      while (!ailiaSpeechToText.isComplete() && interrupt == false) {
        var result = ailiaSpeechToText.transcribe();
        if (result.isNotEmpty) {
          answerPort.send({
            "intermediate": false,
            "terminate": false,
            "text": result,
          });
        }
      }
      ailiaSpeechToText.reset();
      ailiaSpeechToText.close();
      answerPort.send({
        "intermediate": false,
        "terminate": true,
        "text": null,
      });
      return;
    }

    if (message["cmd"] == "transcribe") {
      void intermediateCallback(textMessage) {
        SpeechText text = SpeechText(
          textMessage,
          0,
          0,
          0,
          0,
        );
        List<SpeechText> result = [text];
        answerPort.send({
          "intermediate": true,
          "terminate": false,
          "text": result,
        });
      }

      ailiaSpeechToText.setIntermediateCallback(intermediateCallback);

      ailiaSpeechToText.pushInputData(
        message["chunk"],
        message["sampleRate"],
        message["channels"],
      );

      while (ailiaSpeechToText.isBuffered() && interrupt == false) {
        var result = ailiaSpeechToText.transcribe();
        if (result.isNotEmpty) {
          answerPort.send({
            "intermediate": false,
            "terminate": false,
            "text": result,
          });
        }
      }
      return;
    }

    print("unknown cmd");
  });
}

class SpeechToTextIsolate {
  late ReceivePort receivePort;
  late Isolate isolate;
  late SendPort sendPort;
  late SendPort interruptPort;
  late ReceivePort answerPort;
  bool _isTerminateFlag = false;
  bool _isInitializeFlag = false;
  bool _isIntermediateFlag = false;
  bool _isInterruptFlag = false;

  Future<void> init(
    Function intermediateCallback,
    Function messageCallback,
    Function finishCallback,
    File encoderFile,
    File decoderFile,
    File vadFile,
    int modelType,
    bool liveTranscribe,
    String language,
    bool vadEnable,
    int envId,
    bool virtualMemory,
  ) async {
    _isTerminateFlag = false;
    _isInterruptFlag = false;
    receivePort = ReceivePort();
    isolate = await Isolate.spawn(
      speechToTextIsolateFunc,
      receivePort.sendPort,
    );
    var message = await receivePort.first;
    sendPort = message["sendPort"] as SendPort;
    interruptPort = message["interruptPort"] as SendPort;
    answerPort = ReceivePort();
    answerPort.listen((message) async {
      if (message["intermediate"] == true) {
        _isIntermediateFlag = true;
        intermediateCallback(message["text"]);
      } else {
        if (message["terminate"] == true) {
          finishCallback();
        } else {
          messageCallback(message["text"]);
        }
      }
    });

    var args = {
      "answerPort": answerPort.sendPort,
      "cmd": "initialize",
      "encoderFile": encoderFile,
      "decoderFile": decoderFile,
      "vadFile": vadFile,
      "liveTranscribe": liveTranscribe,
      "language": language,
      "modelType": modelType,
      "vadEnable": vadEnable,
      "envId": envId,
      "virtualMemory": virtualMemory
    };
    sendPort.send(args);

    _isInitializeFlag = true;
    _isIntermediateFlag = false;
  }

  void send(List<double> chunk, int sampleRate, int channels) {
    if (!_isInitializeFlag) {
      print("Warning : send : not initialized");
      return;
    }

    // 音声認識が長時間CPUを使わないようにメッセージを1秒ごとに分割する
    int chunkSize = sampleRate;
    for (int i = 0; i < chunk.length; i += chunkSize) {
      final isLast = i + chunkSize >= chunk.length;
      final end = isLast ? chunk.length : i + chunkSize;
      var args = {
        "answerPort": answerPort.sendPort,
        "cmd": "transcribe",
        "chunk": chunk.sublist(i, end),
        "sampleRate": sampleRate,
        "channels": channels
      };
      sendPort.send(args);
    }
  }

  bool isTerminate() {
    return _isTerminateFlag;
  }

  bool isIntermediate() {
    return _isIntermediateFlag;
  }

  // キューを最後まで処理をして終了する
  void terminate() {
    if (_isTerminateFlag) {
      return;
    }
    if (!_isInitializeFlag) {
      print("Warning : terminate : not initialized");
      return;
    }
    _isTerminateFlag = true;
    var args = {
      "answerPort": answerPort.sendPort,
      "cmd": "terminate",
    };
    sendPort.send(args);
  }

  // 以降のキューの認識をスキップする
  void interrupt() {
    if (_isInterruptFlag) {
      return;
    }
    if (!_isInitializeFlag) {
      print("Warning : terminate : not initialized");
      return;
    }
    _isInterruptFlag = true;
    var args = {
      "cmd": "interrupt",
    };
    interruptPort.send(args);
  }

  void close() {
    if (!_isInitializeFlag) {
      print("Warning : close : not initialized");
      return;
    }
    isolate.kill();
    receivePort.close();
    answerPort.close();
    _isInitializeFlag = false;
  }
}

class AudioProcessingWhisperStreaming {
  final SpeechToTextIsolate _ailiaSpeechModel = SpeechToTextIsolate();

  Future<void> open(File onnx_encoder_file, File onnx_decoder_file, File vad_file, int env_id, String type, String lang, bool virtualMemory, Function intermediateCallback, Function messageCallback, Function finishCallback) async{
    int typeId = 0;
    if (type == "whisper_tiny"){
      typeId = ailia_speech_dart.AILIA_SPEECH_MODEL_TYPE_WHISPER_MULTILINGUAL_TINY;
    }
    if (type == "whisper_small"){
      typeId = ailia_speech_dart.AILIA_SPEECH_MODEL_TYPE_WHISPER_MULTILINGUAL_SMALL;
    }
    if (type == "whisper_medium"){
      // Please add com.apple.developer.kernel.increased-memory-limit for iOS
      typeId = ailia_speech_dart.AILIA_SPEECH_MODEL_TYPE_WHISPER_MULTILINGUAL_MEDIUM;
    }
    if (type == "whisper_large_v3_turbo"){
      // Please add com.apple.developer.kernel.increased-memory-limit for iOS
      typeId = ailia_speech_dart.AILIA_SPEECH_MODEL_TYPE_WHISPER_MULTILINGUAL_LARGE_V3;
    }
    if (virtualMemory){
      Directory path = await getTemporaryDirectory();
      AiliaModel.setTemporaryCachePath(path.path);
    }
    _ailiaSpeechModel.init(intermediateCallback, messageCallback, finishCallback, onnx_encoder_file, onnx_decoder_file, vad_file, typeId, false, lang, true, env_id, virtualMemory);
  }

  void send(List<double> pcm, int samplesPerSecond){
    _ailiaSpeechModel.send(pcm, samplesPerSecond, 1);
  }

  void terminate(){
    _ailiaSpeechModel.terminate();
  }

  void close(){
    _ailiaSpeechModel.close();
  }

}
