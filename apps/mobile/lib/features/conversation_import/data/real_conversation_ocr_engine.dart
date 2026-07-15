import 'package:convo_coach/features/conversation_import/data/image_preprocessor.dart';
import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/data/text_recognition_provider.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/message_region_grouper.dart';
import 'package:convo_coach/features/conversation_import/domain/ocr_engine.dart';
import 'package:convo_coach/features/conversation_import/domain/overlap_detector.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:convo_coach/features/conversation_import/domain/screenshot_ordering.dart';
import 'package:convo_coach/features/conversation_import/domain/speaker_assignment.dart';

class RealConversationOcrEngine implements OcrEngine {
  const RealConversationOcrEngine({
    required this.preprocessor,
    required this.textRecognitionProvider,
    this.regionGrouper = const GeometryMessageRegionGrouper(),
    this.speakerAssignment = const GeometrySpeakerAssignment(),
    this.screenshotOrdering = const TimestampScreenshotOrdering(),
    this.overlapDetector = const BoundaryOverlapDetector(),
  });

  final ConversationImagePreprocessor preprocessor;
  final TextRecognitionProvider textRecognitionProvider;
  final MessageRegionGroupingStrategy regionGrouper;
  final SpeakerAssignmentStrategy speakerAssignment;
  final ScreenshotOrderingStrategy screenshotOrdering;
  final ScreenshotOverlapStrategy overlapDetector;

  @override
  String get providerId => textRecognitionProvider.providerId;

  @override
  String get providerVersion => textRecognitionProvider.providerVersion;

  @override
  String get extractionVersion => 'conversation-extraction-v1';

  @override
  Future<OcrExtractionResult> extract(
    List<TemporaryImportSource> sources, {
    required String locale,
    required void Function(double progress) onProgress,
    required ExtractionCancellationToken cancellationToken,
  }) async {
    if (sources.isEmpty) {
      throw const ExtractionException('Add a screenshot before extracting.');
    }
    final screenshots = <ExtractedScreenshot>[];
    var confidenceAvailable = true;
    for (var index = 0; index < sources.length; index++) {
      cancellationToken.throwIfCancelled();
      final processed = await preprocessor.process(
        sources[index],
        cancellationToken: cancellationToken,
      );
      onProgress((index + 0.35) / sources.length);
      final page = await textRecognitionProvider.recognize(
        processed,
        cancellationToken: cancellationToken,
      );
      final regions = regionGrouper
          .group(page, locale: locale)
          .map((region) {
            final assigned = speakerAssignment.assign(
              region,
              pageWidth: page.width,
            );
            if (region.confidence == null) confidenceAvailable = false;
            return region.copyWith(speaker: assigned);
          })
          .toList(growable: false);
      screenshots.add(
        ExtractedScreenshot(sourceIndex: page.sourceIndex, regions: regions),
      );
      onProgress((index + 1) / sources.length);
    }

    final ordered = screenshotOrdering.order(screenshots);
    final deduplicated = overlapDetector.removeDuplicates(ordered.screenshots);
    final warnings = [...ordered.warnings];
    if (!confidenceAvailable) {
      warnings.add(
        const ExtractionWarning(
          code: ExtractionWarningCode.confidenceUnavailable,
          message:
              'OCR confidence is unavailable on this device. Review every message carefully.',
        ),
      );
    }
    if (deduplicated.removedCount > 0) {
      warnings.add(
        ExtractionWarning(
          code: ExtractionWarningCode.duplicateOverlapRemoved,
          message:
              '${deduplicated.removedCount} overlapping message block${deduplicated.removedCount == 1 ? '' : 's'} removed. Review the join.',
        ),
      );
    }
    if (deduplicated.regions.any(
      (region) => region.speaker == MessageSpeaker.unknown,
    )) {
      warnings.add(
        const ExtractionWarning(
          code: ExtractionWarningCode.unknownSpeaker,
          message:
              'Some message positions were ambiguous. Assign those speakers before saving.',
        ),
      );
    }

    final messages = <ReviewMessage>[];
    for (var index = 0; index < deduplicated.regions.length; index++) {
      final region = deduplicated.regions[index];
      messages.add(
        ReviewMessage(
          id: 'ocr-${region.sourceIndex}-${region.sourceOrder}-$index',
          speaker: region.speaker,
          text: region.text,
          timestamp: region.timestamp,
          timestampEstimated: false,
          ocrConfidence: region.confidence,
          sourceScreenshotIndex: region.sourceIndex,
          status: ReviewMessageStatus.extracted,
          visibleTimestampText: region.visibleTimestampText,
        ),
      );
    }
    return OcrExtractionResult(
      messages: List.unmodifiable(messages),
      warnings: List.unmodifiable(warnings),
      metadata: ExtractionMetadata(
        provider: providerId,
        providerVersion: providerVersion,
        extractionVersion: extractionVersion,
        preprocessingVersion: preprocessor.version,
        confidenceAvailable: confidenceAvailable,
      ),
    );
  }
}
