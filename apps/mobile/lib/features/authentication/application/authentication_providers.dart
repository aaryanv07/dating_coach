import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/features/authentication/data/oidc_authentication_gateway.dart';
import 'package:convo_coach/features/authentication/domain/authentication_contracts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authenticationGatewayProvider = Provider<MobileAuthenticationGateway>((
  ref,
) {
  if (AppConfig.runtime.oidcAuthenticationEnabled) {
    return OidcAuthenticationGateway(
      configuration: OidcAuthenticationConfiguration(
        discoveryUrl: AppConfig.oidcDiscoveryUrl,
        clientId: AppConfig.oidcClientId,
        audience: AppConfig.oidcAudience,
        redirectUrl: AppConfig.oidcRedirectUrl,
        postLogoutRedirectUrl: AppConfig.oidcPostLogoutRedirectUrl,
        scopes: AppConfig.runtime.parsedOidcScopes,
        authorizationParameters: {
          if (AppConfig.runtime.googleSignInEnabled)
            MobileAuthenticationMethod.google: {
              AppConfig.oidcProviderParameter: AppConfig.oidcGoogleConnection,
            },
          if (AppConfig.runtime.appleSignInEnabled)
            MobileAuthenticationMethod.apple: {
              AppConfig.oidcProviderParameter: AppConfig.oidcAppleConnection,
            },
        },
      ),
    );
  }
  return const UnavailableAuthenticationGateway();
});

final authenticationAccessTokenProvider = Provider<MobileAccessTokenProvider>((
  ref,
) {
  if (AppConfig.runtime.previewAuthenticationEnabled &&
      AppConfig.apiAccessToken.isNotEmpty) {
    return const DevelopmentAccessTokenProvider(AppConfig.apiAccessToken);
  }
  final gateway = ref.watch(authenticationGatewayProvider);
  if (gateway is MobileAccessTokenProvider) {
    return gateway as MobileAccessTokenProvider;
  }
  return const UnavailableAccessTokenProvider();
});

final authenticationSessionProvider =
    StreamProvider<MobileAuthenticationSession>(
      (ref) => ref.watch(authenticationGatewayProvider).watchSession(),
    );

final class DevelopmentAccessTokenProvider
    implements MobileAccessTokenProvider {
  const DevelopmentAccessTokenProvider(this._token);

  final String _token;

  @override
  Future<String?> accessToken() async => _token;
}

final class UnavailableAccessTokenProvider
    implements MobileAccessTokenProvider {
  const UnavailableAccessTokenProvider();

  @override
  Future<String?> accessToken() async => null;
}

final class UnavailableAuthenticationGateway
    implements MobileAuthenticationGateway {
  const UnavailableAuthenticationGateway();

  @override
  Future<MobileAuthenticationResult> signIn(
    MobileAuthenticationMethod method,
  ) async => const MobileAuthenticationRejected('authentication_unavailable');

  @override
  Future<void> signOut() async {}

  @override
  Stream<MobileAuthenticationSession> watchSession() =>
      Stream.value(const MobileAuthenticationSession.unavailable());
}
