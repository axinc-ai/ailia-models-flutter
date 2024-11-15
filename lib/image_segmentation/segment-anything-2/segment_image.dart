import 'package:ailia/ailia_model.dart';
import 'package:image/image.dart';
import 'sam2_image_predictor.dart';

class SegmentImage {
  final Sam2ImagePredictor _predictor = Sam2ImagePredictor();
  final AiliaModel _imageEncoder = AiliaModel();
  final AiliaModel _promptEncoder = AiliaModel();
  final AiliaModel _maskDecoder = AiliaModel();
  AiliaTensor? _imageFeature;
  List<AiliaTensor>? _highResFeatures;
  bool _available = false;

  void open(String imageEncoderModelFilePath, String promptEncoderModelFilePath,
      String maskEncoderModelFilePath,
      {int envId = 0, int memoryMode = 11}) {
    _imageEncoder.openFile(imageEncoderModelFilePath,
        envId: envId, memoryMode: memoryMode);
    _promptEncoder.openFile(promptEncoderModelFilePath,
        envId: envId, memoryMode: memoryMode);
    _maskDecoder.openFile(maskEncoderModelFilePath,
        envId: envId, memoryMode: memoryMode);
    _available = true;
  }

  void close() {
    if (!_available) {
      return;
    }

    _imageEncoder.close();
    _promptEncoder.close();
    _maskDecoder.close();

    _available = false;
  }

  Future<bool> setImage(
    Image image,
  ) async {
    _imageFeature = null;
    _highResFeatures = null;

    final features = await _predictor.setImage(image, _imageEncoder);
    if (features.isEmpty) {
      return false;
    }

    _imageFeature = features[0];
    _highResFeatures = features.sublist(1);
    return true;
  }

  Image? run(List<Point> pointCoords, {List<int> pointLabels = const [1]}) {
    if (_imageFeature == null || _highResFeatures == null) {
      return null;
    }

    return _predictor.predict(
      _imageFeature!,
      _highResFeatures!,
      pointCoords,
      pointLabels,
      _promptEncoder,
      _maskDecoder,
    );
  }
}
