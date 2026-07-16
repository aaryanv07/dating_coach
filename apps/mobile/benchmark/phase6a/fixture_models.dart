import 'package:convo_coach/features/conversation_import/domain/conversation_event.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';

enum BenchmarkFixtureTheme { light, dark }

class BenchmarkViewport {
  const BenchmarkViewport({required this.width, required this.height});

  factory BenchmarkViewport.fromJson(Map<String, Object?> json) {
    return BenchmarkViewport(
      width: _requiredInt(json, 'width'),
      height: _requiredInt(json, 'height'),
    );
  }

  final int width;
  final int height;
}

class BenchmarkExpectedMessage {
  const BenchmarkExpectedMessage({
    required this.id,
    required this.speaker,
    required this.text,
    required this.timestamp,
    required this.visibleTimestampText,
    required this.referenceConfidence,
    required this.requiresManualReview,
    required this.eventType,
  });

  factory BenchmarkExpectedMessage.fromJson(Map<String, Object?> json) {
    final timestamp = json['timestamp'];
    return BenchmarkExpectedMessage(
      id: _requiredString(json, 'id'),
      speaker: MessageSpeaker.values.byName(_requiredString(json, 'speaker')),
      text: _requiredString(json, 'text'),
      timestamp: timestamp == null
          ? null
          : DateTime.parse(_stringValue(timestamp, 'timestamp')),
      visibleTimestampText: _optionalString(json, 'visible_timestamp_text'),
      referenceConfidence: _requiredDouble(json, 'reference_confidence'),
      requiresManualReview: _requiredBool(json, 'requires_manual_review'),
      eventType: _eventType(
        _optionalString(json, 'event_type') ?? 'text_message',
      ),
    );
  }

  final String id;
  final MessageSpeaker speaker;
  final String text;
  final DateTime? timestamp;
  final String? visibleTimestampText;
  final double referenceConfidence;
  final bool requiresManualReview;
  final ConversationEventType eventType;
}

class BenchmarkExpectedEvent {
  const BenchmarkExpectedEvent({
    required this.id,
    required this.eventType,
    required this.speaker,
    required this.text,
    required this.requiresManualReview,
  });

  factory BenchmarkExpectedEvent.fromJson(Map<String, Object?> json) {
    return BenchmarkExpectedEvent(
      id: _requiredString(json, 'id'),
      eventType: _eventType(_requiredString(json, 'event_type')),
      speaker: MessageSpeaker.values.byName(_requiredString(json, 'speaker')),
      text: _requiredString(json, 'text'),
      requiresManualReview: _requiredBool(json, 'requires_manual_review'),
    );
  }

  final String id;
  final ConversationEventType eventType;
  final MessageSpeaker speaker;
  final String text;
  final bool requiresManualReview;
}

class BenchmarkReaction {
  const BenchmarkReaction({
    required this.messageId,
    required this.text,
    required this.recognizeAsText,
  });

  factory BenchmarkReaction.fromJson(Map<String, Object?> json) {
    return BenchmarkReaction(
      messageId: _requiredString(json, 'message_id'),
      text: _requiredString(json, 'text'),
      recognizeAsText: _requiredBool(json, 'recognize_as_text'),
    );
  }

  final String messageId;
  final String text;
  final bool recognizeAsText;
}

class BenchmarkFixturePage {
  const BenchmarkFixturePage({
    required this.sourceIndex,
    required this.dateLabel,
    required this.messageIds,
    required this.eventIds,
    required this.cropTopPixels,
    required this.lowContrast,
    required this.reactions,
  });

  factory BenchmarkFixturePage.fromJson(Map<String, Object?> json) {
    return BenchmarkFixturePage(
      sourceIndex: _requiredInt(json, 'source_index'),
      dateLabel: _optionalString(json, 'date_label'),
      messageIds: _stringList(json, 'message_ids'),
      eventIds: _optionalStringList(json, 'event_ids'),
      cropTopPixels: _requiredInt(json, 'crop_top_pixels'),
      lowContrast: _requiredBool(json, 'low_contrast'),
      reactions: _mapList(
        json,
        'reactions',
      ).map(BenchmarkReaction.fromJson).toList(growable: false),
    );
  }

  final int sourceIndex;
  final String? dateLabel;
  final List<String> messageIds;
  final List<String> eventIds;
  final int cropTopPixels;
  final bool lowContrast;
  final List<BenchmarkReaction> reactions;
}

class BenchmarkFixture {
  BenchmarkFixture({
    required this.schemaVersion,
    required this.id,
    required this.layoutPreset,
    required this.inspiration,
    required this.theme,
    required this.language,
    required this.viewport,
    required this.traits,
    required this.expectedSourceOrder,
    required this.expectedDuplicateIds,
    required this.expectedWarnings,
    required this.messages,
    required this.events,
    required this.pages,
  }) : messagesById = Map.unmodifiable({
         for (final message in messages) message.id: message,
       }),
       eventsById = Map.unmodifiable({
         for (final event in events) event.id: event,
       }) {
    _validate();
  }

