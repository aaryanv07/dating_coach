import 'package:convo_coach/features/conversation_import/data/text_recognition_provider.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';

class FixtureReferenceTextRecognitionProvider
    implements TextRecognitionProvider {
  const FixtureReferenceTextRecognitionProvider(this.pages);

  final Map<int, RecognizedTextPage> pages;

  @override
  String get providerId => 'synthetic_fixture_reference';

  @override
  String get providerVersion => 'phase6a-v1';

  @override
  Future<RecognizedTextPage> recognize(
    PreprocessedImage image, {
    required ExtractionCancellationToken cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();
    final page = pages[image.sourceIndex];
    if (page == null) {
      throw const ExtractionException(
        'Synthetic benchmark page metadata is unavailable.',
      );
    }
    return RecognizedTextPage(
      sourceIndex: page.sourceIndex,
      width: image.width,
      height: image.height,
      lines: page.lines,
    );
  }
}
