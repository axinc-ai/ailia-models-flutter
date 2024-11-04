import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:ailia/ailia_model.dart';

const imageSize = 1024;

class Sam2ImagePredictor {
  // ignore: non_constant_identifier_names
  Future<List<AiliaTensor>> setImage(
      Image image, AiliaModel imageEncoder) async {
    final resizedImage = await _resizeImage(image, imageSize, imageSize);
    AiliaTensor inputTensor = await _preprocessImage(resizedImage);

    List<AiliaTensor> output = imageEncoder.run([inputTensor]);
    // final vision_features = output[0];
    // final vision_pos_enc_0 = output[1];
    // final vision_pos_enc_1 = output[2];
    // final vision_pos_enc_2 = output[3];
    final backboneFpn0 = output[4];
    final backboneFpn1 = output[5];
    final backboneFpn2 = output[6];
    // final backbone_out = {
    //   "vision_features": vision_features,
    //   "vision_pos_enc": [vision_pos_enc_0, vision_pos_enc_1, vision_pos_enc_2],
    //   "backbone_fpn": [backbone_fpn_0, backbone_fpn_1, backbone_fpn_2]
    // };
    // final visionFeats =
    //     _prepareBackboneFeatures([backboneFpn0, backboneFpn1, backboneFpn2]);
    final visionFeats = [backboneFpn0, backboneFpn1, backboneFpn2];

    // Add no_mem_embed, which is added to the lowest rest feat. map during training on videos
    AiliaTensor noMemEmbed = _createAiliaTensor(Float32List(256), 1, 1, 256);
    noMemEmbed = _truncNormal(noMemEmbed, std: 0.02);
    visionFeats[visionFeats.length - 1] =
        _plus(visionFeats[visionFeats.length - 1], noMemEmbed);

    if (visionFeats.length != 3) {
      return [];
    }

    return [visionFeats[2], visionFeats[0], visionFeats[1]];

    // const bbFeatSizes = [
    //   [256, 256],
    //   [128, 128],
    //   [64, 64],
    // ];

    // List<AiliaTensor> feats = [];
    // for (int i = 0; i < 3; i++) {
    //   AiliaTensor feat = _transpose(visionFeats[i], 1, 2, 0);
    //   final featSize = bbFeatSizes[i];
    //   int y = feat.data.length ~/ (feat.shape.x * feat.shape.z * feat.shape.w);
    //   feat = _reshape(feat, 1, y, featSize[0], featSize[1]);
    //   feats.add(feat);
    // }

    // //     feats = [
    // //         np.transpose(feat, (1, 2, 0)).reshape(1, -1, *feat_size)
    // //         for feat, feat_size in zip(vision_feats[::-1], bb_feat_sizes[::-1])
    // //     ][::-1]

    // // final features = {
    // //   "image_embed": feats[feats.length - 1],
    // //   "high_res_feats": [feats[0], feats[1]],
    // // };
    // return [feats[feats.length - 1], feats[0], feats[1]];
  }

  AiliaTensor? predict(
    AiliaTensor imageFeature,
    List<AiliaTensor> highResFeatures,
    Size originalSize,
    List<double> pointCoords,
    List<int> pointLabels,
    // boxes: Optional[np.ndarray] = None,
    // mask_input: Optional[np.ndarray] = None,
    AiliaModel promptEncoder,
    AiliaModel maskDecoder,
  ) {
    if (pointCoords.isEmpty) {
      return null;
    }

    final promptInputs = _prepPrompts(pointCoords, pointLabels, originalSize);

    // sparse_embeddings, dense_embeddings, dense_pe = promptEncoder.run({"coords":concat_points[0], "labels":concat_points[1], "masks":mask_input_dummy, "masks_enable":masks_enable})
    final promptOutputs = promptEncoder.run(promptInputs);
    final sparseEmbeddings = promptOutputs[0];
    final denseEmbeddings = promptOutputs[1];
    final densePe = promptOutputs[2];

    final maskInputs = [
      imageFeature,
      densePe,
      sparseEmbeddings,
      denseEmbeddings,
      highResFeatures[0],
      highResFeatures[1]
    ];

    // masks, iou_pred, sam_tokens_out, object_score_logits  = mask_decoder.run({
    //     "image_embeddings":image_feature,
    //     "image_pe": dense_pe,
    //     "sparse_prompt_embeddings": sparse_embeddings,
    //     "dense_prompt_embeddings": dense_embeddings,
    //     "high_res_features1":high_res_features[0],
    //     "high_res_features2":high_res_features[1]})
    final maskOutputs = maskDecoder.run(maskInputs);
    AiliaTensor masks = maskOutputs[0]; // 1, 4, x , y
    AiliaTensor iouPred = maskOutputs[1]; // 1, 4

    int scoreIndex = _getMaxScoreIndex(iouPred);
    AiliaTensor? mask = _getMask(masks, scoreIndex);
    return mask;

    // low_res_masks, iou_predictions, _, _  = self.forward_postprocess(masks, iou_pred, sam_tokens_out, object_score_logits)

    // // # Upscale the masks to the original image resolution
    // masks = self.postprocess_masks(
    //     low_res_masks, orig_hw
    // )
    // low_res_masks = np.clip(low_res_masks, -32.0, 32.0)
    // mask_threshold = 0.0
    // masks = masks > mask_threshold

    // return masks, iou_predictions, low_res_masks
  }

