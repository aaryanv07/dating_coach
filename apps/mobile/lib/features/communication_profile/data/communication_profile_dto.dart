import 'package:convo_coach/features/communication_profile/domain/communication_profile.dart';

class CommunicationProfileDto {
  const CommunicationProfileDto({
    required this.preferredName,
    required this.relationshipIntention,
    required this.communicationTone,
    required this.messageLength,
    required this.usesEmojis,
  });

  factory CommunicationProfileDto.fromJson(Map<String, Object?> json) {
    return CommunicationProfileDto(
      preferredName: json['preferred_name'] as String? ?? '',
      relationshipIntention: _enumByName(
        RelationshipIntention.values,
        _camelCaseEnumName(json['relationship_intention']),
        RelationshipIntention.unsure,
      ),
      communicationTone: _enumByName(
        CommunicationTone.values,
        json['communication_tone'],
        CommunicationTone.natural,
      ),
      messageLength: _enumByName(
        MessageLength.values,
        json['preferred_message_length'],
        MessageLength.medium,
      ),
      usesEmojis: json['uses_emojis'] as bool? ?? true,
    );
  }

  factory CommunicationProfileDto.fromDomain(CommunicationProfile profile) {
    return CommunicationProfileDto(
      preferredName: profile.preferredName,
      relationshipIntention: profile.relationshipIntention,
      communicationTone: profile.communicationTone,
      messageLength: profile.messageLength,
      usesEmojis: profile.usesEmojis,
    );
  }

  final String preferredName;
  final RelationshipIntention relationshipIntention;
  final CommunicationTone communicationTone;
  final MessageLength messageLength;
  final bool usesEmojis;

  CommunicationProfile toDomain() {
    return CommunicationProfile(
      preferredName: preferredName,
      relationshipIntention: relationshipIntention,
      communicationTone: communicationTone,
      messageLength: messageLength,
      usesEmojis: usesEmojis,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'preferred_name': preferredName,
      'relationship_intention': _snakeCaseEnumName(relationshipIntention),
      'communication_tone': communicationTone.name,
      'preferred_message_length': messageLength.name,
      'uses_emojis': usesEmojis,
    };
  }
}

String? _camelCaseEnumName(Object? raw) {
  if (raw == 'friendship_first') return 'friendshipFirst';
  return raw as String?;
}

String _snakeCaseEnumName(RelationshipIntention value) {
  if (value == RelationshipIntention.friendshipFirst) {
    return 'friendship_first';
  }
  return value.name;
}

T _enumByName<T extends Enum>(Iterable<T> values, Object? raw, T fallback) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}
