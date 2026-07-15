import 'package:convo_coach/features/communication_profile/application/communication_profile_controller.dart';
import 'package:convo_coach/features/communication_profile/data/api_communication_profile_repository.dart';
import 'package:convo_coach/features/communication_profile/data/communication_profile_api_client.dart';
import 'package:convo_coach/features/communication_profile/data/communication_profile_dto.dart';
import 'package:convo_coach/features/communication_profile/domain/communication_profile.dart';
import 'package:convo_coach/features/conversations/application/conversation_list_controller.dart';
import 'package:convo_coach/features/conversations/data/conversation_api_client.dart';
import 'package:convo_coach/features/conversations/data/conversation_summary_dto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('communication profile DTO round-trips explicit choices', () {
    const profile = CommunicationProfile(
      preferredName: 'Ari',
      relationshipIntention: RelationshipIntention.friendshipFirst,
      communicationTone: CommunicationTone.thoughtful,
      messageLength: MessageLength.short,
      usesEmojis: false,
    );

    final dto = CommunicationProfileDto.fromDomain(profile);
    final restored = CommunicationProfileDto.fromJson(dto.toJson()).toDomain();

    expect(restored.preferredName, 'Ari');
    expect(dto.toJson()['relationship_intention'], 'friendship_first');
    expect(dto.toJson()['preferred_message_length'], MessageLength.short.name);
    expect(
      restored.relationshipIntention,
      RelationshipIntention.friendshipFirst,
    );
    expect(restored.communicationTone, CommunicationTone.thoughtful);
    expect(restored.messageLength, MessageLength.short);
    expect(restored.usesEmojis, isFalse);
  });

  test('profile repository saves through its API client abstraction', () async {
    final repository = ApiCommunicationProfileRepository(
      MockCommunicationProfileApiClient(),
    );
    const updated = CommunicationProfile(
      preferredName: 'Mira',
      relationshipIntention: RelationshipIntention.serious,
      communicationTone: CommunicationTone.calm,
      messageLength: MessageLength.medium,
      usesEmojis: true,
    );

    await repository.save(updated);
    final fetched = await repository.fetch();

    expect(fetched.preferredName, 'Mira');
    expect(fetched.communicationTone, CommunicationTone.calm);
  });

  test('Riverpod profile provider exposes mock repository state', () async {
    final client = MockCommunicationProfileApiClient();
    final container = ProviderContainer(
      overrides: [
        communicationProfileApiClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);

    final initial = await container.read(communicationProfileProvider.future);
    expect(initial.relationshipIntention, RelationshipIntention.unsure);

    final saved = await container
        .read(communicationProfileProvider.notifier)
        .save(initial.copyWith(preferredName: 'Dev'));

    expect(saved, isTrue);
    expect(
      container.read(communicationProfileProvider).value?.preferredName,
      'Dev',
    );
  });

  test('conversation DTO parses a backend-shaped summary', () {
    final dto = ConversationSummaryDto.fromJson({
      'id': 'conversation-1',
      'title': 'Synthetic chat',
      'participant_name': 'Sam',
      'message_count': 4,
      'updated_at': '2026-07-14T09:30:00Z',
    });

    expect(dto.toDomain().participantName, 'Sam');
    expect(dto.toDomain().messageCount, 4);
    expect(dto.toJson()['updated_at'], '2026-07-14T09:30:00.000Z');
  });

  test('conversation provider deletes from the mock client', () async {
    final client = MockConversationApiClient();
    final container = ProviderContainer(
      overrides: [conversationApiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final initial = await container.read(conversationListProvider.future);
    expect(initial, hasLength(2));

    final deleted = await container
        .read(conversationListProvider.notifier)
        .deleteConversation(initial.first.id);

    expect(deleted, isTrue);
    expect(container.read(conversationListProvider).value, hasLength(1));
  });
}
