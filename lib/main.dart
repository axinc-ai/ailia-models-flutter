import 'package:flutter/material.dart';

// assets
import 'package:flutter/services.dart'; //rootBundle
import 'package:flutter/widgets.dart';
import 'dart:async'; //Future
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:ailia/ailia_model.dart';
import 'package:ailia/ailia_license.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart';

// mic
import 'package:mic_stream/mic_stream.dart';
import 'package:ailia_speech/ailia_speech_model.dart';
import 'package:permission_handler/permission_handler.dart';

// image
import 'dart:ui' as ui;
import 'dart:math' as math;

// ai models
import 'utils/download_model.dart';
import 'image_classification/image_classification_sample.dart';
import 'audio_processing/whisper.dart';
import 'text_to_speech/text_to_speech.dart';
import 'natural_language_processing/fugumt.dart';
import 'natural_language_processing/multilingual_e5.dart';
import 'object_detection/yolox.dart';
import 'large_language_model/large_language_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ailia MODELS Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AiliaModelsFlutter(title: 'ailia MODELS Flutter'),
    );
  }
}

class AiliaModelsFlutter extends StatefulWidget {
  const AiliaModelsFlutter({super.key, required this.title});

  final String title;

  @override
  State<AiliaModelsFlutter> createState() => _AiliaModelsFlutterState();
}

class _AiliaModelsFlutterState extends State<AiliaModelsFlutter> {
  int _counter = 0;
  String predict_result = "";

  Future<File> copyFileFromAssets(String path) async {
    final byteData = await rootBundle.load('assets/$path');
    final buffer = byteData.buffer;
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;
    var filePath = '$tempPath/$path';
    return File(filePath)
      .writeAsBytes(buffer.asUint8List(byteData.offsetInBytes, 
    byteData.lengthInBytes));
  }

  Future<ui.Image> loadImageFromAssets(String path) async {
    ByteData data = await rootBundle.load(path);
    return decodeImageFromList(data.buffer.asUint8List());
  }

  void _displayDownloadBegin(){
    setState(() {
      predict_result = "Downloading...";
    });
  }

  void _displayDownloadProgress(progress){
    setState(() {
      predict_result = "Downloading... ${progress ~/ 1024 ~/ 1024} MB";
    });
  }

  Future<void> _displayDownloadEnd() async{
    setState(() {
      predict_result = "Download success.";
    });
    await Future.delayed(new Duration(milliseconds: 100));
  }

  Future<void> _changeModel() async{
    await AiliaLicense.checkAndDownloadLicense();

    switch (isSelectedItem){
    case "resnet18":
      _ailiaImageClassificationResNet18();
      break;
    case "whisper_tiny":
    case "whisper_small":
    case "whisper_medium":
    case "whisper_large_v3_turbo":
    case "whisper_large_v3_turbo_with_virtual_memory":
      _ailiaAudioProcessingWhisper(isSelectedItem!);
      break;
    case "multilingual-e5":
      _ailiaNaturalLanguageProcessingMultilingualE5();
      break;
    case "yolox":
      _ailiaObjectDetectionYoloX();
      break;
    case "fugumt-en-ja":
      _ailiaNaturalLanguageProcessingFuguMTEnJa();
      break;
    case "fugumt-ja-en":
      _ailiaNaturalLanguageProcessingFuguMTJaEn();
      break;
    case "tacotron2":
      _ailiaTextToSpeechTactoron2();
      break;
    case "gpt-sovits-ja":
      _ailiaTextToSpeechGPTSoVITS_JA();
      break;
    case "gpt-sovits-en":
      _ailiaTextToSpeechGPTSoVITS_EN();
      break;
    case "gemma2":
      _ailiaLargeLanguageModelGemma2();
      break;
    default:
      throw(Exception("Unknown model type"));
    }
  }

  void downloadModelFromModelList(int downloadCnt, List<String> modelList, Function callback){
    String filename = basename(modelList[downloadCnt + 1]);
    String url = "https://storage.googleapis.com/ailia-models/${modelList[downloadCnt + 0]}/$filename";
    setState(() {
      predict_result = "Downloading ${modelList[downloadCnt + 1]}";
    });
    downloadModel(
        url,
        modelList[downloadCnt + 1], (file) {
          downloadCnt = downloadCnt + 2;
          if (downloadCnt >= modelList.length){
            callback();
          }else{
            downloadModelFromModelList(downloadCnt, modelList, callback);
          }
        }, (progress) {
          setState(() {
            predict_result = "Downloading ${modelList[downloadCnt + 1]} ${progress ~/ 1024 ~/ 1024} MB";
          });
        }
    );
  }

