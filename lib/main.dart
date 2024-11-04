import 'dart:ui';

import 'package:ailia/ailia_model.dart';
import 'package:ailia_models_flutter/image_segmentation/segment-anything-2/sam2_image_predictor.dart';
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
    return File(filePath).writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
  }

  Future<ui.Image> loadImageFromAssets(String path) async {
    ByteData data = await rootBundle.load(path);
    return decodeImageFromList(data.buffer.asUint8List());
  }

  void _displayDownloadBegin() {
    setState(() {
      predict_result = "Downloading...";
    });
  }

  void _displayDownloadEnd() {
    setState(() {
      predict_result = "Download success.";
    });
  }

  Future<void> _changeModel() async {
    await AiliaLicense.checkAndDownloadLicense();

    switch (isSelectedItem) {
      case "sam2":
        _ailiaImageSegmentationSam2();
        break;
      case "resnet18":
        _ailiaImageClassificationResNet18();
        break;
      case "whisper":
        _ailiaAudioProcessingWhisper();
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
      default:
        throw (Exception("Unknown model type"));
    }
  }

  void downloadModelFromModelList(
      int downloadCnt, List<String> modelList, Function callback) {
    String filename = basename(modelList[downloadCnt + 1]);
    String url =
        "https://storage.googleapis.com/ailia-models/${modelList[downloadCnt + 0]}/$filename";
    setState(() {
      predict_result = "Downloading ${modelList[downloadCnt + 1]}";
    });
    downloadModel(url, modelList[downloadCnt + 1], (file) {
      downloadCnt = downloadCnt + 2;
      if (downloadCnt >= modelList.length) {
        callback();
      } else {
        downloadModelFromModelList(downloadCnt, modelList, callback);
      }
    });
  }

  void _ailiaNaturalLanguageProcessingFuguMTEnJa() {
    NaturalLanguageProcessingFuguMT fuguMT = NaturalLanguageProcessingFuguMT();
    List<String> modelList = fuguMT.getModelList(false);
    _displayDownloadBegin();
    downloadModelFromModelList(0, modelList, () async {
      File encoderFile =
          File(await getModelPath("fugumt-en-ja/seq2seq-lm-with-past.onnx"));
      File? decoderFile = null;
      File sourceFile = File(await getModelPath("fugumt-en-ja/source.spm"));
      File targetFile = File(await getModelPath("fugumt-en-ja/target.spm"));

      String targetText = "Hello world.";
      String outputText = fuguMT.translate(targetText, encoderFile, decoderFile,
          sourceFile, targetFile, false, ailia_dart.AILIA_ENVIRONMENT_ID_AUTO);

      setState(() {
        predict_result = "${targetText} -> ${outputText}";
      });
    });
  }

  void _ailiaNaturalLanguageProcessingFuguMTJaEn() {
    NaturalLanguageProcessingFuguMT fuguMT = NaturalLanguageProcessingFuguMT();
    List<String> modelList = fuguMT.getModelList(true);
    _displayDownloadBegin();
    downloadModelFromModelList(0, modelList, () async {
      File encoderFile =
          File(await getModelPath("fugumt-ja-en/encoder_model.onnx"));
      File decoderFile =
          File(await getModelPath("fugumt-ja-en/decoder_model.onnx"));
      File sourceFile = File(await getModelPath("fugumt-ja-en/source.spm"));
      File targetFile = File(await getModelPath("fugumt-ja-en/target.spm"));

      String targetText = "こんにちは世界。";
      String outputText = fuguMT.translate(targetText, encoderFile, decoderFile,
          sourceFile, targetFile, true, ailia_dart.AILIA_ENVIRONMENT_ID_AUTO);

      setState(() {
        predict_result = "${targetText} -> ${outputText}";
      });
    });
  }

  void _ailiaTextToSpeechTactoron2() {
    TextToSpeech textToSpeech = TextToSpeech();
    List<String> modelList =
        textToSpeech.getModelList(TextToSpeech.MODEL_TYPE_TACOTRON2);
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
      await textToSpeech.inference(
          targetText,
          outputPath,
          encoderFile,
          decoderFile,
          postnetFile,
          waveglowFile,
          sslFile,
          dicFolder,
          null,
          TextToSpeech.MODEL_TYPE_TACOTRON2);

      setState(() {
        predict_result = "finish";
      });
    });
  }

  void _ailiaTextToSpeechGPTSoVITS_JA() {
    TextToSpeech textToSpeech = TextToSpeech();
    List<String> modelList =
        textToSpeech.getModelList(TextToSpeech.MODEL_TYPE_GPT_SOVITS_JA);
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
      await textToSpeech.inference(
          targetText,
          outputPath,
          encoderFile,
          decoderFile,
          postnetFile,
          waveglowFile,
          sslFile,
          dicFolder,
          null,
          TextToSpeech.MODEL_TYPE_GPT_SOVITS_JA);

      setState(() {
        predict_result = "finish";
      });
    });
  }

  void _ailiaTextToSpeechGPTSoVITS_EN() {
    TextToSpeech textToSpeech = TextToSpeech();
    List<String> modelList =
        textToSpeech.getModelList(TextToSpeech.MODEL_TYPE_GPT_SOVITS_EN);
    _displayDownloadBegin();
    downloadModelFromModelList(0, modelList, () async {
      String encoderFile = await getModelPath("t2s_encoder.onnx");
      String decoderFile = await getModelPath("t2s_fsdec.onnx");
      String postnetFile = await getModelPath("t2s_sdec.opt.onnx");
      String waveglowFile = await getModelPath("vits.onnx");
      String sslFile = await getModelPath("cnhubert.onnx");

      String dicFolderOpenJtalk =
          await getModelPath("open_jtalk_dic_utf_8-1.11/");
      String dicFolderEn = await getModelPath("/");
      String targetText = "Hello world.";
      String outputPath = await getModelPath("temp$_counter.wav");
      await textToSpeech.inference(
          targetText,
          outputPath,
          encoderFile,
          decoderFile,
          postnetFile,
          waveglowFile,
          sslFile,
          dicFolderOpenJtalk,
          dicFolderEn,
          TextToSpeech.MODEL_TYPE_GPT_SOVITS_EN);

      setState(() {
        predict_result = "finish";
      });
    });
  }

  void _ailiaImageSegmentationSam2() async {
    // Load image
    image = await loadImageFromAssets("assets/truck.jpg");
    if (image == null) {
      return;
    }

    setState(() {
      // apply to ui (call build)
      isImageloaded = true;
    });

    // Download onnx
    _displayDownloadBegin();

    const remotePath =
        'https://storage.googleapis.com/ailia-models/segment-anything-2/';
    const imageEncoderModel = 'image_encoder_hiera_l.onnx';
    const promptEncoderModel = 'prompt_encoder_hiera_l.onnx';
    const maskEncoderModel = 'mask_decoder_hiera_l.onnx';

    final imageEncoderModelFile = await downloadModel(
        '$remotePath$imageEncoderModel', imageEncoderModel, null);
    final promptEncoderModelFile = await downloadModel(
        '$remotePath$promptEncoderModel', promptEncoderModel, null);
    final maskEncoderModelFile = await downloadModel(
        '$remotePath$maskEncoderModel', maskEncoderModel, null);

    _displayDownloadEnd();

    if (imageEncoderModelFile == null ||
        promptEncoderModelFile == null ||
        maskEncoderModelFile == null) {
      return;
    }

    AiliaModel imageEncoder = AiliaModel();
    imageEncoder.openFile(imageEncoderModelFile.path,
        memoryMode: ailia_dart.AILIA_MEMORY_REDUCE_INTERSTAGE);
    AiliaModel promptEncoder = AiliaModel();
    promptEncoder.openFile(promptEncoderModelFile.path,
        memoryMode: ailia_dart.AILIA_MEMORY_REDUCE_INTERSTAGE);
    AiliaModel maskEncoder = AiliaModel();
    maskEncoder.openFile(maskEncoderModelFile.path,
        memoryMode: ailia_dart.AILIA_MEMORY_REDUCE_INTERSTAGE);

    // Load image data
    final Sam2ImagePredictor sam2ImagePredictor = Sam2ImagePredictor();
    DateTime time = DateTime.now();
    final inputImage = await _uiImageToImage(image!);
    final features =
        await sam2ImagePredictor.setImage(inputImage, imageEncoder);
    print('setImage: ${DateTime.now().difference(time).inMilliseconds}ms');
    time = DateTime.now();

    final maskImage = sam2ImagePredictor.predict(
      features[0],
      [features[1], features[2]],
      [500, 375],
      [1],
      promptEncoder,
      maskEncoder,
    );
    print('predict: ${DateTime.now().difference(time).inMilliseconds}ms');
    time = DateTime.now();

    if (maskImage == null) {
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/sam2.png';

    img.Image result = await _overlayMaskImage(inputImage, maskImage);
    img.encodePngFile(filePath, result);
    print('saveImage: ${DateTime.now().difference(time).inMilliseconds}ms');

    final maskUiImage = await _imageToUiImage(result);
    setState(() {
      predict_result = 'Saved to $filePath';
      image = maskUiImage;
    });
  }

  Future<img.Image> _overlayMaskImage(
      img.Image srcImage, img.Image maskImage) async {
    final width = maskImage.width;
    final height = maskImage.height;
    if (width != maskImage.width || height != maskImage.height) {
      return srcImage;
    }

    final mask = maskImage.data!.toUint8List();
    final pixels = srcImage.data!.toUint8List();
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final index = (y * width + x) * 4;
        final maskValue = mask[(y * width + x) * maskImage.numChannels] ~/ 5;
        pixels[index] = _clamp(pixels[index] + maskValue, 0, 255);
      }
    }

    final image = img.Image.fromBytes(
        width: width, height: height, numChannels: 4, bytes: pixels.buffer);
    return image;
  }

  Future<img.Image> _uiImageToImage(ui.Image image) async {
    final inputData = await image.toByteData(format: ImageByteFormat.rawRgba);

    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      numChannels: 4,
      bytes: inputData!.buffer,
    );
  }

  Future<ui.Image> _imageToUiImage(img.Image image) async {
    final bytes = img.encodePng(image);
    return _uint8ListToImage(bytes);
  }

  Future<ui.Image> _uint8ListToImage(Uint8List bytes) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  int _clamp(int value, int min, int max) {
    return value < min
        ? min
        : value > max
            ? max
            : value;
  }

  void _ailiaImageClassificationResNet18() {
    // Load image
    loadImageFromAssets("assets/clock.jpg").then((imageAsync) {
      image = imageAsync;
      setState(() {
        // apply to ui (call build)
        isImageloaded = true;
      });

      // Download onnx
      _displayDownloadBegin();
      downloadModel(
          "https://storage.googleapis.com/ailia-models/resnet18/resnet18.onnx",
          "resnet18.onnx", (onnx_file) {
        _displayDownloadEnd();
        // Load image data
        image!.toByteData(format: ui.ImageByteFormat.rawRgba).then((data) {
          ailiaEnvironmentSample();
          setState(() {
            predict_result = ailiaPredictSample(onnx_file, data!);
          });
        });
      });
    });
  }

  void _ailiaAudioProcessingWhisper() async {
    ByteData data = await rootBundle.load("assets/demo.wav");
    final wav = await Wav.read(data.buffer.asUint8List());
    _displayDownloadBegin();
    downloadModel(
        "https://storage.googleapis.com/ailia-models/whisper/encoder_tiny.opt3.onnx",
        "encoder_tiny.opt3.onnx", (onnx_encoder_file) {
      downloadModel(
          "https://storage.googleapis.com/ailia-models/whisper/decoder_tiny_fix_kv_cache.opt3.onnx",
          "decoder_tiny_fix_kv_cache.opt3.onnx", (onnx_decoder_file) async {
        _displayDownloadEnd();
        AudioProcessingWhisper whisper = AudioProcessingWhisper();
        String text = await whisper.transcribe(wav, onnx_encoder_file,
            onnx_decoder_file, ailia_dart.AILIA_ENVIRONMENT_ID_AUTO);
        setState(() {
          predict_result = text;
        });
      });
    });
  }

  void _ailiaNaturalLanguageProcessingMultilingualE5() async {
    _displayDownloadBegin();
    downloadModel(
        "https://storage.googleapis.com/ailia-models/multilingual-e5/multilingual-e5-base.onnx",
        "multilingual-e5-base.onnx", (onnx_file) {
      downloadModel(
          "https://storage.googleapis.com/ailia-models/multilingual-e5/sentencepiece.bpe.model",
          "sentencepiece.bpe.model", (spe_file) async {
        print("Download model success");
        _displayDownloadEnd();
        NaturalLanguageProcessingMultilingualE5 e5 =
            NaturalLanguageProcessingMultilingualE5();
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
          predict_result =
              "$text1 vs $text2 sim $sim1\n$text1 vs $text3 sim $sim2\n";
        });
      });
    });
  }

  void _ailiaObjectDetectionYoloX() async {
    // Load image
    ByteData imData = await rootBundle.load("assets/clock.jpg");
    loadImageFromAssets("assets/clock.jpg").then((imageAsync) {
      image = imageAsync;
      setState(() {
        // apply to ui (call build)
        isImageloaded = true;
      });

      // Download onnx
      _displayDownloadBegin();
      downloadModel(
          "https://storage.googleapis.com/ailia-models/yolox/yolox_s.opt.onnx",
          "yolox_s.opt.onnx", (onnx_file) {
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
        resultSubText = res
            .map((e) =>
                "x:${e.x} y:${e.y} w:${e.w} h:${e.h} p:${e.prob} label:${yolox.category[e.category]}")
            .join("\n");

        setState(() {
          predict_result = resultSubText;
        });
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
    bool isImage = isSelectedItem == 'resnet18' ||
        isSelectedItem == 'yolox' ||
        isSelectedItem == 'sam2';

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
                  child: Text('sam2'),
                  value: 'sam2',
                ),
                DropdownMenuItem(
                  child: Text('resnet18'),
                  value: 'resnet18',
                ),
                DropdownMenuItem(
                  child: Text('whisper'),
                  value: 'whisper',
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
    if (image != null) {
      canvas.drawImage(image!, new Offset(0.0, 0.0), new Paint());
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