  AiliaTensor? _getMask(AiliaTensor masks, int scoreIndex) {
    int numMasks = masks.shape.y;
    // Skip first and out range
    if (scoreIndex < 1 || scoreIndex >= numMasks) {
      return null;
    }

    int width = masks.shape.x;
    int height = masks.shape.y;
    int length = width * height;
    final result = _createAiliaTensor(
      Float32List(length),
      width,
      height,
      1,
    );

    int offset = length * scoreIndex;
    for (int i = 0; i < length; i++) {
      double value = masks.data[offset + i];
      result.data[i] = value > 0.0 ? 1.0 : 0.0;
    }

    return result;
  }

  int _getMaxScoreIndex(AiliaTensor iouPred) {
    int maxIndex = 0;
    double maxScore = 0.0;
    // Skip first
    for (int i = 1; i < iouPred.data.length; i++) {
      if (iouPred.data[i] > maxScore) {
        maxScore = iouPred.data[i];
        maxIndex = i;
      }
    }
    return maxIndex;
  }

  List<AiliaTensor> _prepPrompts(
      List<double> pointCoords, List<int> pointLabels, Size origHw) {
    final coords = _transformCoords(pointCoords, origHw);
    final labels = _createAiliaTensor(
      Float32List.fromList(pointLabels.map((e) => e.toDouble()).toList()),
      pointLabels.length,
      1,
      1,
      dim: 2,
    );

    // mask input
    List<double> dummy = List.filled(256 * 256, 0.0);
    final maskInput =
        _createAiliaTensor(Float32List.fromList(dummy), 256, 256, 1, dim: 3);
    final masksEnable =
        _createAiliaTensor(Float32List.fromList([0.0]), 1, 1, 1, dim: 1);

    return [coords, labels, maskInput, masksEnable];
  }

  AiliaTensor _transformCoords(List<double> coords, Size originalSize) {
    for (int i = 0; i < coords.length / 2; i++) {
      coords[i * 2] = coords[i * 2] / originalSize.width * imageSize;
      coords[i * 2 + 1] = coords[i * 2 + 1] / originalSize.height * imageSize;
    }

    return _createAiliaTensor(Float32List.fromList(coords), coords.length, 1, 1,
        dim: 3);
  }

  List<AiliaTensor> _prepareBackboneFeatures(List<AiliaTensor> backboneFns) {
    List<AiliaTensor> visionFeats = [];
    for (int i = 0; i < backboneFns.length; i++) {
      AiliaTensor b = backboneFns[i];
      int z = b.data.length ~/ (b.shape.x * b.shape.y);
      b = _reshape(b, 1, b.shape.x * b.shape.y, z, 1);
      b = _transpose(b, 2, 0, 1);
      visionFeats.add(b);
    }
    return visionFeats;
  }