  factory BenchmarkFixture.fromJson(Map<String, Object?> json) {
    final schemaVersion = _requiredInt(json, 'schema_version');
    if (schemaVersion != 1) {
      throw FormatException('Unsupported fixture schema: $schemaVersion');
    }
    return BenchmarkFixture(
      schemaVersion: schemaVersion,
      id: _requiredString(json, 'fixture_id'),
      layoutPreset: _requiredString(json, 'layout_preset'),
      inspiration: _requiredString(json, 'inspiration'),
      theme: BenchmarkFixtureTheme.values.byName(
        _requiredString(json, 'theme'),
      ),
      language: _requiredString(json, 'language'),
      viewport: BenchmarkViewport.fromJson(_requiredMap(json, 'viewport')),
      traits: Set.unmodifiable(_stringList(json, 'traits')),
      expectedSourceOrder: _intList(json, 'expected_source_order'),
      expectedDuplicateIds: _stringList(json, 'expected_duplicate_ids'),
      expectedWarnings: _stringList(
        json,
        'expected_warnings',
      ).map(ExtractionWarningCode.values.byName).toSet(),
      messages: _mapList(
        json,
        'messages',
      ).map(BenchmarkExpectedMessage.fromJson).toList(growable: false),
      events: _optionalMapList(
        json,
        'events',
      ).map(BenchmarkExpectedEvent.fromJson).toList(growable: false),
      pages: _mapList(
        json,
        'pages',
      ).map(BenchmarkFixturePage.fromJson).toList(growable: false),
    );
  }

  final int schemaVersion;
  final String id;
  final String layoutPreset;
  final String inspiration;
  final BenchmarkFixtureTheme theme;
  final String language;
  final BenchmarkViewport viewport;
  final Set<String> traits;
  final List<int> expectedSourceOrder;
  final List<String> expectedDuplicateIds;
  final Set<ExtractionWarningCode> expectedWarnings;
  final List<BenchmarkExpectedMessage> messages;
  final List<BenchmarkExpectedEvent> events;
  final List<BenchmarkFixturePage> pages;
  final Map<String, BenchmarkExpectedMessage> messagesById;
  final Map<String, BenchmarkExpectedEvent> eventsById;

  int sourceIndexForMessage(String messageId) {
    for (final sourceIndex in expectedSourceOrder) {
      final page = pages.firstWhere((page) => page.sourceIndex == sourceIndex);
      if (page.messageIds.contains(messageId)) return sourceIndex;
    }
    throw StateError('Message $messageId is not assigned to a page in $id.');
  }

  int sourceIndexForEvent(String eventId) {
    for (final sourceIndex in expectedSourceOrder) {
      final page = pages.firstWhere((page) => page.sourceIndex == sourceIndex);
      if (page.eventIds.contains(eventId)) return sourceIndex;
    }
    throw StateError('Event $eventId is not assigned to a page in $id.');
  }

  void _validate() {
    if (id.isEmpty || messages.isEmpty || pages.isEmpty) {
      throw FormatException(
        'Fixture identity, messages, and pages are required.',
      );
    }
    if (messagesById.length != messages.length) {
      throw FormatException('Fixture $id contains duplicate message IDs.');
    }
    if (eventsById.length != events.length ||
        messagesById.keys
            .toSet()
            .intersection(eventsById.keys.toSet())
            .isNotEmpty) {
      throw FormatException('Fixture $id contains duplicate event IDs.');
    }
    final pageIndices = pages.map((page) => page.sourceIndex).toSet();
    if (pageIndices.length != pages.length ||
        pageIndices.length != expectedSourceOrder.length ||
        !pageIndices.containsAll(expectedSourceOrder)) {
      throw FormatException('Fixture $id has an invalid expected page order.');
    }
    for (final page in pages) {
      for (final messageId in page.messageIds) {
        if (!messagesById.containsKey(messageId)) {
          throw FormatException('Page references unknown message $messageId.');
        }
      }
      for (final reaction in page.reactions) {
        if (!page.messageIds.contains(reaction.messageId)) {
          throw FormatException(
            'Reaction references a message outside its fixture page.',
          );
        }
      }
      for (final eventId in page.eventIds) {
        if (!eventsById.containsKey(eventId)) {
          throw FormatException('Page references unknown event $eventId.');
        }
      }
    }
    for (final message in messages) {
      sourceIndexForMessage(message.id);
      if (message.referenceConfidence < 0 || message.referenceConfidence > 1) {
        throw FormatException('Fixture confidence must be between 0 and 1.');
      }
    }
    for (final event in events) {
      sourceIndexForEvent(event.id);
      if (event.eventType.countsAsMessage) {
        throw FormatException(
          'Message-projecting events belong in the messages fixture collection.',
        );
      }
    }
  }
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  throw FormatException('$key must be an object.');
}

List<Map<String, Object?>> _mapList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('$key must be a list.');
  return value
      .map((item) {
        if (item is Map<String, Object?>) return item;
        if (item is Map) return item.cast<String, Object?>();
        throw FormatException('$key must contain objects.');
      })
      .toList(growable: false);
}

List<Map<String, Object?>> _optionalMapList(
  Map<String, Object?> json,
  String key,
) {
  if (!json.containsKey(key)) return const [];
  return _mapList(json, key);
}

List<String> _stringList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('$key must be a list.');
  return value.map((item) => _stringValue(item, key)).toList(growable: false);
}

List<String> _optionalStringList(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) return const [];
  return _stringList(json, key);
}

List<int> _intList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! int)) {
    throw FormatException('$key must be an integer list.');
  }
  return value.cast<int>().toList(growable: false);
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = _optionalString(json, key);
  if (value == null || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return _stringValue(value, key);
}

String _stringValue(Object? value, String key) {
  if (value is String) return value;
  throw FormatException('$key must be a string.');
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('$key must be an integer.');
}

double _requiredDouble(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('$key must be numeric.');
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('$key must be a boolean.');
}

ConversationEventType _eventType(String value) {
  final eventType = ConversationEventType.fromWireName(value);
  if (eventType == ConversationEventType.unknown && value != 'unknown') {
    throw FormatException('Unsupported event type: $value');
  }
  return eventType;
}
