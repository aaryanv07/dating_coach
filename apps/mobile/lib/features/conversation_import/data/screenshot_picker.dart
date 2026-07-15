import 'dart:typed_data';

import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:image_picker/image_picker.dart';

abstract interface class ScreenshotPicker {
  Future<List<TemporaryImportSource>> pick({required int startingIndex});
}

class SystemScreenshotPicker implements ScreenshotPicker {
  SystemScreenshotPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<List<TemporaryImportSource>> pick({required int startingIndex}) async {
    final images = await _picker.pickMultiImage(
      limit: 10,
      imageQuality: 100,
      requestFullMetadata: false,
    );
    return Future.wait([
      for (var index = 0; index < images.length; index++)
        _fromXFile(images[index], startingIndex + index),
    ]);
  }

  Future<TemporaryImportSource> _fromXFile(XFile file, int index) async {
    final length = await file.length();
    if (length > 10 * 1024 * 1024) {
      throw StateError('Screenshot exceeds the local import limit.');
    }
    final bytes = await file.readAsBytes();
    return TemporaryImportSource(
      metadata: ImportSourceMetadata(
        id: 'picked-${DateTime.now().microsecondsSinceEpoch}-$index',
        name: file.name,
        mimeType: file.mimeType ?? _mimeType(file.name),
        byteSize: length,
        index: index,
      ),
      path: file.path,
      bytes: Uint8List.fromList(bytes),
    );
  }

  String _mimeType(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'heic' || 'heif' => 'image/heic',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
