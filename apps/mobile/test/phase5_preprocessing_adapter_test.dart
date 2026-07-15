import 'dart:io';
import 'dart:math';

import 'package:convo_coach/features/conversation_import/data/google_mlkit_text_recognition_provider.dart';
import 'package:convo_coach/features/conversation_import/data/image_preprocessor.dart';
import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

void main() {
  group('image preprocessing', () {
    test(
      'corrects orientation, resizes, normalizes, and strips metadata',
      () async {
        final sourceImage = img.Image(width: 80, height: 40)
          ..exif.imageIfd.orientation = 6
          ..textData = {'Private': 'synthetic-only'};
        img.fill(sourceImage, color: img.ColorRgb8(205, 205, 205));
        img.fillRect(
          sourceImage,
          x1: 4,
          y1: 4,
          x2: 35,
          y2: 16,
          color: img.ColorRgb8(145, 145, 145),
        );
        final encoded = img.encodeJpg(sourceImage);
        final exif = img.ExifData()..imageIfd.orientation = 6;
        final oriented = img.injectJpgExif(encoded, exif);
        expect(oriented, isNotNull);
        final source = _source(
          oriented!,
          index: 2,
          mimeType: 'image/jpeg',
          name: 'synthetic-2.jpg',
        );
        const preprocessor = SafeConversationImagePreprocessor(
          maximumDimension: 48,
          maximumOutputPixels: 48 * 48,
        );

        final result = await preprocessor.process(
          source,
          cancellationToken: ExtractionCancellationToken(),
        );
        final decoded = img.decodePng(result.bytes);

        expect(result.sourceIndex, 2);
        expect(result.orientationCorrected, isTrue);
        expect(result.wasResized, isTrue);
        expect(result.width, 24);
        expect(result.height, 48);
        expect(decoded, isNotNull);
        expect(decoded!.exif.imageIfd.hasOrientation, isFalse);
        expect(decoded.textData, isNull);
        expect(decoded.iccProfile, isNull);
      },
    );

    test(
      'rejects oversized decoded dimensions before pixel decoding',
      () async {
        final sourceImage = img.Image(width: 20, height: 20);
        final source = _source(img.encodePng(sourceImage));
        const preprocessor = SafeConversationImagePreprocessor(
          maximumSourcePixels: 100,
        );

        await expectLater(
          preprocessor.process(
            source,
            cancellationToken: ExtractionCancellationToken(),
          ),
          throwsA(isA<ExtractionException>()),
        );
      },
    );

    test(
      'rejects content whose decoded format does not match its MIME type',
      () async {
        final source = _source(img.encodePng(img.Image(width: 10, height: 10)));
        final mismatched = TemporaryImportSource(
          metadata: ImportSourceMetadata(
            id: source.metadata.id,
            name: 'synthetic.jpg',
            mimeType: 'image/jpeg',
            byteSize: source.metadata.byteSize,
            index: 0,
          ),
          bytes: source.bytes,
        );

        await expectLater(
          const SafeConversationImagePreprocessor().process(
            mismatched,
            cancellationToken: ExtractionCancellationToken(),
          ),
          throwsA(isA<ExtractionException>()),
        );
      },
    );

    test('increases separation for a low-contrast synthetic image', () async {
      final image = img.Image(width: 40, height: 20);
      img.fill(image, color: img.ColorRgb8(130, 130, 130));
      img.fillRect(
        image,
        x1: 0,
        y1: 0,
        x2: 19,
        y2: 19,
        color: img.ColorRgb8(120, 120, 120),
      );

      final result = await const SafeConversationImagePreprocessor().process(
        _source(img.encodePng(image)),
        cancellationToken: ExtractionCancellationToken(),
      );
      final processed = img.decodePng(result.bytes)!;
      final left = processed.getPixel(5, 5).r;
      final right = processed.getPixel(30, 5).r;

      expect((right - left).abs(), greaterThan(10));
    });
  });

  group('Google ML Kit adapter', () {
    test(
      'maps native text structure and confidence into provider-neutral data',
      () async {
        late Directory workspace;
        final gateway = _FakeGateway(_syntheticRecognizedText());
        final provider = GoogleMlKitTextRecognitionProvider(
          gatewayFactory: () => gateway,
          temporaryDirectoryFactory: () async {
            workspace = await Directory.systemTemp.createTemp(
              'ocr-adapter-test-',
            );
            return workspace;
          },
        );

        final page = await provider.recognize(
          PreprocessedImage(
            sourceIndex: 3,
            bytes: img.encodePng(img.Image(width: 60, height: 80)),
            width: 60,
            height: 80,
            orientationCorrected: false,
            wasResized: false,
          ),
          cancellationToken: ExtractionCancellationToken(),
        );

        expect(gateway.fileExistedDuringProcessing, isTrue);
        expect(gateway.closed, isTrue);
        expect(await workspace.exists(), isFalse);
        expect(page.sourceIndex, 3);
        expect(page.lines.single.text, 'Synthetic hello');
        expect(page.lines.single.confidence, 0.77);
        expect(page.lines.single.bounds.right, 54);
        expect(page.lines.single.elements.single.confidence, 0.74);
      },
    );

    test('cleans temporary files when native recognition fails', () async {
      late Directory workspace;
      final gateway = _ThrowingGateway();
      final provider = GoogleMlKitTextRecognitionProvider(
        gatewayFactory: () => gateway,
        temporaryDirectoryFactory: () async {
          workspace = await Directory.systemTemp.createTemp(
            'ocr-cleanup-test-',
          );
          return workspace;
        },
      );

      await expectLater(
        provider.recognize(
          PreprocessedImage(
            sourceIndex: 0,
            bytes: img.encodePng(img.Image(width: 10, height: 10)),
            width: 10,
            height: 10,
            orientationCorrected: false,
            wasResized: false,
          ),
          cancellationToken: ExtractionCancellationToken(),
        ),
        throwsA(isA<TransientExtractionException>()),
      );

      expect(gateway.closed, isTrue);
      expect(await workspace.exists(), isFalse);
    });

    test('honors cancellation before creating native resources', () async {
      var workspaceCreated = false;
      final token = ExtractionCancellationToken()..cancel();
      final provider = GoogleMlKitTextRecognitionProvider(
        gatewayFactory: () => _FakeGateway(_syntheticRecognizedText()),
        temporaryDirectoryFactory: () async {
          workspaceCreated = true;
          return Directory.systemTemp.createTemp('should-not-exist-');
        },
      );

      await expectLater(
        provider.recognize(
          PreprocessedImage(
            sourceIndex: 0,
            bytes: img.encodePng(img.Image(width: 10, height: 10)),
            width: 10,
            height: 10,
            orientationCorrected: false,
            wasResized: false,
          ),
          cancellationToken: token,
        ),
        throwsA(isA<ExtractionCancelledException>()),
      );
      expect(workspaceCreated, isFalse);
    });
  });
}

