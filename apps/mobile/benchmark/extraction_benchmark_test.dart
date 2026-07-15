import 'package:convo_coach/features/conversation_import/data/image_preprocessor.dart';
import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/message_region_grouper.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('synthetic extraction benchmark', () async {
    final syntheticImage = img.Image(width: 720, height: 1280);
    img.fill(syntheticImage, color: img.ColorRgb8(242, 242, 242));
    for (var row = 0; row < 24; row++) {
      final rightAligned = row.isOdd;
      img.fillRect(
        syntheticImage,
        x1: rightAligned ? 310 : 24,
        y1: 40 + row * 48,
        x2: rightAligned ? 696 : 410,
        y2: 72 + row * 48,
        color: rightAligned
            ? img.ColorRgb8(214, 236, 255)
            : img.ColorRgb8(255, 255, 255),
      );
    }
    final encoded = Uint8List.fromList(img.encodePng(syntheticImage));
    const preprocessor = SafeConversationImagePreprocessor();
    final preprocessing = Stopwatch()..start();
    for (var index = 0; index < 5; index++) {
      await preprocessor.process(
        TemporaryImportSource(
          metadata: ImportSourceMetadata(
            id: 'benchmark-$index',
            name: 'synthetic-$index.png',
            mimeType: 'image/png',
            byteSize: encoded.length,
            index: index,
          ),
          bytes: encoded,
        ),
        cancellationToken: ExtractionCancellationToken(),
      );
    }
    preprocessing.stop();

    final page = RecognizedTextPage(
      sourceIndex: 0,
      width: 720,
      height: 1280,
      lines: [
        for (var index = 0; index < 60; index++)
          RecognizedLine(
            text: 'Synthetic message $index',
            bounds: OcrBounds(
              left: index.isEven ? 24 : 390,
              top: 20 + index * 18,
              right: index.isEven ? 330 : 696,
              bottom: 36 + index * 18,
            ),
            confidence: 0.96,
          ),
      ],
    );
    const grouper = GeometryMessageRegionGrouper();
    final grouping = Stopwatch()..start();
    var regionCount = 0;
    for (var iteration = 0; iteration < 500; iteration++) {
      regionCount += grouper.group(page, locale: 'en_US').length;
    }
    grouping.stop();

    // Numeric-only output is safe for diagnostics; fixtures contain no user data.
    debugPrint(
      'PREPROCESS_BENCHMARK images=5 width=720 height=1280 '
      'total_ms=${preprocessing.elapsedMilliseconds} '
      'average_ms=${preprocessing.elapsedMilliseconds / 5}',
    );
    debugPrint(
      'GROUPING_BENCHMARK pages=500 lines=60 '
      'total_ms=${grouping.elapsedMilliseconds} regions=$regionCount',
    );
    expect(regionCount, greaterThan(0));
  });
}
