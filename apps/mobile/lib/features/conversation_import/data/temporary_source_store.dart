import 'dart:typed_data';

import 'package:convo_coach/features/conversation_import/domain/review_message.dart';

class TemporaryImportSource {
  const TemporaryImportSource({required this.metadata, this.path, this.bytes});

  final ImportSourceMetadata metadata;
  final String? path;
  final Uint8List? bytes;
}

abstract interface class TemporarySourceStore {
  Future<void> putAll(List<TemporaryImportSource> sources);

  Future<List<TemporaryImportSource>> readAll();

  Future<TemporaryImportSource?> read(String id);

  Future<void> clear();
}

class InMemoryTemporarySourceStore implements TemporarySourceStore {
  final Map<String, TemporaryImportSource> _sources = {};

  @override
  Future<void> putAll(List<TemporaryImportSource> sources) async {
    for (final source in sources) {
      _sources[source.metadata.id] = source;
    }
  }

  @override
  Future<List<TemporaryImportSource>> readAll() async {
    final values = _sources.values.toList();
    values.sort((a, b) => a.metadata.index.compareTo(b.metadata.index));
    return values;
  }

  @override
  Future<TemporaryImportSource?> read(String id) async => _sources[id];

  @override
  Future<void> clear() async => _sources.clear();
}
