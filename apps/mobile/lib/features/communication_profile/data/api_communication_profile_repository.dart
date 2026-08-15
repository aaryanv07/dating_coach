import 'dart:typed_data';

import 'package:convo_coach/features/communication_profile/data/communication_profile_api_client.dart';
import 'package:convo_coach/features/communication_profile/data/communication_profile_dto.dart';
import 'package:convo_coach/features/communication_profile/domain/communication_profile.dart';
import 'package:convo_coach/features/communication_profile/domain/communication_profile_repository.dart';

class ApiCommunicationProfileRepository
    implements CommunicationProfileRepository {
  const ApiCommunicationProfileRepository(this._apiClient);

  final CommunicationProfileApiClient _apiClient;

  @override
  Future<CommunicationProfile> fetch() async {
    final dto = await _apiClient.fetchProfile();
    List<int>? photo;
    if (dto.hasProfilePhoto) {
      try {
        photo = await _apiClient.fetchProfilePhoto();
      } on Object {
        // An optional photo failure must not hide valid text profile fields.
        photo = null;
      }
    }
    return dto.toDomain(profilePhotoBytes: photo);
  }

  @override
  Future<CommunicationProfile> save(CommunicationProfile profile) async {
    final dto = CommunicationProfileDto.fromDomain(profile);
    return (await _apiClient.updateProfile(
      dto,
    )).toDomain(profilePhotoBytes: profile.profilePhotoBytes);
  }

  @override
  Future<CommunicationProfile> updatePhoto(
    CommunicationProfile profile,
    List<int> bytes,
    String contentType,
  ) async {
    await _apiClient.updateProfilePhoto(bytes, contentType);
    return profile.copyWith(profilePhotoBytes: Uint8List.fromList(bytes));
  }

  @override
  Future<CommunicationProfile> deletePhoto(CommunicationProfile profile) async {
    await _apiClient.deleteProfilePhoto();
    return profile.copyWith(clearProfilePhoto: true);
  }
}
