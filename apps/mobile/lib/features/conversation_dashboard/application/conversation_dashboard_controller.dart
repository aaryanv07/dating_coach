import 'package:convo_coach/features/conversation_dashboard/application/conversation_dashboard_mapper.dart';
import 'package:convo_coach/features/conversation_dashboard/domain/conversation_analytics_repository.dart';
import 'package:convo_coach/features/conversation_dashboard/domain/dashboard_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final conversationAnalyticsRepositoryProvider =
    Provider<ConversationAnalyticsRepository>(
      (ref) => const UnavailableConversationAnalyticsRepository(),
    );

final conversationDashboardMapperProvider = Provider(
  (ref) => const ConversationDashboardMapper(),
);

final conversationDashboardProvider =
    FutureProvider.family<ConversationDashboardState, String>((
      ref,
      conversationId,
    ) async {
      final analytics = await ref
          .watch(conversationAnalyticsRepositoryProvider)
          .getForConversation(conversationId);
      return ref.watch(conversationDashboardMapperProvider).map(analytics);
    });
