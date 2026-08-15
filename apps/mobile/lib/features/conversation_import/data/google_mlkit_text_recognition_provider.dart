import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:convo_coach/features/conversation_import/data/text_recognition_provider.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as image_lib;

abstract interface class MlKitRecognizerGateway {
  Future<RecognizedText> process(String filePath);

  Future<void> close();
}

class NativeMlKitRecognizerGateway implements MlKitRecognizerGateway {
  NativeMlKitRecognizerGateway()
    : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  @override
  Future<RecognizedText> process(String filePath) {
    return _recognizer.processImage(InputImage.fromFilePath(filePath));
  }

  @override
  Future<void> close() => _recognizer.close();
}

typedef MlKitGatewayFactory = MlKitRecognizerGateway Function();
typedef TemporaryDirectoryFactory = Future<Directory> Function();
typedef VisualConfidenceEstimator =
    double? Function(List<int> bytes, OcrBounds bounds);

class GoogleMlKitTextRecognitionProvider implements TextRecognitionProvider {
  GoogleMlKitTextRecognitionProvider({
    MlKitGatewayFactory? gatewayFactory,
    TemporaryDirectoryFactory? temporaryDirectoryFactory,
    this.visualConfidenceEstimator,
  }) : _gatewayFactory = gatewayFactory ?? NativeMlKitRecognizerGateway.new,
       _temporaryDirectoryFactory =
           temporaryDirectoryFactory ??
           (() => Directory.systemTemp.createTemp('convocoach-ocr-'));

  final MlKitGatewayFactory _gatewayFactory;
  final TemporaryDirectoryFactory _temporaryDirectoryFactory;
  final VisualConfidenceEstimator? visualConfidenceEstimator;
  MlKitRecognizerGateway? _gateway;
  Future<void> _operationTail = Future.value();

  @override
  String get providerId => 'google_ml_kit_on_device';

  @override
  String get providerVersion => 'text-recognition-v2/plugin-0.16.0';

  @override
  Future<RecognizedTextPage> recognize(
    PreprocessedImage image, {
    required ExtractionCancellationToken cancellationToken,
  }) {
    final operation = _operationTail.then(
      (_) => _recognize(image, cancellationToken: cancellationToken),
    );
    _operationTail = operation.then<void>((_) {}, onError: (_) {});
    return operation;
  }

  Future<RecognizedTextPage> _recognize(
    PreprocessedImage image, {
    required ExtractionCancellationToken cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();
    final workspace = await _temporaryDirectoryFactory();
    final file = File('${workspace.path}/sanitized-${image.sourceIndex}.png');
    try {
      final gateway = _gateway ??= _gatewayFactory();
      await file.writeAsBytes(image.bytes, flush: true);
      cancellationToken.throwIfCancelled();
      final recognized = await gateway.process(file.path);
      cancellationToken.throwIfCancelled();
      return _map(recognized, image);
    } on PlatformException catch (error) {
      await _resetGateway();
      if (_isTransient(error.code)) {
        throw const TransientExtractionException(
          'On-device text recognition is temporarily unavailable.',
        );
      }
      throw const ExtractionException(
        'On-device text recognition could not read this screenshot.',
      );
    } finally {
      if (await workspace.exists()) await workspace.delete(recursive: true);
    }
  }

  /// Releases the reusable native recognizer after the owning import scope ends.
  Future<void> close() async {
    await _operationTail;
    await _resetGateway();
  }

  Future<void> _resetGateway() async {
    final gateway = _gateway;
    _gateway = null;
    try {
      await gateway?.close();
    } on Object {
      // Cleanup remains best-effort if the native recognizer already closed.
    }
  }

  RecognizedTextPage _map(RecognizedText recognized, PreprocessedImage image) {
    final lines = <RecognizedLine>[];
    final decoded =
        visualConfidenceEstimator == null &&
            image.visualConfidenceRaster == null
        ? image_lib.decodeImage(image.bytes)
        : null;
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final bounds = _bounds(line.boundingBox);
        final visualConfidence =
            visualConfidenceEstimator?.call(image.bytes, bounds) ??
            _estimateRasterVisualTextConfidence(
              image.visualConfidenceRaster,
              bounds,
              sourceWidth: image.width,
              sourceHeight: image.height,
            ) ??
            _estimateDecodedVisualTextConfidence(decoded, bounds);
        lines.add(
          RecognizedLine(
            text: line.text,
            bounds: bounds,
            confidence: _minimumConfidence(line.confidence, visualConfidence),
            elements: [
              for (final element in line.elements)
                RecognizedElement(
                  text: element.text,
                  bounds: _bounds(element.boundingBox),
                  confidence: element.confidence,
                ),
            ],
          ),
        );
      }
    }
    return RecognizedTextPage(
      sourceIndex: image.sourceIndex,
      width: image.width,
      height: image.height,
      lines: List.unmodifiable(lines),
    );
  }

  OcrBounds _bounds(Rect rect) => OcrBounds(
    left: rect.left,
    top: rect.top,
    right: rect.right,
    bottom: rect.bottom,
  );

  bool _isTransient(String code) {
    final normalized = code.toLowerCase();
    return normalized.contains('unavailable') ||
        normalized.contains('busy') ||
        normalized.contains('timeout');
  }
}

