import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/features/authentication/application/authentication_providers.dart';
import 'package:convo_coach/features/conversations/data/api_conversation_repository.dart';
import 'package:convo_coach/features/conversations/data/conversation_api_client.dart';
import 'package:convo_coach/features/conversations/data/http_conversation_api_client.dart';
import 'package:convo_coach/features/conversations/domain/conversation_repository.dart';
import 'package:convo_coach/features/conversations/domain/conversation_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final conversationApiClientProvider = Provider<ConversationApiClient>((ref) {
  final baseUri = Uri.tryParse(AppConfig.apiBaseUrl);
  if (AppConfig.runtime.authenticatedApiConfigured &&
      baseUri != null &&
      baseUri.hasScheme &&
      baseUri.hasAuthority) {
    final tokens = ref.watch(authenticationAccessTokenProvider);
    return HttpConversationApiClient(
      baseUri: baseUri,
      accessTokenProvider: tokens.accessToken,
    );
  }
  return MockConversationApiClient();
});

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ApiConversationRepository(ref.watch(conversationApiClientProvider));
});

class ConversationListController
    extends AsyncNotifier<List<ConversationSummary>> {
  @override
  Future<List<ConversationSummary>> build() {
    return ref.watch(conversationRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(conversationRepositoryProvider).list(),
    );
  }

  Future<bool> deleteConversation(String conversationId) async {
    final current = switch (state) {
      AsyncData(:final value) => value,
      _ => <ConversationSummary>[],
    };
    try {
      await ref.read(conversationRepositoryProvider).delete(conversationId);
      state = AsyncData(
        current
            .where((conversation) => conversation.id != conversationId)
            .toList(growable: false),
      );
      return true;
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

final conversationListProvider =
    AsyncNotifierProvider<
      ConversationListController,
      List<ConversationSummary>
    >(ConversationListController.new);
