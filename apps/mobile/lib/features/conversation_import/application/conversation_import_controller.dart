import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:convo_coach/features/conversation_import/application/conversation_extraction_service.dart';
import 'package:convo_coach/features/conversation_import/data/google_mlkit_text_recognition_provider.dart';
import 'package:convo_coach/features/conversation_import/data/image_preprocessor.dart';
import 'package:convo_coach/features/conversation_import/data/mock_ocr_engine.dart';
import 'package:convo_coach/features/conversation_import/data/real_conversation_ocr_engine.dart';
import 'package:convo_coach/features/conversation_import/data/screenshot_picker.dart';
import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/domain/normalizer.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/ocr_engine.dart';
import 'package:convo_coach/features/conversation_import/domain/readiness.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:convo_coach/features/conversations/application/conversation_list_controller.dart';
import 'package:convo_coach/features/conversations/domain/saved_conversation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _unset = Object();
const int _maximumScreenshots = 10;
const int _maximumScreenshotBytes = 10 * 1024 * 1024;
const int _maximumImportBytes = 50 * 1024 * 1024;
const int _historyLimit = 50;

final temporarySourceStoreProvider = Provider<TemporarySourceStore>(
  (ref) => InMemoryTemporarySourceStore(),
);

final ocrEngineProvider = Provider<OcrEngine>((ref) {
  final supportsMlKit = Platform.isAndroid || Platform.isIOS;
  if (!supportsMlKit) return const MockOcrEngine();
  return RealConversationOcrEngine(
    preprocessor: const SafeConversationImagePreprocessor(),
    textRecognitionProvider: GoogleMlKitTextRecognitionProvider(),
  );
});

final conversationExtractionServiceProvider =
    Provider<ConversationExtractionService>(
      (ref) => ConversationExtractionService(ref.watch(ocrEngineProvider)),
    );

final conversationTextParserProvider = Provider<ConversationTextParser>(
  (ref) => MockConversationTextParser(),
);

final screenshotPickerProvider = Provider<ScreenshotPicker>(
  (ref) => SystemScreenshotPicker(),
);

class ConversationImportState {
  const ConversationImportState({
    this.importType,
    this.title = 'Imported conversation',
    this.sources = const [],
    this.messages = const [],
    this.past = const [],
    this.future = const [],
    this.progress = 0,
    this.isBusy = false,
    this.isPreparingSources = false,
    this.saveConsent = false,
    this.extractionWarnings = const [],
    this.extractionMetadata,
    this.errorMessage,
  });

  final ConversationImportType? importType;
  final String title;
  final List<ImportSourceMetadata> sources;
  final List<ReviewMessage> messages;
  final List<List<ReviewMessage>> past;
  final List<List<ReviewMessage>> future;
  final double progress;
  final bool isBusy;
  final bool isPreparingSources;
  final bool saveConsent;
  final List<ExtractionWarning> extractionWarnings;
  final ExtractionMetadata? extractionMetadata;
  final String? errorMessage;

  ReadinessReport get readiness => ConversationReadiness.evaluate(messages);
  bool get canUndo => past.isNotEmpty;
  bool get canRedo => future.isNotEmpty;

