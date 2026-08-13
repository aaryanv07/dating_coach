import 'package:convo_coach/features/communication_profile/data/communication_profile_dto.dart';

abstract interface class CommunicationProfileApiClient {
  Future<CommunicationProfileDto> fetchProfile();

  Future<CommunicationProfileDto> updateProfile(
    CommunicationProfileDto profile,
  );

  Future<List<int>?> fetchProfilePhoto();

  Future<void> updateProfilePhoto(List<int> bytes, String contentType);

  Future<void> deleteProfilePhoto();
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
  List<int>? _photoBytes;

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

  @override
  Future<List<int>?> fetchProfilePhoto() async {
    await Future<void>.delayed(latency);
    return _photoBytes == null ? null : List<int>.from(_photoBytes!);
  }

  @override
  Future<void> updateProfilePhoto(List<int> bytes, String contentType) async {
    await Future<void>.delayed(latency);
    _photoBytes = List<int>.from(bytes);
  }

  @override
  Future<void> deleteProfilePhoto() async {
    await Future<void>.delayed(latency);
    _photoBytes = null;
  }
}
