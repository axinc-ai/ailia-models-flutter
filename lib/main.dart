import 'package:flutter/material.dart';

// assets
import 'package:flutter/services.dart'; //rootBundle
import 'package:flutter/widgets.dart';
import 'dart:async'; //Future
import 'package:path_provider/path_provider.dart';
import 'package:wav/wav.dart';
import 'dart:io';
import 'package:ailia/ailia.dart' as ailia_dart;
import 'package:ailia/ailia_license.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart';

// image
import 'dart:ui' as ui;

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
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'ailia MODELS Flutter'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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

  void _displayDownloadEnd(){
    setState(() {
      predict_result = "Download success.";
    });
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
      File encoderFile = File(await getModelPath("fugumt-en-ja/seq2seq-lm-with-past.onnx"));
      File? decoderFile = null;
      File sourceFile = File(await getModelPath("fugumt-en-ja/source.spm"));
      File targetFile = File(await getModelPath("fugumt-en-ja/target.spm"));

      String targetText = "Hello world.";
      String outputText = fuguMT.translate(targetText, encoderFile, decoderFile, sourceFile, targetFile, false, ailia_dart.AILIA_ENVIRONMENT_ID_AUTO);

      setState(() {
        predict_result = "${targetText} -> ${outputText}";
      });
    });
  }

  void _ailiaNaturalLanguageProcessingFuguMTJaEn(){
    NaturalLanguageProcessingFuguMT fuguMT = NaturalLanguageProcessingFuguMT();
    List<String> modelList = fuguMT.getModelList(true);
    _displayDownloadBegin();
    downloadModelFromModelList(0, modelList, () async {
      File encoderFile = File(await getModelPath("fugumt-ja-en/encoder_model.onnx"));
      File decoderFile = File(await getModelPath("fugumt-ja-en/decoder_model.onnx"));
      File sourceFile = File(await getModelPath("fugumt-ja-en/source.spm"));
      File targetFile = File(await getModelPath("fugumt-ja-en/target.spm"));

      String targetText = "こんにちは世界。";
      String outputText = fuguMT.translate(targetText, encoderFile, decoderFile, sourceFile, targetFile, true, ailia_dart.AILIA_ENVIRONMENT_ID_AUTO);

      setState(() {
        predict_result = "${targetText} -> ${outputText}";
      });
    });
  }

  void _ailiaTextToSpeechTactoron2(){
    TextToSpeech textToSpeech = TextToSpeech();
    List<String> modelList = textToSpeech.getModelList(TextToSpeech.MODEL_TYPE_TACOTRON2);
    _displayDownloadBegin();
    downloadModelFromModelList(0, modelList, () async {
      String encoderFile = await getModelPath("encoder.onnx");
      String decoderFile = await getModelPath("decoder_iter.onnx");
      String postnetFile = await getModelPath("postnet.onnx");
      String waveglowFile = await getModelPath("waveglow.onnx");
      String? sslFile;

      String dicFolder = await getModelPath("open_jtalk_dic_utf_8-1.11/");
      String targetText = "Hello world.";
      String outputPath = await getModelPath("temp$_counter.wav");
      await textToSpeech.inference(targetText, outputPath, encoderFile, decoderFile, postnetFile, waveglowFile, sslFile, dicFolder, null, TextToSpeech.MODEL_TYPE_TACOTRON2);

      setState(() {
        predict_result = "finish";
      });
    });
  }

  void _ailiaTextToSpeechGPTSoVITS_JA(){
    TextToSpeech textToSpeech = TextToSpeech();
    List<String> modelList = textToSpeech.getModelList(TextToSpeech.MODEL_TYPE_GPT_SOVITS_JA);
    _displayDownloadBegin();
    downloadModelFromModelList(0, modelList, () async {
      String encoderFile = await getModelPath("t2s_encoder.onnx");
      String decoderFile = await getModelPath("t2s_fsdec.onnx");
      String postnetFile = await getModelPath("t2s_sdec.opt.onnx");
      String waveglowFile = await getModelPath("vits.onnx");
      String sslFile = await getModelPath("cnhubert.onnx");

      String dicFolder = await getModelPath("open_jtalk_dic_utf_8-1.11/");
      String targetText = "Hello world.";
      String outputPath = await getModelPath("temp$_counter.wav");
      await textToSpeech.inference(targetText, outputPath, encoderFile, decoderFile, postnetFile, waveglowFile, sslFile, dicFolder, null, TextToSpeech.MODEL_TYPE_GPT_SOVITS_JA);

      setState(() {
        predict_result = "finish";
      });
    });
  }

  void _ailiaTextToSpeechGPTSoVITS_EN(){
    TextToSpeech textToSpeech = TextToSpeech();
    List<String> modelList = textToSpeech.getModelList(TextToSpeech.MODEL_TYPE_GPT_SOVITS_EN);
    _displayDownloadBegin();
    downloadModelFromModelList(0, modelList, () async {
      String encoderFile = await getModelPath("t2s_encoder.onnx");
      String decoderFile = await getModelPath("t2s_fsdec.onnx");
      String postnetFile = await getModelPath("t2s_sdec.opt.onnx");
      String waveglowFile = await getModelPath("vits.onnx");
      String sslFile = await getModelPath("cnhubert.onnx");

      String dicFolderOpenJtalk = await getModelPath("open_jtalk_dic_utf_8-1.11/");
      String dicFolderEn = await getModelPath("/");
      String targetText = "Hello world.";
      String outputPath = await getModelPath("temp$_counter.wav");
      await textToSpeech.inference(targetText, outputPath, encoderFile, decoderFile, postnetFile, waveglowFile, sslFile, dicFolderOpenJtalk, dicFolderEn, TextToSpeech.MODEL_TYPE_GPT_SOVITS_EN);

      setState(() {
        predict_result = "finish";
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
        downloadModel("https://storage.googleapis.com/ailia-models/resnet18/resnet18.onnx", "resnet18.onnx", (onnx_file) {
            _displayDownloadEnd();
            // Load image data
            image!.toByteData(format: ui.ImageByteFormat.rawRgba).then(
              (data){
                ailiaEnvironmentSample();
                setState(() {
                  predict_result = ailiaPredictSample(onnx_file, data!);
                });
              }
            );
        }, _displayDownloadProgress);
      }
    );
  }

  void _ailiaAudioProcessingWhisper(String modelType) async{
    ByteData data = await rootBundle.load("assets/demo.wav");
    final wav = await Wav.read(data.buffer.asUint8List());
    AudioProcessingWhisper whisper = AudioProcessingWhisper();
    List<String> modelList = whisper.getModelList(modelType);
    _displayDownloadBegin();
    downloadModelFromModelList(0, modelList, () async {
      _displayDownloadEnd();
      File vad_file = File(await getModelPath(modelList[1]));
      File onnx_encoder_file = File(await getModelPath(modelList[3]));
      File onnx_decoder_file = File(await getModelPath(modelList[5]));
      String text = await whisper.transcribe(wav, onnx_encoder_file, onnx_decoder_file, vad_file, ailia_dart.AILIA_ENVIRONMENT_ID_AUTO, modelType);
      setState(() {
        predict_result = text;
      });
    });
  }

  void _ailiaNaturalLanguageProcessingMultilingualE5() async{
    _displayDownloadBegin();
    downloadModel("https://storage.googleapis.com/ailia-models/multilingual-e5/multilingual-e5-base.onnx", "multilingual-e5-base.onnx", (onnx_file) {
      downloadModel("https://storage.googleapis.com/ailia-models/multilingual-e5/sentencepiece.bpe.model", "sentencepiece.bpe.model", (spe_file) async {
        print("Download model success");
        _displayDownloadEnd();
        NaturalLanguageProcessingMultilingualE5 e5 = NaturalLanguageProcessingMultilingualE5();
        e5.open(onnx_file, spe_file, ailia_dart.AILIA_ENVIRONMENT_ID_AUTO);
        String text1 = "Hello.";
        String text2 = "こんにちは。";
        String text3 = "Today is good day.";
        List<double> embedding1 = e5.textEmbedding(text1);
        List<double> embedding2 = e5.textEmbedding(text2);
        List<double> embedding3 = e5.textEmbedding(text3);
        double sim1 = e5.cosSimilarity(embedding1, embedding2);
        double sim2 = e5.cosSimilarity(embedding1, embedding3);
        e5.close();
        setState(() {
          predict_result = "$text1 vs $text2 sim $sim1\n$text1 vs $text3 sim $sim2\n";
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
        downloadModel("https://storage.googleapis.com/ailia-models/yolox/yolox_s.opt.onnx", "yolox_s.opt.onnx", (onnx_file) {
            _displayDownloadEnd();
            ObjectDetectionYoloX yolox = ObjectDetectionYoloX();
            yolox.open(onnx_file, ailia_dart.AILIA_ENVIRONMENT_ID_AUTO);

            final image = img.decodeImage(imData.buffer.asUint8List())!;
            final width = image.width;
            final height = image.height;
            final imageWithoutAlpha = image.convert(numChannels: 3);
            final buffer = imageWithoutAlpha.getBytes(order: img.ChannelOrder.rgb);

            String resultSubText;
            final res = yolox.run(buffer, width, height);
            resultSubText = res.map((e) => "x:${e.x} y:${e.y} w:${e.w} h:${e.h} p:${e.prob} label:${yolox.category[e.category]}").join("\n");

            setState(() {
              predict_result = resultSubText;
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
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
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

  @override
  Widget build(BuildContext context) {
    bool isImage = isSelectedItem == 'resnet18' || isSelectedItem == 'yolox';

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
            //3
            DropdownButton(
              //4
              items: const [
                //5
                DropdownMenuItem(
                  child: Text('resnet18'),
                  value: 'resnet18',
                ),
                DropdownMenuItem(
                  child: Text('whisper_tiny'),
                  value: 'whisper_tiny',
                ),
                DropdownMenuItem(
                  child: Text('whisper_small'),
                  value: 'whisper_small',
                ),
                DropdownMenuItem(
                  child: Text('whisper_medium'),
                  value: 'whisper_medium',
                ),
                DropdownMenuItem(
                  child: Text('whisper_large_v3_turbo'),
                  value: 'whisper_large_v3_turbo',
                ),
                DropdownMenuItem(
                  child: Text('multilingual-e5'),
                  value: 'multilingual-e5',
                ),
                DropdownMenuItem(
                  child: Text('yolox'),
                  value: 'yolox',
                ),
                DropdownMenuItem(
                  child: Text('fugumt-en-ja'),
                  value: 'fugumt-en-ja',
                ),
                DropdownMenuItem(
                  child: Text('fugumt-ja-en'),
                  value: 'fugumt-ja-en',
                ),
                DropdownMenuItem(
                  child: Text('tacotron2'),
                  value: 'tacotron2',
                ),
                DropdownMenuItem(
                  child: Text('gpt-sovits-ja'),
                  value: 'gpt-sovits-ja',
                ),
                DropdownMenuItem(
                  child: Text('gpt-sovits-en'),
                  value: 'gpt-sovits-en',
                ),
                DropdownMenuItem(
                  child: Text('gemma2'),
                  value: 'gemma2',
                ),
              ],
              //6
              onChanged: (String? value) {
                setState(() {
                  isSelectedItem = value;
                });
              },
              //7
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