  ConversationImportState copyWith({
    ConversationImportType? importType,
    String? title,
    List<ImportSourceMetadata>? sources,
    List<ReviewMessage>? messages,
    List<List<ReviewMessage>>? past,
    List<List<ReviewMessage>>? future,
    double? progress,
    bool? isBusy,
    bool? isPreparingSources,
    bool? saveConsent,
    List<ExtractionWarning>? extractionWarnings,
    Object? extractionMetadata = _unset,
    Object? errorMessage = _unset,
  }) {
    return ConversationImportState(
      importType: importType ?? this.importType,
      title: title ?? this.title,
      sources: sources ?? this.sources,
      messages: messages ?? this.messages,
      past: past ?? this.past,
      future: future ?? this.future,
      progress: progress ?? this.progress,
      isBusy: isBusy ?? this.isBusy,
      isPreparingSources: isPreparingSources ?? this.isPreparingSources,
      saveConsent: saveConsent ?? this.saveConsent,
      extractionWarnings: extractionWarnings ?? this.extractionWarnings,
      extractionMetadata: identical(extractionMetadata, _unset)
          ? this.extractionMetadata
          : extractionMetadata as ExtractionMetadata?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class ConversationImportController extends Notifier<ConversationImportState> {
  int _messageSequence = 0;
  ExtractionCancellationToken? _activeCancellationToken;

  @override
  ConversationImportState build() {
    final sourceStore = ref.read(temporarySourceStoreProvider);
    ref.onDispose(() {
      _activeCancellationToken?.cancel();
      unawaited(sourceStore.clear());
    });
    return const ConversationImportState();
  }

  Future<void> start(ConversationImportType importType) async {
    final activeToken = _activeCancellationToken;
    _activeCancellationToken = null;
    activeToken?.cancel();
    ref.read(conversationExtractionServiceProvider).clear();
    await ref.read(temporarySourceStoreProvider).clear();
    state = ConversationImportState(importType: importType);
  }

  Future<void> cancel() async {
    final activeToken = _activeCancellationToken;
    _activeCancellationToken = null;
    activeToken?.cancel();
    ref.read(conversationExtractionServiceProvider).clear();
    await ref.read(temporarySourceStoreProvider).clear();
    state = const ConversationImportState();
  }

  void setTitle(String title) => state = state.copyWith(title: title);

  void setSaveConsent(bool value) => state = state.copyWith(saveConsent: value);

  void clearError() => state = state.copyWith(errorMessage: null);

  Future<void> pickScreenshots() async {
    try {
      final picked = await ref
          .read(screenshotPickerProvider)
          .pick(startingIndex: state.sources.length);
      await addSources(picked);
    } on Object {
      state = state.copyWith(
        errorMessage:
            'Those screenshots could not be opened. Try different images.',
      );
    }
  }

  Future<void> addSources(List<TemporaryImportSource> incoming) async {
    if (incoming.isEmpty) return;
    if (state.sources.length + incoming.length > _maximumScreenshots) {
      state = state.copyWith(
        errorMessage:
            'Choose up to $_maximumScreenshots screenshots at a time.',
      );
      return;
    }
    final allowedMimeTypes = {'image/jpeg', 'image/png', 'image/webp'};
    if (incoming.any(
      (source) =>
          !allowedMimeTypes.contains(source.metadata.mimeType) ||
          source.metadata.byteSize > _maximumScreenshotBytes,
    )) {
      state = state.copyWith(
        errorMessage: 'Use JPG, PNG, or WebP images under 10 MB each.',
      );
      return;
    }
    final currentBytes = state.sources.fold<int>(
      0,
      (total, source) => total + source.byteSize,
    );
    final incomingBytes = incoming.fold<int>(
      0,
      (total, source) => total + source.metadata.byteSize,
    );
    if (currentBytes + incomingBytes > _maximumImportBytes) {
      state = state.copyWith(
        errorMessage: 'Keep the total import under 50 MB.',
      );
      return;
    }

    final normalized = <TemporaryImportSource>[];
    for (var offset = 0; offset < incoming.length; offset++) {
      final source = incoming[offset];
      final metadata = ImportSourceMetadata(
        id: source.metadata.id,
        name: source.metadata.name,
        mimeType: source.metadata.mimeType,
        byteSize: source.metadata.byteSize,
        index: state.sources.length + offset,
      );
      normalized.add(
        TemporaryImportSource(
          metadata: metadata,
          path: source.path,
          bytes: source.bytes,
        ),
      );
    }
    state = state.copyWith(
      isPreparingSources: true,
      progress: 0,
      errorMessage: null,
    );
    final store = ref.read(temporarySourceStoreProvider);
    for (var index = 0; index < normalized.length; index++) {
      await store.putAll([normalized[index]]);
      state = state.copyWith(progress: (index + 1) / normalized.length);
    }
    state = state.copyWith(
      importType: ConversationImportType.screenshot,
      sources: [
        ...state.sources,
        ...normalized.map((source) => source.metadata),
      ],
      isPreparingSources: false,
      errorMessage: null,
    );
  }

  Future<void> removeSource(String sourceId) async {
    final stored = await ref.read(temporarySourceStoreProvider).readAll();
    await _replaceStoredSources(
      stored.where((source) => source.metadata.id != sourceId).toList(),
    );
  }

  Future<void> moveSource(String sourceId, int delta) async {
    final stored = await ref.read(temporarySourceStoreProvider).readAll();
    final index = stored.indexWhere((source) => source.metadata.id == sourceId);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= stored.length) return;
    final moved = stored.removeAt(index);
    stored.insert(target, moved);
    await _replaceStoredSources(stored);
  }

  Future<bool> extractScreenshots() async {
    if (state.sources.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Add at least one screenshot first.',
      );
      return false;
    }
    state = state.copyWith(isBusy: true, progress: 0, errorMessage: null);
    final cancellationToken = ExtractionCancellationToken();
    _activeCancellationToken = cancellationToken;
    try {
      final temporarySources = await ref
          .read(temporarySourceStoreProvider)
          .readAll();
      final result = await ref
          .read(conversationExtractionServiceProvider)
          .extract(
            temporarySources,
            locale: PlatformDispatcher.instance.locale.toLanguageTag(),
            onProgress: (progress) {
              if (cancellationToken.isCancelled) return;
              state = state.copyWith(progress: progress);
            },
            cancellationToken: cancellationToken,
          );
      state = state.copyWith(
        messages: result.messages,
        past: const [],
        future: const [],
        extractionWarnings: result.warnings,
        extractionMetadata: result.metadata,
        progress: 1,
        isBusy: false,
      );
      return true;
    } on ExtractionCancelledException {
      if (!identical(_activeCancellationToken, cancellationToken)) return false;
      state = state.copyWith(
        isBusy: false,
        errorMessage:
            'Extraction cancelled. Your screenshots remain temporary for a safe retry.',
      );
      return false;
    } on ExtractionException catch (error) {
      if (!identical(_activeCancellationToken, cancellationToken)) return false;
      state = state.copyWith(isBusy: false, errorMessage: error.safeMessage);
      return false;
    } on Object {
      if (!identical(_activeCancellationToken, cancellationToken)) return false;
      state = state.copyWith(
        isBusy: false,
        errorMessage:
            'Text extraction did not finish. Your images are still on this device.',
      );
      return false;
    } finally {
      if (identical(_activeCancellationToken, cancellationToken)) {
        _activeCancellationToken = null;
      }
    }
  }

  void cancelExtraction() => _activeCancellationToken?.cancel();

  bool parsePaste(String text) {
    if (text.trim().length < 10) {
      state = state.copyWith(
        errorMessage: 'Paste at least two complete messages to continue.',
      );
      return false;
    }
    final messages = ref.read(conversationTextParserProvider).parse(text);
    if (messages.length < 2) {
      state = state.copyWith(
        errorMessage: 'Put each message on a new line so it can be reviewed.',
      );
      return false;
    }
    final source = ImportSourceMetadata(
      id: 'paste-source',
      name: 'Pasted text',
      mimeType: 'text/plain',
      byteSize: text.length,
      index: 0,
    );
    state = state.copyWith(
      importType: ConversationImportType.paste,
      sources: [source],
      messages: messages,
      past: const [],
      future: const [],
      extractionWarnings: const [],
      extractionMetadata: null,
      errorMessage: null,
    );
    return true;
  }

  void editMessage(String id, String text) {
    _updateMessage(
      id,
      (message) =>
          message.copyWith(text: text, status: ReviewMessageStatus.edited),
    );
  }

  void changeSpeaker(String id, MessageSpeaker speaker) {
    _updateMessage(
      id,
      (message) => message.copyWith(
        speaker: speaker,
        status: ReviewMessageStatus.edited,
      ),
    );
  }

  void swapSpeaker(String id) {
    final message = state.messages.firstWhere((item) => item.id == id);
    final speaker = switch (message.speaker) {
      MessageSpeaker.me => MessageSpeaker.other,
      MessageSpeaker.other || MessageSpeaker.unknown => MessageSpeaker.me,
    };
    changeSpeaker(id, speaker);
  }

  void swapAllSpeakers() {
    _commit([
      for (final message in state.messages)
        if (message.isDeleted)
          message
        else
          message.copyWith(
            speaker: switch (message.speaker) {
              MessageSpeaker.me => MessageSpeaker.other,
              MessageSpeaker.other => MessageSpeaker.me,
              MessageSpeaker.unknown => MessageSpeaker.unknown,
            },
            status: ReviewMessageStatus.edited,
          ),
    ]);
  }

  void deleteMessage(String id) {
    _updateMessage(
      id,
      (message) => message.copyWith(status: ReviewMessageStatus.deleted),
    );
  }

  void restoreMessage(String id) {
    _updateMessage(
      id,
      (message) => message.copyWith(status: ReviewMessageStatus.edited),
    );
  }

  void duplicateMessage(String id) {
    final index = state.messages.indexWhere((message) => message.id == id);
    if (index < 0) return;
    final original = state.messages[index];
    final next = [...state.messages]
      ..insert(
        index + 1,
        ReviewMessage(
          id: _nextMessageId('duplicate'),
          speaker: original.speaker,
          text: original.text,
          timestamp: original.timestamp,
          timestampEstimated: original.timestampEstimated,
          ocrConfidence: original.ocrConfidence,
          sourceScreenshotIndex: original.sourceScreenshotIndex,
          status: ReviewMessageStatus.added,
          visibleTimestampText: original.visibleTimestampText,
        ),
      );
    _commit(next);
  }

  void mergeWithNext(String id) {
    final currentIndex = state.messages.indexWhere(
      (message) => message.id == id,
    );
    if (currentIndex < 0 || state.messages[currentIndex].isDeleted) return;
    var nextIndex = currentIndex + 1;
    while (nextIndex < state.messages.length &&
        state.messages[nextIndex].isDeleted) {
      nextIndex++;
    }
    if (nextIndex >= state.messages.length) return;
    final current = state.messages[currentIndex];
    final nextMessage = state.messages[nextIndex];
    final next = [...state.messages];
    next[currentIndex] = current.copyWith(
      text: '${current.text.trim()} ${nextMessage.text.trim()}'.trim(),
      status: ReviewMessageStatus.edited,
    );
    next[nextIndex] = nextMessage.copyWith(status: ReviewMessageStatus.deleted);
    _commit(next);
  }

  bool splitMessage(String id, int offset) {
    final index = state.messages.indexWhere((message) => message.id == id);
    if (index < 0) return false;
    final original = state.messages[index];
    if (offset <= 0 || offset >= original.text.length) return false;
    final first = original.text.substring(0, offset).trim();
    final second = original.text.substring(offset).trim();
    if (first.isEmpty || second.isEmpty) return false;
    return splitMessageInto(id, first: first, second: second);
  }

  bool splitMessageInto(
    String id, {
    required String first,
    required String second,
  }) {
    final index = state.messages.indexWhere((message) => message.id == id);
    if (index < 0 || first.trim().isEmpty || second.trim().isEmpty) {
      return false;
    }
    final original = state.messages[index];
    final next = [...state.messages];
    next[index] = original.copyWith(
      text: first.trim(),
      status: ReviewMessageStatus.edited,
    );
    next.insert(
      index + 1,
      ReviewMessage(
        id: _nextMessageId('split'),
        speaker: original.speaker,
        text: second.trim(),
        timestamp: original.timestamp,
        timestampEstimated: original.timestampEstimated,
        ocrConfidence: original.ocrConfidence,
        sourceScreenshotIndex: original.sourceScreenshotIndex,
        status: ReviewMessageStatus.edited,
        visibleTimestampText: original.visibleTimestampText,
      ),
    );
    _commit(next);
    return true;
  }

  void moveMessage(String id, int delta) {
    final active = state.messages
        .where((message) => !message.isDeleted)
        .toList();
    final activeIndex = active.indexWhere((message) => message.id == id);
    final targetIndex = activeIndex + delta;
    if (activeIndex < 0 || targetIndex < 0 || targetIndex >= active.length) {
      return;
    }
    final fromIndex = state.messages.indexWhere((message) => message.id == id);
    final targetId = active[targetIndex].id;
    final toIndex = state.messages.indexWhere(
      (message) => message.id == targetId,
    );
    final next = [...state.messages];
    final message = next.removeAt(fromIndex);
    next.insert(toIndex, message);
    _commit(next);
  }

  void addMessage({
    String text = '',
    MessageSpeaker speaker = MessageSpeaker.me,
  }) {
    final next = [
      ...state.messages,
      ReviewMessage(
        id: _nextMessageId('added'),
        speaker: speaker,
        text: text,
        timestamp: null,
        timestampEstimated: false,
        ocrConfidence: null,
        sourceScreenshotIndex:
            state.importType == ConversationImportType.screenshot &&
                state.sources.isNotEmpty
            ? state.sources.last.index
            : null,
        status: ReviewMessageStatus.added,
      ),
    ];
    _commit(next);
  }

  void undo() {
    if (!state.canUndo) return;
    final previous = state.past.last;
    state = state.copyWith(
      messages: previous,
      past: state.past.sublist(0, state.past.length - 1),
      future: [state.messages, ...state.future],
    );
  }

  void redo() {
    if (!state.canRedo) return;
    final next = state.future.first;
    state = state.copyWith(
      messages: next,
      past: [...state.past, state.messages],
      future: state.future.sublist(1),
    );
  }

  Future<SavedConversation?> save() async {
    final readiness = state.readiness;
    if (!readiness.isReady || !state.saveConsent || state.importType == null) {
      state = state.copyWith(
        errorMessage: !state.saveConsent
            ? 'Confirm that you want to save this reviewed conversation.'
            : 'Resolve the readiness checks before saving.',
      );
      return null;
    }
    state = state.copyWith(isBusy: true, errorMessage: null);
    try {
      final normalized = ConversationNormalizer.normalize(
        title: state.title,
        importType: state.importType!,
        readinessScore: readiness.score,
        messages: state.messages,
        sources: state.sources,
        extractionMetadata: state.extractionMetadata,
      );
      final saved = await ref
          .read(conversationRepositoryProvider)
          .save(normalized);
      await ref.read(temporarySourceStoreProvider).clear();
      ref.read(conversationExtractionServiceProvider).clear();
      ref.invalidate(conversationListProvider);
      state = state.copyWith(isBusy: false);
      return saved;
    } on Object {
      state = state.copyWith(
        isBusy: false,
        errorMessage:
            'The reviewed conversation could not be saved. Try again.',
      );
      return null;
    }
  }

  void _updateMessage(
    String id,
    ReviewMessage Function(ReviewMessage message) transform,
  ) {
    final index = state.messages.indexWhere((message) => message.id == id);
    if (index < 0) return;
    final next = [...state.messages];
    next[index] = transform(next[index]);
    _commit(next);
  }

  void _commit(List<ReviewMessage> messages) {
    final past = [...state.past, state.messages];
    state = state.copyWith(
      messages: List.unmodifiable(messages),
      past: past.length > _historyLimit
          ? past.sublist(past.length - _historyLimit)
          : past,
      future: const [],
      errorMessage: null,
    );
  }

  Future<void> _replaceStoredSources(
    List<TemporaryImportSource> sources,
  ) async {
    final reindexed = <TemporaryImportSource>[];
    for (var index = 0; index < sources.length; index++) {
      final source = sources[index];
      reindexed.add(
        TemporaryImportSource(
          metadata: ImportSourceMetadata(
            id: source.metadata.id,
            name: source.metadata.name,
            mimeType: source.metadata.mimeType,
            byteSize: source.metadata.byteSize,
            index: index,
          ),
          path: source.path,
          bytes: source.bytes,
        ),
      );
    }
    final store = ref.read(temporarySourceStoreProvider);
    await store.clear();
    await store.putAll(reindexed);
    state = state.copyWith(
      sources: reindexed.map((source) => source.metadata).toList(),
      errorMessage: null,
    );
  }

  String _nextMessageId(String prefix) => '$prefix-${_messageSequence++}';
}

final conversationImportProvider =
    NotifierProvider<ConversationImportController, ConversationImportState>(
      ConversationImportController.new,
    );
