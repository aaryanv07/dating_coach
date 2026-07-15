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
    return (await _apiClient.fetchProfile()).toDomain();
  }

  @override
  Future<CommunicationProfile> save(CommunicationProfile profile) async {
    final dto = CommunicationProfileDto.fromDomain(profile);
    return (await _apiClient.updateProfile(dto)).toDomain();
  }
}
