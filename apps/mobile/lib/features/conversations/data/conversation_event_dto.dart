import 'dart:convert';

import 'package:convo_coach/features/conversation_import/domain/conversation_event.dart';
import 'package:convo_coach/features/conversations/domain/saved_conversation.dart';
import 'package:crypto/crypto.dart';

class ConversationEventDto {
  const ConversationEventDto({required this.event});

  factory ConversationEventDto.fromJson(Map<String, Object?> json) {
    return ConversationEventDto(
      event: NormalizedConversationEvent(
        id: _string(json, 'id'),
        position: _int(json, 'position'),
        eventType: ConversationEventType.fromWireName(
          _string(json, 'event_type'),
        ),
        speaker: _string(json, 'speaker'),
        text: json['text'] as String?,
        timestamp: _dateTime(json['timestamp']),
        timestampEstimated: _bool(json, 'timestamp_is_estimated'),
        rawTimestampText: json['raw_timestamp_text'] as String?,
        sourceImageIndex: json['source_image_index'] as int?,
        sourceRegionId: json['source_region_id'] as String?,
        ocrConfidence: _double(json['ocr_confidence']),
        classificationConfidence: _double(json['classification_confidence']),
        speakerConfidence: _double(json['speaker_confidence']),
        timestampConfidence: _double(json['timestamp_confidence']),
        relationshipConfidence: _double(json['relationship_confidence']),
        requiresReview: _bool(json, 'requires_review'),
        metadata: _objectMap(json['metadata']),
        deletedAt: _dateTime(json['deleted_at']),
      ),
    );
  }

  final NormalizedConversationEvent event;

  Map<String, Object?> toJson() {
    return {
      'id': _wireUuid(event.id),
      'position': event.position,
      'event_type': event.eventType.wireName,
      'speaker': event.speaker,
      'text': event.text,
      'timestamp': event.timestamp?.toUtc().toIso8601String(),
      'timestamp_is_estimated': event.timestampEstimated,
      'raw_timestamp_text': event.rawTimestampText,
      'source_image_index': event.sourceImageIndex,
      'source_region_id': event.sourceRegionId,
      'ocr_confidence': event.ocrConfidence,
      'classification_confidence': event.classificationConfidence,
      'speaker_confidence': event.speakerConfidence,
      'timestamp_confidence': event.timestampConfidence,
      'relationship_confidence': event.relationshipConfidence,
      'requires_review': event.requiresReview,
      'metadata': event.metadata,
      'deleted_at': event.deletedAt?.toUtc().toIso8601String(),
    };
  }
}

class ConversationEventRelationshipDto {
  const ConversationEventRelationshipDto({required this.relationship});

  factory ConversationEventRelationshipDto.fromJson(Map<String, Object?> json) {
    return ConversationEventRelationshipDto(
      relationship: NormalizedConversationEventRelationship(
        id: _string(json, 'id'),
        sourceEventId: _string(json, 'source_event_id'),
        targetEventId: _string(json, 'target_event_id'),
        type: ConversationEventRelationshipType.fromWireName(
          _string(json, 'relationship_type'),
        ),
        confidence: _double(json['confidence']),
        metadata: _objectMap(json['metadata']),
      ),
    );
  }

  final NormalizedConversationEventRelationship relationship;

  Map<String, Object?> toJson() {
    return {
      'id': _wireUuid(relationship.id),
      'source_event_id': _wireUuid(relationship.sourceEventId),
      'target_event_id': _wireUuid(relationship.targetEventId),
      'relationship_type': relationship.type.wireName,
      'confidence': relationship.confidence,
      'metadata': relationship.metadata,
    };
  }
}

class ConversationEventSequenceDto {
  const ConversationEventSequenceDto({
    required this.events,
    required this.relationships,
  });

  factory ConversationEventSequenceDto.fromJson(Map<String, Object?> json) {
    if (json['schema_version'] != 'conversation-events.v1') {
      throw const FormatException('Unsupported conversation event schema.');
    }
    return ConversationEventSequenceDto(
      events: _mapList(
        json['events'],
      ).map(ConversationEventDto.fromJson).toList(growable: false),
      relationships: _mapList(
        json['relationships'],
      ).map(ConversationEventRelationshipDto.fromJson).toList(growable: false),
    );
  }

  final List<ConversationEventDto> events;
  final List<ConversationEventRelationshipDto> relationships;

  Map<String, Object?> toJson() {
    return {
      'schema_version': 'conversation-events.v1',
      'events': events.map((event) => event.toJson()).toList(growable: false),
      'relationships': relationships
          .map((relationship) => relationship.toJson())
          .toList(growable: false),
    };
  }
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing event field: $key');
  }
  return value;
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('Missing event field: $key');
  return value;
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Missing event field: $key');
  return value;
}

double? _double(Object? value) => value is num ? value.toDouble() : null;

DateTime? _dateTime(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List) throw const FormatException('Expected event list.');
  return value
      .map(
        (item) => item is Map<String, Object?>
            ? item
            : throw const FormatException('Expected event object.'),
      )
      .toList(growable: false);
}

String _wireUuid(String localId) {
  if (RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(localId)) {
    return localId.toLowerCase();
  }
  final bytes = sha256
      .convert(utf8.encode('conversation-events.v1:$localId'))
      .bytes
      .take(16)
      .toList();
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}
