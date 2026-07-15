import 'package:convo_coach/features/conversations/application/conversation_list_controller.dart';
import 'package:convo_coach/features/conversations/domain/saved_conversation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final conversationDetailProvider =
    FutureProvider.family<SavedConversation?, String>((ref, conversationId) {
      return ref.watch(conversationRepositoryProvider).get(conversationId);
    });
