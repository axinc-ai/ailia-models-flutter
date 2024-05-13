import 'package:ailia/ailia_model.dart';
import 'package:ailia_models_flutter/object_detection/yolox.dart';
import 'package:flutter/material.dart';

// assets
import 'package:flutter/services.dart'; //rootBundle
import 'package:flutter/widgets.dart';
import 'dart:async'; //Future
import 'package:path_provider/path_provider.dart';
import 'package:wav/wav.dart';
import 'dart:io';
import 'package:ailia/ailia.dart' as ailia_dart;
import 'package:image/image.dart' as img;

// image
import 'dart:ui' as ui;

// category
import 'image_classification/image_classification_sample.dart';
import 'utils/download_model.dart';
import 'audio_processing/whisper.dart';
import 'natural_language_processing/multilingual_e5.dart';

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

  void _displayDownloadEnd(){
    setState(() {
      predict_result = "Download success.";
    });
  }

  void _changeModel(){
    switch (isSelectedItem){
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
    }
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
        });
      }
    );
  }

  void _ailiaAudioProcessingWhisper() async{
    ByteData data = await rootBundle.load("assets/demo.wav");
    final wav = await Wav.read(data.buffer.asUint8List());
    _displayDownloadBegin();
    downloadModel("https://storage.googleapis.com/ailia-models/whisper/encoder_tiny.opt3.onnx", "encoder_tiny.opt3.onnx", (onnx_encoder_file) {
      downloadModel("https://storage.googleapis.com/ailia-models/whisper/decoder_tiny_fix_kv_cache.opt3.onnx", "decoder_tiny_fix_kv_cache.opt3.onnx", (onnx_decoder_file) async {
        _displayDownloadEnd();
        AudioProcessingWhisper whisper = AudioProcessingWhisper();
        String text = await whisper.transcribe(wav, onnx_encoder_file, onnx_decoder_file, ailia_dart.AILIA_ENVIRONMENT_ID_AUTO);
        setState(() {
          predict_result = text;
        });
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
      });
    });
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
        });
      }
    );
  }


  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _changeModel();
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

    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
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