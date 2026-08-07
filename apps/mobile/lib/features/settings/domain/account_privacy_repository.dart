abstract interface class AccountPrivacyRepository {
  /// Requests deletion of the authenticated account and all owner-scoped data.
  Future<void> requestAccountDeletion();
}

class PreviewAccountPrivacyRepository implements AccountPrivacyRepository {
  const PreviewAccountPrivacyRepository();

  @override
  Future<void> requestAccountDeletion() async {}
}
