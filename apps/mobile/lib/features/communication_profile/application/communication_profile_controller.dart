import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/features/authentication/application/authentication_providers.dart';
import 'package:convo_coach/features/communication_profile/data/api_communication_profile_repository.dart';
import 'package:convo_coach/features/communication_profile/data/communication_profile_api_client.dart';
import 'package:convo_coach/features/communication_profile/data/http_communication_profile_api_client.dart';
import 'package:convo_coach/features/communication_profile/domain/communication_profile.dart';
import 'package:convo_coach/features/communication_profile/domain/communication_profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final communicationProfileApiClientProvider =
    Provider<CommunicationProfileApiClient>((ref) {
      final baseUri = Uri.tryParse(AppConfig.apiBaseUrl);
      if (AppConfig.runtime.authenticatedApiConfigured &&
          baseUri != null &&
          baseUri.hasScheme &&
          baseUri.hasAuthority) {
        final tokens = ref.watch(authenticationAccessTokenProvider);
        return HttpCommunicationProfileApiClient(
          baseUri: baseUri,
          accessTokenProvider: tokens.accessToken,
        );
      }
      return MockCommunicationProfileApiClient();
    });

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

  Future<bool> updatePhoto(List<int> bytes, String contentType) async {
    final current = switch (state) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (current == null) return false;
    state = await AsyncValue.guard(
      () => ref
          .read(communicationProfileRepositoryProvider)
          .updatePhoto(current, bytes, contentType),
    );
    return !state.hasError;
  }

  Future<bool> deletePhoto() async {
    final current = switch (state) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (current == null) return false;
    state = await AsyncValue.guard(
      () =>
          ref.read(communicationProfileRepositoryProvider).deletePhoto(current),
    );
    return !state.hasError;
  }
}

final communicationProfileProvider =
    AsyncNotifierProvider<CommunicationProfileController, CommunicationProfile>(
      CommunicationProfileController.new,
    );
