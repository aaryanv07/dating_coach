import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:flutter/material.dart';

import 'fixture_models.dart';

class GeneratedBenchmarkFixture {
  const GeneratedBenchmarkFixture({
    required this.definition,
    required this.workspace,
    required this.sources,
    required this.referencePages,
  });

  final BenchmarkFixture definition;
  final Directory workspace;
  final List<TemporaryImportSource> sources;
  final Map<int, RecognizedTextPage> referencePages;

  Future<void> dispose() async {
    if (await workspace.exists()) await workspace.delete(recursive: true);
  }
}

class SyntheticScreenshotFixtureRenderer {
  const SyntheticScreenshotFixtureRenderer();

  Future<GeneratedBenchmarkFixture> generate(
    BenchmarkFixture fixture, {
    Directory? parentDirectory,
  }) async {
    final parent = parentDirectory ?? Directory.systemTemp;
    final workspace = await parent.createTemp('convocoach-phase6a-');
    final sources = <TemporaryImportSource>[];
    final referencePages = <int, RecognizedTextPage>{};
    try {
      for (final page in fixture.pages) {
        final rendered = await _render(fixture, page);
        final file = File(
          '${workspace.path}/synthetic-page-${page.sourceIndex}.png',
        );
        await file.writeAsBytes(rendered.bytes, flush: true);
        sources.add(
          TemporaryImportSource(
            metadata: ImportSourceMetadata(
              id: '${fixture.id}-page-${page.sourceIndex}',
              name: 'synthetic-page-${page.sourceIndex}.png',
              mimeType: 'image/png',
              byteSize: rendered.bytes.length,
              index: page.sourceIndex,
            ),
            path: file.path,
            bytes: rendered.bytes,
          ),
        );
        referencePages[page.sourceIndex] = rendered.referencePage;
      }
      sources.sort(
        (first, second) =>
            first.metadata.index.compareTo(second.metadata.index),
      );
      return GeneratedBenchmarkFixture(
        definition: fixture,
        workspace: workspace,
        sources: List.unmodifiable(sources),
        referencePages: Map.unmodifiable(referencePages),
      );
    } on Object {
      if (await workspace.exists()) await workspace.delete(recursive: true);
      rethrow;
    }
  }