double? _estimateRasterVisualTextConfidence(
  VisualConfidenceRaster? raster,
  OcrBounds bounds, {
  required int sourceWidth,
  required int sourceHeight,
}) {
  if (raster == null ||
      raster.width <= 0 ||
      raster.height <= 0 ||
      raster.luminance.length != raster.width * raster.height) {
    return null;
  }
  final left = (bounds.left * raster.width / sourceWidth)
      .floor()
      .clamp(0, raster.width - 1)
      .toInt();
  final top = (bounds.top * raster.height / sourceHeight)
      .floor()
      .clamp(0, raster.height - 1)
      .toInt();
  final right = (bounds.right * raster.width / sourceWidth)
      .ceil()
      .clamp(left + 1, raster.width)
      .toInt();
  final bottom = (bounds.bottom * raster.height / sourceHeight)
      .ceil()
      .clamp(top + 1, raster.height)
      .toInt();
  final histogram = Uint32List(256);
  var count = 0;
  for (var y = top; y < bottom; y++) {
    final row = y * raster.width;
    for (var x = left; x < right; x++) {
      histogram[raster.luminance[row + x]]++;
      count++;
    }
  }
  if (count < 8) return null;
  return _confidenceFromHistogram(histogram, count);
}

double? estimateVisualTextConfidence(List<int> bytes, OcrBounds bounds) {
  final decoded = image_lib.decodeImage(Uint8List.fromList(bytes));
  return _estimateDecodedVisualTextConfidence(decoded, bounds);
}

double? _estimateDecodedVisualTextConfidence(
  image_lib.Image? decoded,
  OcrBounds bounds,
) {
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) return null;
  final left = bounds.left.floor().clamp(0, decoded.width - 1).toInt();
  final top = bounds.top.floor().clamp(0, decoded.height - 1).toInt();
  final right = bounds.right.ceil().clamp(left + 1, decoded.width).toInt();
  final bottom = bounds.bottom.ceil().clamp(top + 1, decoded.height).toInt();
  final area = (right - left) * (bottom - top);
  final stride = math.sqrt(area / 4096).floor().clamp(1, 32).toInt();
  final luminance = <double>[];
  for (var y = top; y < bottom; y += stride) {
    for (var x = left; x < right; x += stride) {
      final pixel = decoded.getPixel(x, y);
      luminance.add(
        _relativeLuminance(
          pixel.r.toDouble(),
          pixel.g.toDouble(),
          pixel.b.toDouble(),
        ),
      );
    }
  }
  if (luminance.length < 8) return null;
  luminance.sort();
  final dark = luminance[(luminance.length * 0.03).floor()];
  final light =
      luminance[(luminance.length * 0.97).floor().clamp(
        0,
        luminance.length - 1,
      )];
  final ratio = (light + 0.05) / (dark + 0.05);
  return ((ratio - 1) / 3.5).clamp(0, 1);
}

double _confidenceFromHistogram(Uint32List histogram, int count) {
  final darkTarget = (count * 0.03).floor();
  final lightTarget = (count * 0.97).floor();
  var cumulative = 0;
  var dark = 0;
  var light = 255;
  var foundDark = false;
  for (var value = 0; value < histogram.length; value++) {
    cumulative += histogram[value];
    if (!foundDark && cumulative > darkTarget) {
      dark = value;
      foundDark = true;
    }
    if (cumulative > lightTarget) {
      light = value;
      break;
    }
  }
  final darkLinear = _linearChannel(dark.toDouble());
  final lightLinear = _linearChannel(light.toDouble());
  final ratio = (lightLinear + 0.05) / (darkLinear + 0.05);
  return ((ratio - 1) / 3.5).clamp(0, 1);
}

double _relativeLuminance(double red, double green, double blue) {
  return 0.2126 * _linearChannel(red) +
      0.7152 * _linearChannel(green) +
      0.0722 * _linearChannel(blue);
}

double _linearChannel(double value) {
  final normalized = value / 255;
  return normalized <= 0.04045
      ? normalized / 12.92
      : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
}

double? _minimumConfidence(double? provider, double? visual) {
  if (provider == null) return visual;
  if (visual == null) return provider;
  return math.min(provider, visual);
}