  Future<AiliaTensor> _preprocessImage(Image image) async {
    AiliaTensor inputTensor = _createAiliaTensor(
        Float32List(image.width * image.height * 3),
        image.width,
        image.height,
        3);

    final data = await image.toByteData(format: ImageByteFormat.rawRgba);
    List pixel = data!.buffer.asUint8List().toList();

    List mean = [0.485, 0.456, 0.406];
    List std = [0.229, 0.224, 0.225];

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        for (int rgb = 0; rgb < 3; rgb++) {
          inputTensor.data[
                  y * image.width + x + rgb * image.width * image.height] =
              (pixel[(image.width * y + x) * 4 + rgb] / 255.0 - mean[rgb]) /
                  std[rgb]; // XXX
        }
      }
    }

    return inputTensor;
  }

  Future<Image> _resizeImage(Image image, int width, int height) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // Draw the original image onto the canvas with the new size
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      paint,
    );

    // End recording and convert to an image
    final picture = recorder.endRecording();
    final resizedImage = await picture.toImage(width, height);
    return resizedImage;
  }

  AiliaTensor _reshape(AiliaTensor input, int x, int y, int z, int w) {
    int length = x * y * z * w;
    if (x <= 0 || y <= 0 || z <= 0 || w <= 0 || input.data.length != length) {
      throw ArgumentError(
          'The total number of elements does not match the new shape.');
    }

    return _createAiliaTensor(input.data, x, y, z, w: w);

    // List<double> reshaped = List.filled(length, 0.0);

    // int index = 0;
    // for (int i = 0; i < x; i++) {
    //   for (int j = 0; j < y; j++) {
    //     for (int k = 0; k < z; k++) {
    //       for (int l = 0; l < w; l++) {
    //         reshaped[index++] =
    //             input.data[i * y * z * w + j * z * w + k * w + l];
    //       }
    //     }
    //   }
    // }

    // return _createAiliaTensor(x, y, z, 1, 4, Float32List.fromList(reshaped));
  }

  AiliaTensor _transpose(
      AiliaTensor input, int indexX, int indexY, int indexZ) {
    if (indexX < 0 ||
        indexX > 3 ||
        indexY < 0 ||
        indexY > 3 ||
        indexZ < 0 ||
        indexZ > 3) {
      throw ArgumentError(
          'The total number of elements does not match the new shape.');
    }
    final originX = input.shape.x;
    final originY = input.shape.y;
    final originZ = input.shape.z;
    final shape = [originX, originY, originZ];
    final x = shape[indexX];
    final y = shape[indexY];
    final z = shape[indexZ];
    List<double> transposed = List.filled(x * y * z, 0.0);

    int index = 0;
    for (int i = 0; i < x; i++) {
      for (int j = 0; j < y; j++) {
        for (int k = 0; k < z; k++) {
          transposed[index++] = input.data[i * y * z + j * z + k];
        }
      }
    }

    return _createAiliaTensor(Float32List.fromList(transposed), x, y, z);
  }

  AiliaTensor _generateNormalDistribution(
      AiliaTensor input, double mean, double std) {
    Random random = Random();
    int size = input.shape.x * input.shape.y * input.shape.z;
    List<double> samples = List.filled(size, 0.0);

    for (int i = 0; i < size; i++) {
      double u1 = random.nextDouble();
      double u2 = random.nextDouble();
      double z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
      samples[i] = z0 * std + mean;
    }
    input.data = Float32List.fromList(samples);

    return input;
  }

  AiliaTensor _clip(AiliaTensor input, double min, double max) {
    int size = input.shape.x * input.shape.y * input.shape.z;

    for (int i = 0; i < size; i++) {
      input.data[i] = input.data[i] < min
          ? min
          : input.data[i] > max
              ? max
              : input.data[i];
    }

    return input;
  }

  AiliaTensor _plus(AiliaTensor a, AiliaTensor b) {
    int x = a.shape.x > b.shape.x ? a.shape.x : b.shape.x;
    int y = a.shape.y > b.shape.y ? a.shape.y : b.shape.y;
    int z = a.shape.z > b.shape.z ? a.shape.z : b.shape.z;

    Float32List result = Float32List(x * y * z);

    for (int i = 0; i < x; i++) {
      for (int j = 0; j < y; j++) {
        for (int k = 0; k < z; k++) {
          double aValue = a.data[(i % a.shape.x) * a.shape.y * a.shape.z +
              (j % a.shape.y) * a.shape.z +
              (k % a.shape.z)];
          double bValue = b.data[(i % b.shape.x) * b.shape.y * b.shape.z +
              (j % b.shape.y) * b.shape.z +
              (k % b.shape.z)];
          result[i * y * z + j * z + k] = aValue + bValue;
        }
      }
    }

    return _createAiliaTensor(Float32List.fromList(result), x, y, z);
  }

  AiliaTensor _truncNormal(AiliaTensor input,
      {double std = 0.02, int a = -2, int b = 2}) {
    final output = _generateNormalDistribution(input, 0.0, std);
    return _clip(output, a * std, b * std);
  }

  AiliaTensor _createAiliaTensor(Float32List data, int x, int y, int z,
      {int w = 1, int dim = 4}) {
    final shape = AiliaShape();
    shape.x = x;
    shape.y = y;
    shape.z = z;
    shape.w = w;
    shape.dim = dim;

    AiliaTensor tensor = AiliaTensor();
    tensor.shape = shape;
    tensor.data = data;
    return tensor;
  }
}
