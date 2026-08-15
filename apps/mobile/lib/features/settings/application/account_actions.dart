import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/features/authentication/application/authentication_providers.dart';
import 'package:convo_coach/features/authentication/domain/authentication_contracts.dart';
import 'package:convo_coach/features/progress/application/progress_dashboard_controller.dart';
import 'package:convo_coach/features/progress/domain/progress_journal_repository.dart';
import 'package:convo_coach/features/settings/data/http_account_privacy_repository.dart';
import 'package:convo_coach/features/settings/domain/account_privacy_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final accountPrivacyRepositoryProvider = Provider<AccountPrivacyRepository>((
  ref,
) {
  final baseUri = Uri.tryParse(AppConfig.apiBaseUrl);
  if (AppConfig.runtime.authenticatedApiConfigured &&
      baseUri != null &&
      baseUri.hasScheme &&
      baseUri.hasAuthority) {
    return HttpAccountPrivacyRepository(
      baseUri: baseUri,
      accessTokenProvider: ref
          .watch(authenticationAccessTokenProvider)
          .accessToken,
    );
  }
  return const PreviewAccountPrivacyRepository();
});

class AccountActions {
  const AccountActions({
    required this.authentication,
    required this.progressJournal,
    required this.accountPrivacy,
  });

  final MobileAuthenticationGateway authentication;
  final ProgressJournalRepository progressJournal;
  final AccountPrivacyRepository accountPrivacy;

  Future<bool> signOut() async {
    try {
      await progressJournal.clear();
      await authentication.signOut();
      return true;
    } on Object {
      return false;
    }
  }

  Future<String?> exportAccount() async {
    try {
      return await accountPrivacy.exportAccountData();
    } on Object {
      return null;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      await accountPrivacy.requestAccountDeletion();
      await progressJournal.clear();
      await authentication.signOut();
      return true;
    } on Object {
      return false;
    }
  }
}

final accountActionsProvider = Provider<AccountActions>((ref) {
  return AccountActions(
    authentication: ref.watch(authenticationGatewayProvider),
    progressJournal: ref.watch(progressJournalRepositoryProvider),
    accountPrivacy: ref.watch(accountPrivacyRepositoryProvider),
  );
});