  void _ailiaNaturalLanguageProcessingFuguMTEnJa(){
    NaturalLanguageProcessingFuguMT fuguMT = NaturalLanguageProcessingFuguMT();
    List<String> modelList = fuguMT.getModelList(false);
    _displayDownloadBegin();
    downloadModelFromModelList(0, modelList, () async {
      await _displayDownloadEnd();

      File encoderFile = File(await getModelPath("fugumt-en-ja/seq2seq-lm-with-past.onnx"));
      File? decoderFile = null;
      File sourceFile = File(await getModelPath("fugumt-en-ja/source.spm"));
      File targetFile = File(await getModelPath("fugumt-en-ja/target.spm"));

      int startTime = DateTime.now().millisecondsSinceEpoch;
      String targetText = "Hello world.";
      String outputText = fuguMT.translate(targetText, encoderFile, decoderFile, sourceFile, targetFile, false, selectedEnvId);
      int endTime = DateTime.now().millisecondsSinceEpoch;
      String profileText = "processing time : ${(endTime - startTime) / 1000} sec";

      setState(() {
        predict_result = "${targetText} -> ${outputText}\n${profileText}";
      });
    });
  }

  void _ailiaNaturalLanguageProcessingFuguMTJaEn(){
    NaturalLanguageProcessingFuguMT fuguMT = NaturalLanguageProcessingFuguMT();
    List<String> modelList = fuguMT.getModelList(true);
    _displayDownloadBegin();
    downloadModelFromModelList(0, modelList, () async {
      await _displayDownloadEnd();

      File encoderFile = File(await getModelPath("fugumt-ja-en/encoder_model.onnx"));
      File decoderFile = File(await getModelPath("fugumt-ja-en/decoder_model.onnx"));
      File sourceFile = File(await getModelPath("fugumt-ja-en/source.spm"));
      File targetFile = File(await getModelPath("fugumt-ja-en/target.spm"));

      int startTime = DateTime.now().millisecondsSinceEpoch;
      String targetText = "こんにちは世界。";
      String outputText = fuguMT.translate(targetText, encoderFile, decoderFile, sourceFile, targetFile, true, selectedEnvId);
      int endTime = DateTime.now().millisecondsSinceEpoch;
      String profileText = "processing time : ${(endTime - startTime) / 1000} sec";

      setState(() {
        predict_result = "${targetText} -> ${outputText}\n${profileText}";
      });
    });
  }

  void _ailiaTextToSpeechTactoron2(){
    TextToSpeech textToSpeech = TextToSpeech();
    List<String> modelList = textToSpeech.getModelList(TextToSpeech.MODEL_TYPE_TACOTRON2);
    _displayDownloadBegin();
    downloadModelFromModelList(0, modelList, () async {
      await _displayDownloadEnd();

      String encoderFile = await getModelPath("encoder.onnx");
      String decoderFile = await getModelPath("decoder_iter.onnx");
      String postnetFile = await getModelPath("postnet.onnx");
      String waveglowFile = await getModelPath("waveglow.onnx");
      String? sslFile;

      String dicFolder = await getModelPath("open_jtalk_dic_utf_8-1.11/");
      String targetText = "Hello world.";
      String outputPath = await getModelPath("temp$_counter.wav");

      int startTime = DateTime.now().millisecondsSinceEpoch;
      await textToSpeech.inference(targetText, outputPath, encoderFile, decoderFile, postnetFile, waveglowFile, sslFile, dicFolder, null, TextToSpeech.MODEL_TYPE_TACOTRON2);
      int endTime = DateTime.now().millisecondsSinceEpoch;
      String profileText = "processing time : ${(endTime - startTime) / 1000} sec";

      setState(() {
        predict_result = profileText;
      });
    });
  }

