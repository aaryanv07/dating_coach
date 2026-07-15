import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/ocr_engine.dart';
import 'package:crypto/crypto.dart';

class ConversationExtractionService {
  ConversationExtractionService(
    this._engine, {
    this.maximumRetries = 2,
    this.maximumCachedResults = 3,
  });

  final OcrEngine _engine;
  final int maximumRetries;
  final int maximumCachedResults;
  final LinkedHashMap<String, OcrExtractionResult> _completed = LinkedHashMap();
  final Map<String, Future<OcrExtractionResult>> _inFlight = {};

  Future<OcrExtractionResult> extract(
    List<TemporaryImportSource> sources, {
    required String locale,
    required void Function(double progress) onProgress,
    required ExtractionCancellationToken cancellationToken,
  }) async {
    final key = await _requestKey(sources, locale: locale);
    cancellationToken.throwIfCancelled();
    final cached = _completed[key];
    if (cached != null) {
      onProgress(1);
      return cached;
    }
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final operation = _extractWithRetry(
      sources,
      locale: locale,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
    _inFlight[key] = operation;
    try {
      final result = await operation;
      _completed[key] = result;
      while (_completed.length > maximumCachedResults) {
        _completed.remove(_completed.keys.first);
      }
      return result;
    } finally {
      _inFlight.remove(key);
    }
  }

  void clear() {
    _completed.clear();
    _inFlight.clear();
  }

  Future<OcrExtractionResult> _extractWithRetry(
    List<TemporaryImportSource> sources, {
    required String locale,
    required void Function(double progress) onProgress,
    required ExtractionCancellationToken cancellationToken,
  }) async {
    for (var attempt = 0; ; attempt++) {
      cancellationToken.throwIfCancelled();
      try {
        return await _engine.extract(
          sources,
          locale: locale,
          onProgress: onProgress,
          cancellationToken: cancellationToken,
        );
      } on TransientExtractionException {
        if (attempt >= maximumRetries) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 80 * (attempt + 1)));
      }
    }
  }

  Future<String> _requestKey(
    List<TemporaryImportSource> sources, {
    required String locale,
  }) async {
    final parts = <String>[
      _engine.providerId,
      _engine.providerVersion,
      _engine.extractionVersion,
      locale,
    ];
    for (final source in sources) {
      final bytes =
          source.bytes ??
          (source.path == null ? null : await File(source.path!).readAsBytes());
      if (bytes == null) {
        throw const ExtractionException('The screenshot could not be read.');
      }
      parts
        ..add(source.metadata.index.toString())
        ..add(sha256.convert(bytes).toString());
    }
    return sha256.convert(utf8.encode(parts.join('|'))).toString();
  }
}
