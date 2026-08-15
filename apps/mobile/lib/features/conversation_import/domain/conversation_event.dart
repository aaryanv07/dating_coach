import 'package:flutter/foundation.dart';

enum ConversationEventType {
  textMessage('text_message', 'Text message'),
  emojiMessage('emoji_message', 'Emoji message'),
  reaction('reaction', 'Reaction'),
  image('image', 'Image'),
  video('video', 'Video'),
  gif('gif', 'GIF'),
  sticker('sticker', 'Sticker'),
  voiceNote('voice_note', 'Voice note'),
  audio('audio', 'Audio'),
  document('document', 'Document'),
  link('link', 'Link'),
  location('location', 'Location'),
  contactCard('contact_card', 'Contact card'),
  poll('poll', 'Poll'),
  paymentRequest('payment_request', 'Payment request'),
  callStarted('call_started', 'Call started'),
  callEnded('call_ended', 'Call ended'),
  missedCall('missed_call', 'Missed call'),
  declinedCall('declined_call', 'Declined call'),
  deletedMessage('deleted_message', 'Deleted message'),
  editedMessageMarker('edited_message_marker', 'Edited marker'),
  replyReference('reply_reference', 'Reply reference'),
  systemMessage('system_message', 'System message'),
  dateSeparator('date_separator', 'Date separator'),
  unreadSeparator('unread_separator', 'Unread separator'),
  encryptionNotice('encryption_notice', 'Encryption notice'),
  memberEvent('member_event', 'Member event'),
  unknown('unknown', 'Unknown item');

  const ConversationEventType(this.wireName, this.label);

  final String wireName;
  final String label;

  static ConversationEventType fromWireName(String value) {
    return values.firstWhere(
      (type) => type.wireName == value,
      orElse: () => ConversationEventType.unknown,
    );
  }

  bool get countsAsMessage => switch (this) {
    ConversationEventType.textMessage ||
    ConversationEventType.emojiMessage ||
    ConversationEventType.image ||
    ConversationEventType.video ||
    ConversationEventType.gif ||
    ConversationEventType.sticker ||
    ConversationEventType.voiceNote ||
    ConversationEventType.audio ||
    ConversationEventType.document ||
    ConversationEventType.link ||
    ConversationEventType.location ||
    ConversationEventType.contactCard ||
    ConversationEventType.poll ||
    ConversationEventType.paymentRequest => true,
    ConversationEventType.reaction ||
    ConversationEventType.callStarted ||
    ConversationEventType.callEnded ||
    ConversationEventType.missedCall ||
    ConversationEventType.declinedCall ||
    ConversationEventType.deletedMessage ||
    ConversationEventType.editedMessageMarker ||
    ConversationEventType.replyReference ||
    ConversationEventType.systemMessage ||
    ConversationEventType.dateSeparator ||
    ConversationEventType.unreadSeparator ||
    ConversationEventType.encryptionNotice ||
    ConversationEventType.memberEvent ||
    ConversationEventType.unknown => false,
  };

  bool get isStructural => switch (this) {
    ConversationEventType.systemMessage ||
    ConversationEventType.dateSeparator ||
    ConversationEventType.unreadSeparator ||
    ConversationEventType.encryptionNotice ||
    ConversationEventType.memberEvent => true,
    _ => false,
  };

  bool get supportsTextEditing => switch (this) {
    ConversationEventType.textMessage ||
    ConversationEventType.emojiMessage ||
    ConversationEventType.reaction ||
    ConversationEventType.deletedMessage ||
    ConversationEventType.editedMessageMarker ||
    ConversationEventType.replyReference ||
    ConversationEventType.systemMessage ||
    ConversationEventType.dateSeparator ||
    ConversationEventType.unreadSeparator ||
    ConversationEventType.encryptionNotice ||
    ConversationEventType.memberEvent ||
    ConversationEventType.unknown => true,
    _ => false,
  };

  bool get supportsRelationship => switch (this) {
    ConversationEventType.reaction ||
    ConversationEventType.editedMessageMarker ||
    ConversationEventType.replyReference => true,
    _ => false,
  };
}

enum ConversationEventRelationshipType {
  reactionTarget('reaction_target'),
  replyTarget('reply_target'),
  editTarget('edit_target'),
  mediaCaption('media_caption'),
  callPair('call_pair'),
  systemContext('system_context'),
  duplicateOf('duplicate_of');

  const ConversationEventRelationshipType(this.wireName);

  final String wireName;

  static ConversationEventRelationshipType fromWireName(String value) {
    return values.firstWhere(
      (type) => type.wireName == value,
      orElse: () => ConversationEventRelationshipType.systemContext,
    );
  }
}

@immutable
class ConversationEventRelationship {
  const ConversationEventRelationship({
    required this.id,
    required this.sourceEventId,
    required this.targetEventId,
    required this.type,
    required this.confidence,
    this.metadata = const {},
  });

  final String id;
  final String sourceEventId;
  final String targetEventId;
  final ConversationEventRelationshipType type;
  final double? confidence;
  final Map<String, Object?> metadata;

  ConversationEventRelationship copyWith({
    String? targetEventId,
    double? confidence,
  }) {
    return ConversationEventRelationship(
      id: id,
      sourceEventId: sourceEventId,
      targetEventId: targetEventId ?? this.targetEventId,
      type: type,
      confidence: confidence ?? this.confidence,
      metadata: metadata,
    );
  }
}