  void _ailiaTextToSpeechGPTSoVITS_JA(){
    TextToSpeech textToSpeech = TextToSpeech();
    List<String> modelList = textToSpeech.getModelList(TextToSpeech.MODEL_TYPE_GPT_SOVITS_JA);
    _displayDownloadBegin();
    downloadModelFromModelList(0, modelList, () async {
      await _displayDownloadEnd();

      String encoderFile = await getModelPath("t2s_encoder.onnx");
      String decoderFile = await getModelPath("t2s_fsdec.onnx");
      String postnetFile = await getModelPath("t2s_sdec.opt.onnx");
      String waveglowFile = await getModelPath("vits.onnx");
      String sslFile = await getModelPath("cnhubert.onnx");

      String dicFolder = await getModelPath("open_jtalk_dic_utf_8-1.11/");
      String targetText = "Hello world.";
      String outputPath = await getModelPath("temp$_counter.wav");

      int startTime = DateTime.now().millisecondsSinceEpoch;
      await textToSpeech.inference(targetText, outputPath, encoderFile, decoderFile, postnetFile, waveglowFile, sslFile, dicFolder, null, TextToSpeech.MODEL_TYPE_GPT_SOVITS_JA);
      int endTime = DateTime.now().millisecondsSinceEpoch;
      String profileText = "processing time : ${(endTime - startTime) / 1000} sec";

      setState(() {
        predict_result = profileText;
      });
    });
  }

  void _ailiaTextToSpeechGPTSoVITS_EN(){
    TextToSpeech textToSpeech = TextToSpeech();
    List<String> modelList = textToSpeech.getModelList(TextToSpeech.MODEL_TYPE_GPT_SOVITS_EN);
    _displayDownloadBegin();
    downloadModelFromModelList(0, modelList, () async {
      await _displayDownloadEnd();

      String encoderFile = await getModelPath("t2s_encoder.onnx");
      String decoderFile = await getModelPath("t2s_fsdec.onnx");
      String postnetFile = await getModelPath("t2s_sdec.opt.onnx");
      String waveglowFile = await getModelPath("vits.onnx");
      String sslFile = await getModelPath("cnhubert.onnx");

      String dicFolderOpenJtalk = await getModelPath("open_jtalk_dic_utf_8-1.11/");
      String dicFolderEn = await getModelPath("/");
      String targetText = "Hello world.";
      String outputPath = await getModelPath("temp$_counter.wav");

      int startTime = DateTime.now().millisecondsSinceEpoch;
      await textToSpeech.inference(targetText, outputPath, encoderFile, decoderFile, postnetFile, waveglowFile, sslFile, dicFolderOpenJtalk, dicFolderEn, TextToSpeech.MODEL_TYPE_GPT_SOVITS_EN);
      int endTime = DateTime.now().millisecondsSinceEpoch;
      String profileText = "processing time : ${(endTime - startTime) / 1000} sec";

      setState(() {
        predict_result = profileText;
      });
    });
  }

  void _ailiaImageClassificationResNet18(){
    // Load image
    loadImageFromAssets("assets/clock.jpg").then(
      (imageAsync) {
        image = imageAsync;
        setState(() { // apply to ui (call build)
          isImageloaded = true;
        });

        // Download onnx
        _displayDownloadBegin();
        downloadModel("https://storage.googleapis.com/ailia-models/resnet18/resnet18.onnx", "resnet18.onnx", (onnx_file) async {
            await _displayDownloadEnd();
            // Load image data
            image!.toByteData(format: ui.ImageByteFormat.rawRgba).then(
              (data){
                ailiaEnvironmentSample();

                int startTime = DateTime.now().millisecondsSinceEpoch;
                String classificationText = ailiaPredictSample(onnx_file, data!);
                int endTime = DateTime.now().millisecondsSinceEpoch;
                String profileText = "processing time : ${(endTime - startTime) / 1000} sec";

                setState(() {
                  predict_result = "${classificationText}\n${profileText}";
                });
              }
            );
        }, _displayDownloadProgress);
      }
    );
  }

  AudioProcessingWhisper whisper = AudioProcessingWhisper();
  Stream<Uint8List>? stream = null;
  StreamSubscription? listener = null;
  String mic_volume = "";

  void _intermediateCallback(List<SpeechText> text){
      setState(() {
        predict_result = text[0].text + "...";
      });
  }

