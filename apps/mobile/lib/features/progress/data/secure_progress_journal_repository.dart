import 'dart:convert';

import 'package:convo_coach/features/progress/domain/progress_journal.dart';
import 'package:convo_coach/features/progress/domain/progress_journal_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _progressJournalStorageKey = 'convocoach.progress-journal.v1';

class SecureProgressJournalRepository implements ProgressJournalRepository {
  SecureProgressJournalRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<ProgressJournal> load() async {
    final encoded = await _storage.read(key: _progressJournalStorageKey);
    if (encoded == null || encoded.isEmpty) return ProgressJournal();
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, Object?> ||
        decoded['schema_version'] != progressJournalSchemaVersion) {
      throw const FormatException('Unsupported progress journal data.');
    }
    final rawOutcomes = decoded['outcomes'];
    if (rawOutcomes is! List<Object?>) {
      throw const FormatException('Invalid progress outcome list.');
    }
    final outcomes = <ConversationOutcome>[];
    for (final item in rawOutcomes) {
      if (item is! Map<String, Object?>) {
        throw const FormatException('Invalid progress outcome.');
      }
      final conversationId = item['conversation_id'];
      final reply = item['reply_outcome'];
      final plan = item['plan_confirmation'];
      final authenticity = item['authenticity_rating'];
      final clarity = item['clarity_rating'];
      final boundary = item['boundary_rating'];
      final updatedAt = item['updated_at'];
      if (conversationId is! String ||
          conversationId.isEmpty ||
          reply is! String ||
          plan is! String ||
          authenticity is! int ||
          clarity is! int ||
          boundary is! int ||
          updatedAt is! String) {
        throw const FormatException('Invalid progress outcome fields.');
      }
      final parsedReply = ReplyOutcome.values
          .where((value) => value.name == reply)
          .firstOrNull;
      final parsedPlan = PlanConfirmation.values
          .where((value) => value.name == plan)
          .firstOrNull;
      final parsedDate = DateTime.tryParse(updatedAt)?.toUtc();
      if (parsedReply == null || parsedPlan == null || parsedDate == null) {
        throw const FormatException('Invalid progress outcome values.');
      }
      if (authenticity < 1 ||
          authenticity > 5 ||
          clarity < 1 ||
          clarity > 5 ||
          boundary < 1 ||
          boundary > 5) {
        throw const FormatException(
          'Progress ratings must be between 1 and 5.',
        );
      }
      outcomes.add(
        ConversationOutcome(
          conversationId: conversationId,
          replyOutcome: parsedReply,
          planConfirmation: parsedPlan,
          authenticityRating: authenticity,
          clarityRating: clarity,
          boundaryRating: boundary,
          updatedAt: parsedDate,
        ),
      );
    }
    final reflection = decoded['private_reflection'];
    if (reflection is! String || reflection.length > 1000) {
      throw const FormatException('Invalid private reflection.');
    }
    return ProgressJournal(outcomes: outcomes, privateReflection: reflection);
  }

  @override
  Future<void> save(ProgressJournal journal) async {
    final payload = <String, Object?>{
      'schema_version': progressJournalSchemaVersion,
      'outcomes': [
        for (final outcome in journal.outcomes)
          <String, Object?>{
            'conversation_id': outcome.conversationId,
            'reply_outcome': outcome.replyOutcome.name,
            'plan_confirmation': outcome.planConfirmation.name,
            'authenticity_rating': outcome.authenticityRating,
            'clarity_rating': outcome.clarityRating,
            'boundary_rating': outcome.boundaryRating,
            'updated_at': outcome.updatedAt.toUtc().toIso8601String(),
          },
      ],
      'private_reflection': journal.privateReflection,
    };
    await _storage.write(
      key: _progressJournalStorageKey,
      value: jsonEncode(payload),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _progressJournalStorageKey);
  }
}
