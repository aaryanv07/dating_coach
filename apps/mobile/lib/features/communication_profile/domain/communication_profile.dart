import 'dart:typed_data';

enum RelationshipIntention {
  serious,
  exploring,
  casual,
  friendshipFirst,
  unsure,
}

enum CommunicationTone {
  natural,
  playful,
  calm,
  direct,
  thoughtful,
  romantic,
  funny,
  reserved,
}

enum MessageLength { short, medium, long }

class CommunicationProfile {
  const CommunicationProfile({
    required this.preferredName,
    required this.relationshipIntention,
    required this.communicationTone,
    required this.messageLength,
    required this.usesEmojis,
    required this.jobTitle,
    required this.likes,
    required this.lookingFor,
    required this.profilePhotoBytes,
  });

  const CommunicationProfile.empty()
    : preferredName = '',
      relationshipIntention = RelationshipIntention.unsure,
      communicationTone = CommunicationTone.natural,
      messageLength = MessageLength.medium,
      usesEmojis = true,
      jobTitle = '',
      likes = const [],
      lookingFor = const [],
      profilePhotoBytes = null;

  final String preferredName;
  final RelationshipIntention relationshipIntention;
  final CommunicationTone communicationTone;
  final MessageLength messageLength;
  final bool usesEmojis;
  final String jobTitle;
  final List<String> likes;
  final List<String> lookingFor;
  final Uint8List? profilePhotoBytes;

  CommunicationProfile copyWith({
    String? preferredName,
    RelationshipIntention? relationshipIntention,
    CommunicationTone? communicationTone,
    MessageLength? messageLength,
    bool? usesEmojis,
    String? jobTitle,
    List<String>? likes,
    List<String>? lookingFor,
    Uint8List? profilePhotoBytes,
    bool clearProfilePhoto = false,
  }) {
    return CommunicationProfile(
      preferredName: preferredName ?? this.preferredName,
      relationshipIntention:
          relationshipIntention ?? this.relationshipIntention,
      communicationTone: communicationTone ?? this.communicationTone,
      messageLength: messageLength ?? this.messageLength,
      usesEmojis: usesEmojis ?? this.usesEmojis,
      jobTitle: jobTitle ?? this.jobTitle,
      likes: List.unmodifiable(likes ?? this.likes),
      lookingFor: List.unmodifiable(lookingFor ?? this.lookingFor),
      profilePhotoBytes: clearProfilePhoto
          ? null
          : profilePhotoBytes ?? this.profilePhotoBytes,
    );
  }
}

extension RelationshipIntentionLabel on RelationshipIntention {
  String get label => switch (this) {
    RelationshipIntention.serious => 'Serious relationship',
    RelationshipIntention.exploring => 'Dating and exploring',
    RelationshipIntention.casual => 'Casual dating',
    RelationshipIntention.friendshipFirst => 'Friendship first',
    RelationshipIntention.unsure => 'Unsure',
  };
}

extension CommunicationToneLabel on CommunicationTone {
  String get label => switch (this) {
    CommunicationTone.natural => 'Natural',
    CommunicationTone.playful => 'Playful',
    CommunicationTone.calm => 'Calm',
    CommunicationTone.direct => 'Direct',
    CommunicationTone.thoughtful => 'Thoughtful',
    CommunicationTone.romantic => 'Romantic',
    CommunicationTone.funny => 'Funny',
    CommunicationTone.reserved => 'Reserved',
  };
}

extension MessageLengthLabel on MessageLength {
  String get label => switch (this) {
    MessageLength.short => 'Short',
    MessageLength.medium => 'Medium',
    MessageLength.long => 'Long',
  };
}