  void _messageCallback(List<SpeechText> text){
      setState(() {
        predict_result = "";
        for (int i = 0; i < text.length; i++){
          predict_result += text[i].text;
        }
      });
  }

  void _finishCallback(){
  }

  void _processSamples(samples) {
    // https://github.com/anarchuser/mic_stream/issues/94
    List<double> result = [];
    int UInt16Max = math.pow(2, 16).toInt();
    for (var i = 0; i < samples.length~/2; i++) {
      int a = samples[2*i + 1];
      int b = samples[2*i];
      int c = 256*a + b;
      if (2*c > UInt16Max) {
        c = -UInt16Max + c;
      }
      result.add(c / 32738.0);
    }

    setState(() {
      mic_volume = "mic volume : ${result.reduce(math.max)}";
    });

    int sampleRate = 44100;
    whisper.send(result, sampleRate);
  }

  void _ailiaAudioProcessingWhisper(String modelType) async{
    List<String> modelList = whisper.getModelList(modelType);
    _displayDownloadBegin();
    downloadModelFromModelList(0, modelList, () async {
      await _displayDownloadEnd();

      setState(() {
        predict_result = "Please speak to mic.";
      });

      File vad_file = File(await getModelPath(modelList[1]));
      File onnx_encoder_file = File(await getModelPath(modelList[3]));
      File onnx_decoder_file = File(await getModelPath(modelList[5]));
      await whisper.open(onnx_encoder_file, onnx_decoder_file, vad_file, selectedEnvId, modelType, _intermediateCallback, _messageCallback, _finishCallback);

      if (listener != null){
        listener!.cancel();
        listener = null;
      }

      await Permission.microphone.request();

      int sampleRate = 44100;
      stream = MicStream.microphone(audioSource: AudioSource.DEFAULT, sampleRate: sampleRate, channelConfig: ChannelConfig.CHANNEL_IN_MONO, audioFormat: AudioFormat.ENCODING_PCM_16BIT);
      listener = stream!.listen(_processSamples);
    });
  }

  void _ailiaNaturalLanguageProcessingMultilingualE5() async{
    _displayDownloadBegin();
    downloadModel("https://storage.googleapis.com/ailia-models/multilingual-e5/multilingual-e5-base.onnx", "multilingual-e5-base.onnx", (onnx_file) {
      downloadModel("https://storage.googleapis.com/ailia-models/multilingual-e5/sentencepiece.bpe.model", "sentencepiece.bpe.model", (spe_file) async {
        print("Download model success");
        await _displayDownloadEnd();
        NaturalLanguageProcessingMultilingualE5 e5 = NaturalLanguageProcessingMultilingualE5();
        e5.open(onnx_file, spe_file, selectedEnvId);
        String text1 = "Hello.";
        String text2 = "こんにちは。";
        String text3 = "Today is good day.";
        int startTime = DateTime.now().millisecondsSinceEpoch;
        List<double> embedding1 = e5.textEmbedding(text1);
        List<double> embedding2 = e5.textEmbedding(text2);
        List<double> embedding3 = e5.textEmbedding(text3);
        double sim1 = e5.cosSimilarity(embedding1, embedding2);
        double sim2 = e5.cosSimilarity(embedding1, embedding3);
        int endTime = DateTime.now().millisecondsSinceEpoch;
        String profileText = "processing time : ${(endTime - startTime) / 1000} sec";
        e5.close();
        setState(() {
          predict_result = "$text1 vs $text2 sim $sim1\n$text1 vs $text3 sim $sim2\n${profileText}";
        });
      }, _displayDownloadProgress);
    }, _displayDownloadProgress);
  }

