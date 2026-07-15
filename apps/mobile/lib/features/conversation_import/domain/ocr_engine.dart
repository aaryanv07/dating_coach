import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';

abstract interface class OcrEngine {
  String get providerId;

  String get providerVersion;

  String get extractionVersion;

  Future<OcrExtractionResult> extract(
    List<TemporaryImportSource> sources, {
    required String locale,
    required void Function(double progress) onProgress,
    required ExtractionCancellationToken cancellationToken,
  });
}

abstract interface class ConversationTextParser {
  List<ReviewMessage> parse(String text);
}
