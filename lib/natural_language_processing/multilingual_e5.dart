import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:ailia/ailia.dart';
import 'package:ailia/ailia_model.dart';

import 'package:ailia_tokenizer/ailia_tokenizer.dart' as ailia_tokenizer_dart;
import 'package:ailia_tokenizer/ailia_tokenizer_model.dart';

class NaturalLanguageProcessingMultilingualE5 {
  AiliaModel? ailiaModel;
  AiliaTokenizerModel? ailiaTokenizerModel;

  bool available = false;
  bool debug = false;

  void open(File onnxFile, File bpeFile, int envId) {
    if (available) {
      return;
    }

    ailiaModel = AiliaModel();
    ailiaTokenizerModel = AiliaTokenizerModel();

    ailiaModel!.openFile(onnxFile.path, envId: envId, memoryMode: 11);
    ailiaTokenizerModel!.openFile(
      modelFile: bpeFile.path,
      ailia_tokenizer_dart.AILIA_TOKENIZER_TYPE_XLM_ROBERTA,
    );

    available = true;
  }

  void close() {
    if (!available) {
      return;
    }

    ailiaModel!.close();
    ailiaTokenizerModel!.close();

    available = false;
  }

  Float32List _meanPool(Float32List features) {
    const numState = 768;
    Float32List mean = Float32List(numState);
    for (int j = 0; j < numState; j++) {
      double sum = 0;
      int numSentence = features.length ~/ numState;
      for (int i = 0; i < numSentence; i++) {
        sum = sum + features[i * numState + j];
      }
      sum /= numSentence;
      mean[j] = sum;
    }
    return mean;
  }

  void _normalize(Float32List data) {
    double sum = 0.0;
    for (int i = 0; i < data.length; i++) {
      sum += data[i] * data[i];
    }
    sum = sqrt(sum);
    for (int i = 0; i < data.length; i++) {
      data[i] /= sum;
    }
  }

  List<double> textEmbedding(String text) {
    if (!available) {
      throw Exception("Model not opened");
    }

    Int32List tokens = ailiaTokenizerModel!.encode(text);

    Float32List tokensF = Float32List(tokens.length);
    Float32List attentionMask = Float32List(tokens.length);
    String debugText = "";
    for (int i = 0; i < tokens.length; i++) {
      tokensF[i] = tokens[i].toDouble();
      attentionMask[i] = 1;
      debugText += " ${tokens[i]}";
    }
    if (debug) {
      print("Text $text");
      print("Tokens $debugText");
    }

    final totalToken = tokens.length;
    final chunkAmount = (totalToken + 511) ~/ 512;

    Float32List embeddingD = Float32List(0);
    if (debug) {
      print("chunkAmount $chunkAmount");
    }
    for (int i = 0; i < chunkAmount; i++) {
      int tokenCount;
      if ((totalToken - 512 * (i + 1)) > 0) {
        tokenCount = 512;
      } else {
        tokenCount = totalToken - (512 * i);
      }

      Float32List chunkTokens = Float32List(tokenCount);
      Float32List mask = Float32List(tokenCount);

      for (int j = 0; j < tokenCount; j++) {
        chunkTokens[j] = tokensF[j + (512 * i)];
        mask[j] = 1;
      }

      List<AiliaTensor> inputTensors = List<AiliaTensor>.empty(growable: true);

      for (int i = 0; i < 2; i++) {
        AiliaTensor inputTensor = AiliaTensor();
        int batchSize = 1;
        inputTensor.shape.x = tokenCount;
        inputTensor.shape.y = batchSize;
        inputTensor.shape.z = 1;
        inputTensor.shape.w = 1;
        inputTensor.shape.dim = 2;
        if (i == 0) {
          inputTensor.data = chunkTokens;
        } else {
          inputTensor.data = mask;
        }

        inputTensors.add(inputTensor);
      }

      List<AiliaTensor> outputTensors = ailiaModel!.run(inputTensors);

      Float32List embedding = outputTensors[0].data;

      Float32List result = _meanPool(embedding);
      _normalize(result);
      if (debug) {
        debugText = "";
        for (int i = 0; i < result.length; i++) {
          debugText += " ${result[i]}";
        }
        print("Embeddings $debugText");
      }

      if (embeddingD.isEmpty) {
        embeddingD = result;
      } else {
        for (int j = 0; j < embeddingD.length; j++) {
          embeddingD[j] = embeddingD[j] + result[j];
        }
      }
    }

    for (int i = 0; i < embeddingD.length; i++) {
      embeddingD[i] = embeddingD[i] / chunkAmount;
      if (embeddingD[i].isNaN) {
        throw (Exception("Embedding contains NaN."));
      }
    }

    return embeddingD.toList();
  }

  double cosSimilarity(List<double> s1, List<double> s2) {
    double cosSim = 0.0;
    for (int i = 0; i < s1.length; i++) {
      cosSim += s1[i] * s2[i];
    }

    return cosSim;
  }
}
