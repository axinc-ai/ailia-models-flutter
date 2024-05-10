// for ailia SDK Predict api sample

import 'dart:io';
import 'dart:typed_data';
import 'package:ailia/ailia_model.dart';
import 'image_classification/imagenet_category.dart';

void ailiaEnvironmentSample(){
  List<AiliaEnvironment> envList = AiliaModel.getEnvironmentList();
  for (int i = 0; i < envList.length; i++){
    print("${envList[i].id} ${envList[i].name}");
  }
}

String ailiaPredictSample(File onnxFile, ByteData data){
  AiliaModel ailia = AiliaModel();
  ailia.openFile(onnxFile.path);

  const int numClass = 1000;
  const int imageSize = 224;
  const int imageCannels = 3;

  AiliaTensor inputTensor = AiliaTensor();
  inputTensor.shape.x = imageSize;
  inputTensor.shape.y = imageSize;
  inputTensor.shape.z = imageCannels;
  inputTensor.shape.w = 1;
  inputTensor.shape.dim = 4;
  inputTensor.data = Float32List(imageSize * imageSize * imageCannels);

  List pixel = data.buffer.asUint8List().toList();

  List mean = [0.485, 0.456, 0.406];
  List std = [0.229, 0.224, 0.225];

  for (int y = 0; y < imageSize; y++){
    for (int x = 0; x < imageSize; x++){
      for (int rgb = 0; rgb < 3; rgb++){
        inputTensor.data[y * imageSize + x + rgb * imageSize * imageSize] = (pixel[(imageSize * y + x) * 4 + rgb] / 255.0 - mean[rgb])/std[rgb];
      }
    }
  }

  List<AiliaTensor> output = ailia.run([inputTensor]);
  
  double maxProb = 0.0;
  int maxI = 0;
  for (int i = 0; i < numClass; i++){
    if (maxProb < output[0].data[i]){
      maxProb = output[0].data[i];
      maxI = i;
    }
  }

  return "Class : ${maxI} ${imagenet_category[maxI]} Confidence : ${maxProb}";
}

