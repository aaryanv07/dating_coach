import 'package:convo_coach/features/communication_profile/domain/communication_profile.dart';

abstract interface class CommunicationProfileRepository {
  Future<CommunicationProfile> fetch();

  Future<CommunicationProfile> save(CommunicationProfile profile);
}
