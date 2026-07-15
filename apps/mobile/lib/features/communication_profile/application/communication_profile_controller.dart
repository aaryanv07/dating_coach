import 'package:convo_coach/features/communication_profile/data/api_communication_profile_repository.dart';
import 'package:convo_coach/features/communication_profile/data/communication_profile_api_client.dart';
import 'package:convo_coach/features/communication_profile/domain/communication_profile.dart';
import 'package:convo_coach/features/communication_profile/domain/communication_profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final communicationProfileApiClientProvider =
    Provider<CommunicationProfileApiClient>(
      (ref) => MockCommunicationProfileApiClient(),
    );

final communicationProfileRepositoryProvider =
    Provider<CommunicationProfileRepository>((ref) {
      return ApiCommunicationProfileRepository(
        ref.watch(communicationProfileApiClientProvider),
      );
    });

class CommunicationProfileController
    extends AsyncNotifier<CommunicationProfile> {
  @override
  Future<CommunicationProfile> build() {
    return ref.watch(communicationProfileRepositoryProvider).fetch();
  }

  Future<bool> save(CommunicationProfile profile) async {
    state = await AsyncValue.guard(
      () => ref.read(communicationProfileRepositoryProvider).save(profile),
    );
    return !state.hasError;
  }
}

final communicationProfileProvider =
    AsyncNotifierProvider<CommunicationProfileController, CommunicationProfile>(
      CommunicationProfileController.new,
    );