TemporaryImportSource _source(
  List<int> bytes, {
  int index = 0,
  String mimeType = 'image/png',
  String? name,
}) {
  return TemporaryImportSource(
    metadata: ImportSourceMetadata(
      id: 'synthetic-$index',
      name: name ?? 'synthetic-$index.png',
      mimeType: mimeType,
      byteSize: bytes.length,
      index: index,
    ),
    bytes: Uint8List.fromList(bytes),
  );
}

RecognizedText _syntheticRecognizedText() {
  final element = TextElement(
    text: 'Synthetic',
    symbols: const [],
    boundingBox: const Rect.fromLTRB(6, 12, 34, 28),
    recognizedLanguages: const ['en'],
    cornerPoints: const [
      Point(6, 12),
      Point(34, 12),
      Point(34, 28),
      Point(6, 28),
    ],
    confidence: 0.74,
    angle: 0,
  );
  final line = TextLine(
    text: 'Synthetic hello',
    elements: [element],
    boundingBox: const Rect.fromLTRB(6, 12, 54, 30),
    recognizedLanguages: const ['en'],
    cornerPoints: const [
      Point(6, 12),
      Point(54, 12),
      Point(54, 30),
      Point(6, 30),
    ],
    confidence: 0.77,
    angle: 0,
  );
  return RecognizedText(
    text: line.text,
    blocks: [
      TextBlock(
        text: line.text,
        lines: [line],
        boundingBox: line.boundingBox,
        recognizedLanguages: const ['en'],
        cornerPoints: line.cornerPoints,
      ),
    ],
  );
}

class _FakeGateway implements MlKitRecognizerGateway {
  _FakeGateway(this.result);

  final RecognizedText result;
  bool fileExistedDuringProcessing = false;
  bool closed = false;

  @override
  Future<RecognizedText> process(String filePath) async {
    fileExistedDuringProcessing = await File(filePath).exists();
    return result;
  }

  @override
  Future<void> close() async => closed = true;
}

class _ThrowingGateway implements MlKitRecognizerGateway {
  bool closed = false;

  @override
  Future<RecognizedText> process(String filePath) {
    throw PlatformException(code: 'timeout');
  }

  @override
  Future<void> close() async => closed = true;
}
