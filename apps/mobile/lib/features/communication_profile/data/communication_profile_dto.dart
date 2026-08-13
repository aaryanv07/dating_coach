import 'dart:typed_data';

import 'package:convo_coach/features/communication_profile/domain/communication_profile.dart';

class CommunicationProfileDto {
  const CommunicationProfileDto({
    required this.preferredName,
    required this.relationshipIntention,
    required this.communicationTone,
    required this.messageLength,
    required this.usesEmojis,
    required this.jobTitle,
    required this.likes,
    required this.lookingFor,
    required this.hasProfilePhoto,
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
      jobTitle: json['job_title'] as String? ?? '',
      likes: _stringList(json['likes']),
      lookingFor: _stringList(json['looking_for']),
      hasProfilePhoto: json['has_profile_photo'] as bool? ?? false,
    );
  }

  factory CommunicationProfileDto.fromDomain(CommunicationProfile profile) {
    return CommunicationProfileDto(
      preferredName: profile.preferredName,
      relationshipIntention: profile.relationshipIntention,
      communicationTone: profile.communicationTone,
      messageLength: profile.messageLength,
      usesEmojis: profile.usesEmojis,
      jobTitle: profile.jobTitle,
      likes: profile.likes,
      lookingFor: profile.lookingFor,
      hasProfilePhoto: profile.profilePhotoBytes != null,
    );
  }

  final String preferredName;
  final RelationshipIntention relationshipIntention;
  final CommunicationTone communicationTone;
  final MessageLength messageLength;
  final bool usesEmojis;
  final String jobTitle;
  final List<String> likes;
  final List<String> lookingFor;
  final bool hasProfilePhoto;

  CommunicationProfile toDomain({List<int>? profilePhotoBytes}) {
    return CommunicationProfile(
      preferredName: preferredName,
      relationshipIntention: relationshipIntention,
      communicationTone: communicationTone,
      messageLength: messageLength,
      usesEmojis: usesEmojis,
      jobTitle: jobTitle,
      likes: List.unmodifiable(likes),
      lookingFor: List.unmodifiable(lookingFor),
      profilePhotoBytes: profilePhotoBytes == null
          ? null
          : Uint8List.fromList(profilePhotoBytes),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'preferred_name': preferredName.trim().isEmpty ? null : preferredName,
      'relationship_intention': _snakeCaseEnumName(relationshipIntention),
      'communication_tone': communicationTone.name,
      'preferred_message_length': messageLength.name,
      'uses_emojis': usesEmojis,
      'job_title': jobTitle.trim().isEmpty ? null : jobTitle,
      'likes': likes,
      'looking_for': lookingFor,
    };
  }
}

List<String> _stringList(Object? value) {
  if (value is! List<Object?>) return const [];
  return List.unmodifiable(value.whereType<String>());
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
