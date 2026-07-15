import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';

abstract interface class TextRecognitionProvider {
  String get providerId;

  String get providerVersion;

  Future<RecognizedTextPage> recognize(
    PreprocessedImage image, {
    required ExtractionCancellationToken cancellationToken,
  });
}