  Future<_RenderedPage> _render(
    BenchmarkFixture fixture,
    BenchmarkFixturePage page,
  ) async {
    final width = fixture.viewport.width;
    final height = fixture.viewport.height;
    final scale = width / 720;
    final palette = _FixturePalette.forTheme(
      fixture.theme,
      lowContrast: page.lowContrast,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(palette.background, BlendMode.src);
    _drawBackdrop(canvas, fixture.layoutPreset, width, height, scale, palette);

    final headerHeight = 104 * scale;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), headerHeight),
      Paint()..color = palette.header,
    );
    canvas.drawCircle(
      Offset(48 * scale, headerHeight / 2),
      20 * scale,
      Paint()..color = palette.accent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(82 * scale, 35 * scale, 150 * scale, 15 * scale),
        Radius.circular(8 * scale),
      ),
      Paint()..color = palette.headerDetail,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(82 * scale, 59 * scale, 92 * scale, 10 * scale),
        Radius.circular(6 * scale),
      ),
      Paint()..color = palette.headerDetail.withValues(alpha: 0.62),
    );

    final recognizedLines = <RecognizedLine>[];
    var y = headerHeight + 42 * scale - page.cropTopPixels;
    if (page.dateLabel case final dateLabel?) {
      final style = TextStyle(
        color: palette.secondaryText,
        fontSize: 19 * scale,
        fontWeight: FontWeight.w600,
      );
      final painter = _textPainter(dateLabel, style);
      final offset = Offset((width - painter.width) / 2, y);
      painter.paint(canvas, offset);
      recognizedLines.add(
        RecognizedLine(
          text: dateLabel,
          bounds: _bounds(offset, painter.width, painter.height),
          confidence: 0.99,
        ),
      );
      y += painter.height + 46 * scale;
    }

    final messageBounds = <String, Rect>{};
    for (final messageId in page.messageIds) {
      final message = fixture.messagesById[messageId]!;
      final rendered = _drawMessage(
        canvas: canvas,
        message: message,
        width: width,
        y: y,
        scale: scale,
        palette: palette,
        layoutPreset: fixture.layoutPreset,
      );
      recognizedLines.addAll(rendered.lines);
      messageBounds[messageId] = rendered.bubbleBounds;
      y = rendered.bubbleBounds.bottom + 72 * scale;
    }

    for (final eventId in page.eventIds) {
      final event = fixture.eventsById[eventId]!;
      final rendered = _drawMessage(
        canvas: canvas,
        message: BenchmarkExpectedMessage(
          id: event.id,
          speaker: event.speaker,
          text: event.text,
          timestamp: null,
          visibleTimestampText: null,
          referenceConfidence: event.requiresManualReview ? 0.62 : 0.97,
          requiresManualReview: event.requiresManualReview,
          eventType: event.eventType,
        ),
        width: width,
        y: y,
        scale: scale,
        palette: palette,
        layoutPreset: fixture.layoutPreset,
      );
      recognizedLines.addAll(rendered.lines);
      y = rendered.bubbleBounds.bottom + 72 * scale;
    }

    for (final reaction in page.reactions) {
      final anchor = messageBounds[reaction.messageId]!;
      final reactionStyle = TextStyle(
        color: palette.primaryText,
        fontSize: 22 * scale,
      );
      final painter = _textPainter(reaction.text, reactionStyle);
      final pill = Rect.fromLTWH(
        anchor.right - 50 * scale,
        anchor.bottom - 10 * scale,
        painter.width + 24 * scale,
        painter.height + 12 * scale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(pill, Radius.circular(18 * scale)),
        Paint()..color = palette.reaction,
      );
      final offset = Offset(pill.left + 12 * scale, pill.top + 6 * scale);
      painter.paint(canvas, offset);
      if (reaction.recognizeAsText) {
        recognizedLines.add(
          RecognizedLine(
            text: reaction.text,
            bounds: _bounds(offset, painter.width, painter.height),
            confidence: 0.9,
          ),
        );
      }
    }

    recognizedLines.sort((first, second) {
      final vertical = first.bounds.top.compareTo(second.bounds.top);
      return vertical != 0
          ? vertical
          : first.bounds.left.compareTo(second.bounds.left);
    });
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (data == null) throw StateError('Synthetic fixture encoding failed.');
    final bytes = data.buffer.asUint8List();
    return _RenderedPage(
      bytes: Uint8List.fromList(bytes),
      referencePage: RecognizedTextPage(
        sourceIndex: page.sourceIndex,
        width: width,
        height: height,
        lines: List.unmodifiable(recognizedLines),
      ),
    );
  }

  _RenderedMessage _drawMessage({
    required Canvas canvas,
    required BenchmarkExpectedMessage message,
    required int width,
    required double y,
    required double scale,
    required _FixturePalette palette,
    required String layoutPreset,
  }) {
    final maximumBubbleWidth =
        width * (layoutPreset == 'prompt_thread' ? 0.78 : 0.72);
    final horizontalPadding = 24 * scale;
    final textStyle = TextStyle(
      color: palette.primaryText,
      fontSize: 25 * scale,
      height: 1.24,
      fontWeight: FontWeight.w400,
    );
    final lines = _wrapText(
      message.text,
      textStyle,
      maximumBubbleWidth - horizontalPadding * 2,
    );
    final linePainters = lines
        .map((line) => _textPainter(line, textStyle))
        .toList(growable: false);
    final widestText = linePainters.fold<double>(
      0,
      (current, painter) => painter.width > current ? painter.width : current,
    );
    final timestampStyle = TextStyle(
      color: palette.secondaryText,
      fontSize: 17 * scale,
      height: 1.1,
    );
    final timestampPainter = message.visibleTimestampText == null
        ? null
        : _textPainter(message.visibleTimestampText!, timestampStyle);
    final bubbleWidth = (widestText + horizontalPadding * 2)
        .clamp(150 * scale, maximumBubbleWidth)
        .toDouble();
    final lineHeight = linePainters.first.height;
    final timestampHeight = timestampPainter == null
        ? 0
        : timestampPainter.height + 10 * scale;
    final bubbleHeight =
        lineHeight * linePainters.length + timestampHeight + 34 * scale;
    final horizontalMargin = 30 * scale;
    final left = switch (message.speaker) {
      MessageSpeaker.other => horizontalMargin,
      MessageSpeaker.me => width - horizontalMargin - bubbleWidth,
      MessageSpeaker.system ||
      MessageSpeaker.unknown => (width - bubbleWidth) / 2,
    };
    final bubble = Rect.fromLTWH(left, y, bubbleWidth, bubbleHeight);
    final bubbleColor = message.speaker == MessageSpeaker.me
        ? palette.myBubble
        : palette.otherBubble;
    canvas.drawRRect(
      _bubbleShape(bubble, message.speaker, layoutPreset, scale),
      Paint()..color = bubbleColor,
    );
    if (layoutPreset == 'prompt_thread') {
      canvas.drawRect(
        Rect.fromLTWH(bubble.left, bubble.top, 5 * scale, bubble.height),
        Paint()..color = palette.accent,
      );
    }

    final recognized = <RecognizedLine>[];
    var textY = bubble.top + 17 * scale;
    for (var index = 0; index < linePainters.length; index++) {
      final painter = linePainters[index];
      final offset = Offset(bubble.left + horizontalPadding, textY);
      painter.paint(canvas, offset);
      recognized.add(
        RecognizedLine(
          text: lines[index],
          bounds: _bounds(offset, painter.width, painter.height),
          confidence: message.referenceConfidence,
        ),
      );
      textY += lineHeight;
    }
    if (timestampPainter != null) {
      final offset = Offset(
        bubble.right - horizontalPadding - timestampPainter.width,
        bubble.bottom - timestampPainter.height - 10 * scale,
      );
      timestampPainter.paint(canvas, offset);
      recognized.add(
        RecognizedLine(
          text: message.visibleTimestampText!,
          bounds: _bounds(
            offset,
            timestampPainter.width,
            timestampPainter.height,
          ),
          confidence: message.referenceConfidence,
        ),
      );
    }
    return _RenderedMessage(
      bubbleBounds: bubble,
      lines: List.unmodifiable(recognized),
    );
  }

  RRect _bubbleShape(
    Rect bounds,
    MessageSpeaker speaker,
    String layoutPreset,
    double scale,
  ) {
    final radius = switch (layoutPreset) {
      'match_stream' => 30 * scale,
      'social_dm' => 27 * scale,
      'first_move' => 20 * scale,
      _ => 16 * scale,
    };
    final small = 6 * scale;
    return RRect.fromRectAndCorners(
      bounds,
      topLeft: Radius.circular(
        speaker == MessageSpeaker.other ? small : radius,
      ),
      topRight: Radius.circular(speaker == MessageSpeaker.me ? small : radius),
      bottomLeft: Radius.circular(radius),
      bottomRight: Radius.circular(radius),
    );
  }

  void _drawBackdrop(
    Canvas canvas,
    String preset,
    int width,
    int height,
    double scale,
    _FixturePalette palette,
  ) {
    final paint = Paint()..color = palette.backdropDetail;
    if (preset == 'dense_thread') {
      for (var y = 150 * scale; y < height; y += 150 * scale) {
        canvas.drawCircle(Offset(width - 30 * scale, y), 5 * scale, paint);
      }
    } else if (preset == 'match_stream') {
      canvas.drawRect(
        Rect.fromLTWH(0, 104 * scale, width.toDouble(), 5 * scale),
        paint,
      );
    } else if (preset == 'first_move') {
      canvas.drawCircle(Offset(width / 2, 155 * scale), 28 * scale, paint);
    } else if (preset == 'prompt_thread') {
      canvas.drawRect(
        Rect.fromLTWH(0, 104 * scale, 12 * scale, height.toDouble()),
        paint,
      );
    } else {
      for (var x = 80 * scale; x < width; x += 180 * scale) {
        canvas.drawCircle(Offset(x, height - 50 * scale), 7 * scale, paint);
      }
    }
  }

  List<String> _wrapText(String text, TextStyle style, double maximumWidth) {
    final words = text.split(RegExp(r'\s+'));
    if (words.length == 1) return [text];
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (current.isNotEmpty &&
          _textPainter(candidate, style).width > maximumWidth) {
        lines.add(current);
        current = word;
      } else {
        current = candidate;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines;
  }

  TextPainter _textPainter(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    painter.layout();
    return painter;
  }

  OcrBounds _bounds(Offset offset, double width, double height) => OcrBounds(
    left: offset.dx,
    top: offset.dy,
    right: offset.dx + width,
    bottom: offset.dy + height,
  );
}

