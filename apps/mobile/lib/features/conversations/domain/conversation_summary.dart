class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.participantName,
    required this.messageCount,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String participantName;
  final int messageCount;
  final DateTime updatedAt;
}