  void _ailiaObjectDetectionYoloX() async{
    // Load image
    ByteData imData = await rootBundle.load("assets/clock.jpg");
    loadImageFromAssets("assets/clock.jpg").then(
      (imageAsync) {
        image = imageAsync;
        setState(() { // apply to ui (call build)
          isImageloaded = true;
        });

        // Download onnx
        _displayDownloadBegin();
        downloadModel("https://storage.googleapis.com/ailia-models/yolox/yolox_s.opt.onnx", "yolox_s.opt.onnx", (onnx_file) async {
            await _displayDownloadEnd();
            ObjectDetectionYoloX yolox = ObjectDetectionYoloX();
            yolox.open(onnx_file, selectedEnvId);

            final image = img.decodeImage(imData.buffer.asUint8List())!;
            final width = image.width;
            final height = image.height;
            final imageWithoutAlpha = image.convert(numChannels: 3);
            final buffer = imageWithoutAlpha.getBytes(order: img.ChannelOrder.rgb);

            String resultSubText;

            int startTime = DateTime.now().millisecondsSinceEpoch;
            final res = yolox.run(buffer, width, height);
            int endTime = DateTime.now().millisecondsSinceEpoch;
            String profileText = "processing time : ${(endTime - startTime) / 1000} sec";
        
            resultSubText = res.map((e) => "x:${e.x} y:${e.y} w:${e.w} h:${e.h} p:${e.prob} label:${yolox.category[e.category]}").join("\n");

            setState(() {
              predict_result = "${resultSubText}\n${profileText}";
            });
        }, _displayDownloadProgress);
      }
    );
  }

  void _ailiaLargeLanguageModelGemma2() async {
    LargeLanguageModel llm = LargeLanguageModel();
    List<String> modelList = llm.getModelList();
    _displayDownloadBegin();
    downloadModelFromModelList(0, modelList, () async {
      File modelFile = File(await getModelPath("gemma-2-2b-it-Q4_K_M.gguf"));
      String inputText = "こんにちは。";
      llm.open(modelFile);
      llm.setSystemPrompt("語尾に「わん」をつけてください。");
      String outputText = llm.chat(inputText);
      setState(() {
        predict_result = "${inputText} -> ${outputText}";
      });
    });
  }

  void _incrementCounter() async {
    await _changeModel();

    setState(() {
      _counter++;
    });
  }

  ui.Image? image = null;
  bool isImageloaded = false;

  Widget _buildImage() {
    if (this.isImageloaded && image != null) {
      return new CustomPaint(
          painter: new ImageEditor(image: image!),
        );
    } else {
      return new Center(child: new Text(''));
    }
  }
  
  String? isSelectedItem = 'resnet18';
  List<AiliaEnvironment> envList = [];
  int selectedEnvId = 1;
  
  @override
  Widget build(BuildContext context) {
    bool isImage = isSelectedItem == 'resnet18' || isSelectedItem == 'yolox';
    if (envList.length == 0){
      envList = AiliaModel.getEnvironmentList();
    }

    List<String> modelList = [];
    modelList.add('resnet18');
    modelList.add('whisper_tiny');
    modelList.add('whisper_small');
    modelList.add('whisper_medium');
    modelList.add('whisper_large_v3_turbo');
    modelList.add('whisper_large_v3_turbo_with_virtual_memory');
    modelList.add('multilingual-e5');
    modelList.add('yolox');
    modelList.add('fugumt-en-ja');
    modelList.add('fugumt-ja-en');
    modelList.add('tacotron2');
    modelList.add('gpt-sovits-ja');
    modelList.add('gpt-sovits-en');
    modelList.add('gemma2');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            const Text(
              'You have pushed the inference button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            DropdownButton(
              items:
                envList.map((item) => 
                  DropdownMenuItem(
                    child: Text(item.name),
                    value: item.id,
                  )
                ).toList(),
              onChanged: (int? value) {
                setState(() {
                  selectedEnvId = value!;
                });
              },
              value: selectedEnvId,
            ),
            DropdownButton(
              items:
                modelList.map((item) => 
                  DropdownMenuItem(
                    child: Text(item),
                    value: item,
                  )
                ).toList(),
              onChanged: (String? value) {
                setState(() {
                  isSelectedItem = value;
                });
              },
              value: isSelectedItem,
            ),
            if (isImage) ...[ 
              new Container(
                width: 224,
                height: 224,
                child: _buildImage(),
              ),
            ],
            Text(
              predict_result,
            ),
            Text(
              mic_volume,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Inference',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class ImageEditor extends CustomPainter {
  ImageEditor({
    this.image,
  });

  ui.Image? image;

  @override
  void paint(Canvas canvas, ui.Size size) {
    if (image != null){
      canvas.drawImage(image!, new Offset(0.0, 0.0), new Paint());
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }

}