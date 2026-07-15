import 'package:convo_coach/features/communication_profile/data/communication_profile_dto.dart';

abstract interface class CommunicationProfileApiClient {
  Future<CommunicationProfileDto> fetchProfile();

  Future<CommunicationProfileDto> updateProfile(
    CommunicationProfileDto profile,
  );
}

class MockCommunicationProfileApiClient
    implements CommunicationProfileApiClient {
  MockCommunicationProfileApiClient({
    CommunicationProfileDto? initialProfile,
    this.latency = Duration.zero,
  }) : _profile =
           initialProfile ??
           CommunicationProfileDto.fromJson(const <String, Object?>{});

  CommunicationProfileDto _profile;
  final Duration latency;

  @override
  Future<CommunicationProfileDto> fetchProfile() async {
    await Future<void>.delayed(latency);
    return CommunicationProfileDto.fromJson(_profile.toJson());
  }

  @override
  Future<CommunicationProfileDto> updateProfile(
    CommunicationProfileDto profile,
  ) async {
    await Future<void>.delayed(latency);
    _profile = CommunicationProfileDto.fromJson(profile.toJson());
    return _profile;
  }
}
