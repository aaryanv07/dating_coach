import 'package:convo_coach/features/conversations/domain/conversation_summary.dart';

class ConversationSummaryDto {
  const ConversationSummaryDto({
    required this.id,
    required this.title,
    required this.participantName,
    required this.messageCount,
    required this.updatedAt,
  });

  factory ConversationSummaryDto.fromJson(Map<String, Object?> json) {
    return ConversationSummaryDto(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled conversation',
      participantName: json['participant_name'] as String? ?? 'Other person',
      messageCount: json['message_count'] as int? ?? 0,
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String id;
  final String title;
  final String participantName;
  final int messageCount;
  final DateTime updatedAt;

  ConversationSummary toDomain() {
    return ConversationSummary(
      id: id,
      title: title,
      participantName: participantName,
      messageCount: messageCount,
      updatedAt: updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'participant_name': participantName,
      'message_count': messageCount,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
