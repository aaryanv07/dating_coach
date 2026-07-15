import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:image/image.dart' as img;

abstract interface class ConversationImagePreprocessor {
  String get version;

  Future<PreprocessedImage> process(
    TemporaryImportSource source, {
    required ExtractionCancellationToken cancellationToken,
  });
}

class SafeConversationImagePreprocessor
    implements ConversationImagePreprocessor {
  const SafeConversationImagePreprocessor({
    this.maximumEncodedBytes = 10 * 1024 * 1024,
    this.maximumSourcePixels = 24 * 1024 * 1024,
    this.maximumOutputPixels = 8 * 1024 * 1024,
    this.maximumDimension = 4096,
  });

  final int maximumEncodedBytes;
  final int maximumSourcePixels;
  final int maximumOutputPixels;
  final int maximumDimension;

  @override
  String get version => 'image-v1';

  @override
  Future<PreprocessedImage> process(
    TemporaryImportSource source, {
    required ExtractionCancellationToken cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();
    final bytes =
        source.bytes ??
        (source.path == null ? null : await File(source.path!).readAsBytes());
    if (bytes == null || bytes.isEmpty) {
      throw const ExtractionException('The screenshot could not be read.');
    }
    if (bytes.length > maximumEncodedBytes) {
      throw const ExtractionException('The screenshot is larger than 10 MB.');
    }
    final config = _PreprocessingConfig(
      sourceIndex: source.metadata.index,
      maximumSourcePixels: maximumSourcePixels,
      maximumOutputPixels: maximumOutputPixels,
      maximumDimension: maximumDimension,
      mimeType: source.metadata.mimeType,
    );
    final result = await Isolate.run(() => _preprocess(bytes, config));
    cancellationToken.throwIfCancelled();
    return result;
  }
}

class _PreprocessingConfig {
  const _PreprocessingConfig({
    required this.sourceIndex,
    required this.maximumSourcePixels,
    required this.maximumOutputPixels,
    required this.maximumDimension,
    required this.mimeType,
  });

  final int sourceIndex;
  final int maximumSourcePixels;
  final int maximumOutputPixels;
  final int maximumDimension;
  final String mimeType;
}

PreprocessedImage _preprocess(Uint8List bytes, _PreprocessingConfig config) {
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (decoder == null || info == null || info.width <= 0 || info.height <= 0) {
    throw const ExtractionException(
      'Use a valid JPG, PNG, or WebP screenshot.',
    );
  }
  final expectedFormat = switch (config.mimeType) {
    'image/jpeg' => img.ImageFormat.jpg,
    'image/png' => img.ImageFormat.png,
    'image/webp' => img.ImageFormat.webp,
    _ => img.ImageFormat.invalid,
  };
  if (decoder.format != expectedFormat) {
    throw const ExtractionException(
      'The screenshot format does not match its file type.',
    );
  }
  if (info.width * info.height > config.maximumSourcePixels) {
    throw const ExtractionException(
      'This screenshot is too large to process safely.',
    );
  }
  final encodedOrientation = decoder.format == img.ImageFormat.jpg
      ? img.decodeJpgExif(bytes)?.imageIfd.orientation
      : null;
  var image = decoder.decode(bytes, frame: 0);
  if (image == null) {
    throw const ExtractionException('The screenshot could not be decoded.');
  }

  final orientation = encodedOrientation ?? image.exif.imageIfd.orientation;
  final orientationCorrected = orientation != null && orientation != 1;
  image = img.bakeOrientation(image);

  final pixels = image.width * image.height;
  final dimensionScale = math.min(
    config.maximumDimension / image.width,
    config.maximumDimension / image.height,
  );
  final pixelScale = math.sqrt(config.maximumOutputPixels / pixels);
  final scale = math.min(1, math.min(dimensionScale, pixelScale));
  final wasResized = scale < 0.999;
  if (wasResized) {
    image = img.copyResize(
      image,
      width: math.max(1, (image.width * scale).round()),
      height: math.max(1, (image.height * scale).round()),
      interpolation: img.Interpolation.linear,
    );
  }

  final contrast = _normalizedContrast(image);
  image = img.adjustColor(image, contrast: contrast);
  image
    ..exif = img.ExifData()
    ..textData = null
    ..iccProfile = null;
  final encoded = Uint8List.fromList(img.encodePng(image, level: 6));
  return PreprocessedImage(
    sourceIndex: config.sourceIndex,
    bytes: encoded,
    width: image.width,
    height: image.height,
    orientationCorrected: orientationCorrected,
    wasResized: wasResized,
  );
}

double _normalizedContrast(img.Image image) {
  final step = math.max(
    1,
    math.sqrt((image.width * image.height) / 10000).floor(),
  );
  var count = 0;
  var total = 0.0;
  var totalSquared = 0.0;
  for (var y = 0; y < image.height; y += step) {
    for (var x = 0; x < image.width; x += step) {
      final pixel = image.getPixel(x, y);
      final luminance =
          0.2126 * pixel.rNormalized +
          0.7152 * pixel.gNormalized +
          0.0722 * pixel.bNormalized;
      total += luminance;
      totalSquared += luminance * luminance;
      count++;
    }
  }
  if (count == 0) return 1;
  final mean = total / count;
  final variance = math.max(0, totalSquared / count - mean * mean);
  final deviation = math.sqrt(variance);
  if (deviation < 0.12) return 1.24;
  if (deviation < 0.2) return 1.12;
  return 1.04;
}
