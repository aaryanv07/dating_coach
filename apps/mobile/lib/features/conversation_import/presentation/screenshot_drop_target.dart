import 'dart:async';
import 'dart:typed_data';

import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:flutter/material.dart';
import 'package:super_clipboard/super_clipboard.dart' show DataReader;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class ScreenshotDropTarget extends StatefulWidget {
  const ScreenshotDropTarget({required this.onSources, super.key});

  final Future<void> Function(List<TemporaryImportSource> sources) onSources;

  @override
  State<ScreenshotDropTarget> createState() => _ScreenshotDropTargetState();
}

class _ScreenshotDropTargetState extends State<ScreenshotDropTarget> {
  static const _formats = [Formats.png, Formats.jpeg, Formats.webp];
  bool _isDragOver = false;

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: _formats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        if (!_isDragOver) setState(() => _isDragOver = true);
        return DropOperation.copy;
      },
      onDropLeave: (event) => setState(() => _isDragOver = false),
      onPerformDrop: (event) async {
        setState(() => _isDragOver = false);
        final sources = <TemporaryImportSource>[];
        for (var index = 0; index < event.session.items.length; index++) {
          final reader = event.session.items[index].dataReader;
          if (reader == null) continue;
          for (final format in _formats) {
            if (!reader.canProvide(format)) continue;
            final name =
                await reader.getSuggestedName() ?? 'Dropped screenshot';
            final result = await _readFile(reader, format, name, index);
            if (result != null) sources.add(result);
            break;
          }
        }
        if (sources.isNotEmpty) await widget.onSources(sources);
      },
      child: Semantics(
        label: 'Screenshot drop area',
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotionSpeed.fast),
          curve: AppMotion.standardCurve,
          constraints: const BoxConstraints(minHeight: 148),
          decoration: BoxDecoration(
            color: _isDragOver
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                : context.appColors.surfaceRaised,
            borderRadius: AppRadii.card,
            border: Border.all(
              color: _isDragOver
                  ? Theme.of(context).colorScheme.primary
                  : context.appColors.border,
              width: _isDragOver ? 2 : 1,
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, size: 32),
                SizedBox(height: AppSpacing.sm),
                Text('Drop screenshots here'),
                SizedBox(height: AppSpacing.xs),
                Text('JPG, PNG, or WebP'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<TemporaryImportSource?> _readFile(
    DataReader reader,
    FileFormat format,
    String name,
    int index,
  ) {
    final completer = Completer<TemporaryImportSource?>();
    final progress = reader.getFile(format, (file) async {
      try {
        final Uint8List bytes = await file.readAll();
        completer.complete(
          TemporaryImportSource(
            metadata: ImportSourceMetadata(
              id: 'drop-${DateTime.now().microsecondsSinceEpoch}-$index',
              name: file.fileName ?? name,
              mimeType: _mimeType(format),
              byteSize: bytes.length,
              index: index,
            ),
            bytes: bytes,
          ),
        );
      } on Object {
        completer.complete(null);
      }
    }, onError: (error) => completer.complete(null));
    if (progress == null) completer.complete(null);
    return completer.future;
  }

  String _mimeType(FileFormat format) {
    if (format == Formats.png) return 'image/png';
    if (format == Formats.webp) return 'image/webp';
    return 'image/jpeg';
  }
}
