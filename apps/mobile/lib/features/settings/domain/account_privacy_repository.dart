abstract interface class AccountPrivacyRepository {
  /// Returns a versioned, owner-scoped JSON export for explicit user sharing.
  Future<String> exportAccountData();

  /// Requests deletion of the authenticated account and all owner-scoped data.
  Future<void> requestAccountDeletion();
}

class PreviewAccountPrivacyRepository implements AccountPrivacyRepository {
  const PreviewAccountPrivacyRepository();

  @override
  Future<String> exportAccountData() async =>
      '{"schema_version":"account-export.v1","data":{}}';

  @override
  Future<void> requestAccountDeletion() async {}
}
