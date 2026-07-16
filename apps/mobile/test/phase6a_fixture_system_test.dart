import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convo_coach/features/conversation_import/data/image_preprocessor.dart';
import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/domain/conversation_event.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../benchmark/phase6a/fixture_catalog.dart';
import '../benchmark/phase6a/fixture_renderer.dart';
import '../benchmark/phase6a/generated_fixture_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fixture catalog covers every Phase 6A qualification trait', () async {
    final fixtures = await BenchmarkFixtureCatalog.load();
    final traits = fixtures.expand((fixture) => fixture.traits).toSet();

    expect(fixtures, hasLength(7));
    expect(
      traits,
      containsAll({
        'whatsapp_style',
        'tinder_style',
        'bumble_style',
        'hinge_style',
        'instagram_dm_style',
        'light_mode',
        'dark_mode',
        'english',
        'hinglish',
        'roman_hindi',
        'emoji_only_messages',
        'reactions',
        'long_messages',
        'cropped_screenshot',
        'overlapping_screenshots',
        'out_of_order_screenshots',
        'missing_timeline_sections',
        'low_contrast_text',
        'compact_screen',
        'large_screen',
        'mixed_english_hinglish',
        'emoji_heavy',
        'reaction_heavy',
        'deleted_messages',
        'media_placeholders',
        'system_messages',
        'original_design',
      }),
    );
  });

  test(
    'embedded native catalog matches the reviewable ground-truth files',
    () async {
      expect(
        phase6aEmbeddedGroundTruth.keys,
        orderedEquals(BenchmarkFixtureCatalog.groundTruthPaths),
      );
      for (final entry in phase6aEmbeddedGroundTruth.entries) {
        final file = File(entry.key);
        expect(await file.exists(), isTrue, reason: entry.key);
        expect(
          jsonDecode(entry.value),
          jsonDecode(await file.readAsString()),
          reason: 'Regenerate the embedded catalog after editing ${entry.key}.',
        );
      }
    },
  );

  test(
    'fixture generation creates metadata-free PNGs and cleans them',
    () async {
      final fixtures = await BenchmarkFixtureCatalog.load();
      const renderer = SyntheticScreenshotFixtureRenderer();

      for (final fixture in fixtures) {
        final generated = await renderer.generate(fixture);
        final workspace = generated.workspace;
        expect(generated.sources, hasLength(fixture.pages.length));
        for (final source in generated.sources) {
          final decoded = img.decodePng(source.bytes!);
          expect(decoded, isNotNull);
          expect(decoded!.width, fixture.viewport.width);
          expect(decoded.height, fixture.viewport.height);
          expect(decoded.exif.isEmpty, isTrue);
          expect(decoded.textData, isNull);
          expect(decoded.iccProfile, isNull);
          expect(generated.referencePages, contains(source.metadata.index));
        }
        await generated.dispose();
        expect(await workspace.exists(), isFalse);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('ground truth preserves multilingual and emoji-only content', () async {
    final fixtures = await BenchmarkFixtureCatalog.load();
    final text = fixtures
        .expand((fixture) => fixture.messages)
        .map((message) => message.text)
        .join('\n');

    expect(text, contains('Aaj ka scene kya hai?'));
    expect(text, contains('Tum usually Sunday ko kya karte ho?'));
    expect(text, contains('😂😂'));
    expect(
      fixtures.expand((fixture) => fixture.expectedDuplicateIds),
      containsAll({'dense-2', 'dense-3'}),
    );
  });

  test(
    'Phase 6A.2 originals cover typed events and reaction-heavy visuals',
    () async {
      final fixtures = await BenchmarkFixtureCatalog.load();
      final timeline = fixtures.firstWhere(
        (fixture) => fixture.id == 'event_timeline_mixed_language_low_contrast',
      );
      final reactionLab = fixtures.firstWhere(
        (fixture) => fixture.id == 'reaction_lab_emoji_heavy_hinglish',
      );

      expect(
        timeline.messages.map((message) => message.eventType),
        containsAll({
          ConversationEventType.image,
          ConversationEventType.voiceNote,
        }),
      );
      expect(
        timeline.events.map((event) => event.eventType),
        containsAll({
          ConversationEventType.deletedMessage,
          ConversationEventType.encryptionNotice,
          ConversationEventType.unreadSeparator,
        }),
      );
      expect(
        reactionLab.pages.expand((page) => page.reactions),
        hasLength(greaterThanOrEqualTo(4)),
      );
    },
  );

  test('preprocessor rejects an unsupported synthetic image format', () async {
    final image = img.Image(width: 20, height: 20);
    final bytes = Uint8List.fromList(img.encodeGif(image));
    const preprocessor = SafeConversationImagePreprocessor();

    await expectLater(
      preprocessor.process(
        TemporaryImportSource(
          metadata: ImportSourceMetadata(
            id: 'unsupported-synthetic',
            name: 'unsupported.gif',
            mimeType: 'image/gif',
            byteSize: bytes.length,
            index: 0,
          ),
          bytes: bytes,
        ),
        cancellationToken: ExtractionCancellationToken(),
      ),
      throwsA(isA<ExtractionException>()),
    );
  });
}
