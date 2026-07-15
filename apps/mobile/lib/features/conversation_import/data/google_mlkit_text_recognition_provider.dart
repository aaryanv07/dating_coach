import 'dart:io';

import 'package:convo_coach/features/conversation_import/data/text_recognition_provider.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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

class GoogleMlKitTextRecognitionProvider implements TextRecognitionProvider {
  GoogleMlKitTextRecognitionProvider({
    MlKitGatewayFactory? gatewayFactory,
    TemporaryDirectoryFactory? temporaryDirectoryFactory,
  }) : _gatewayFactory = gatewayFactory ?? NativeMlKitRecognizerGateway.new,
       _temporaryDirectoryFactory =
           temporaryDirectoryFactory ??
           (() => Directory.systemTemp.createTemp('convocoach-ocr-'));

  final MlKitGatewayFactory _gatewayFactory;
  final TemporaryDirectoryFactory _temporaryDirectoryFactory;

  @override
  String get providerId => 'google_ml_kit_on_device';

  @override
  String get providerVersion => 'text-recognition-v2/plugin-0.16.0';

  @override
  Future<RecognizedTextPage> recognize(
    PreprocessedImage image, {
    required ExtractionCancellationToken cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();
    final workspace = await _temporaryDirectoryFactory();
    final file = File('${workspace.path}/sanitized-${image.sourceIndex}.png');
    MlKitRecognizerGateway? gateway;
    try {
      gateway = _gatewayFactory();
      await file.writeAsBytes(image.bytes, flush: true);
      cancellationToken.throwIfCancelled();
      final recognized = await gateway.process(file.path);
      cancellationToken.throwIfCancelled();
      return _map(recognized, image);
    } on PlatformException catch (error) {
      if (_isTransient(error.code)) {
        throw const TransientExtractionException(
          'On-device text recognition is temporarily unavailable.',
        );
      }
      throw const ExtractionException(
        'On-device text recognition could not read this screenshot.',
      );
    } finally {
      try {
        await gateway?.close();
      } on Object {
        // Resource cleanup continues even if the native recognizer already closed.
      }
      if (await workspace.exists()) await workspace.delete(recursive: true);
    }
  }

  RecognizedTextPage _map(RecognizedText recognized, PreprocessedImage image) {
    final lines = <RecognizedLine>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        lines.add(
          RecognizedLine(
            text: line.text,
            bounds: _bounds(line.boundingBox),
            confidence: line.confidence,
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