class _RenderedPage {
  const _RenderedPage({required this.bytes, required this.referencePage});

  final Uint8List bytes;
  final RecognizedTextPage referencePage;
}

class _RenderedMessage {
  const _RenderedMessage({required this.bubbleBounds, required this.lines});

  final Rect bubbleBounds;
  final List<RecognizedLine> lines;
}

class _FixturePalette {
  const _FixturePalette({
    required this.background,
    required this.header,
    required this.headerDetail,
    required this.accent,
    required this.primaryText,
    required this.secondaryText,
    required this.myBubble,
    required this.otherBubble,
    required this.reaction,
    required this.backdropDetail,
  });

  factory _FixturePalette.forTheme(
    BenchmarkFixtureTheme theme, {
    required bool lowContrast,
  }) {
    if (theme == BenchmarkFixtureTheme.dark) {
      return _FixturePalette(
        background: const Color(0xFF151719),
        header: const Color(0xFF22262A),
        headerDetail: const Color(0xFF6D747A),
        accent: const Color(0xFF5BC6A8),
        primaryText: lowContrast
            ? const Color(0xFF777C80)
            : const Color(0xFFF4F6F7),
        secondaryText: const Color(0xFFADB3B8),
        myBubble: const Color(0xFF245B66),
        otherBubble: const Color(0xFF303438),
        reaction: const Color(0xFF43484C),
        backdropDetail: const Color(0xFF2B3034),
      );
    }
    return _FixturePalette(
      background: const Color(0xFFF4F6F7),
      header: const Color(0xFFE7EBED),
      headerDetail: const Color(0xFF929A9F),
      accent: const Color(0xFF236F68),
      primaryText: lowContrast
          ? const Color(0xFFB6BCBF)
          : const Color(0xFF202426),
      secondaryText: const Color(0xFF687075),
      myBubble: const Color(0xFFCFEAE5),
      otherBubble: const Color(0xFFFFFFFF),
      reaction: const Color(0xFFE1E6E8),
      backdropDetail: const Color(0xFFDDE3E5),
    );
  }

  final Color background;
  final Color header;
  final Color headerDetail;
  final Color accent;
  final Color primaryText;
  final Color secondaryText;
  final Color myBubble;
  final Color otherBubble;
  final Color reaction;
  final Color backdropDetail;
}
