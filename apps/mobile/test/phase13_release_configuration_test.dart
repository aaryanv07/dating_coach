import 'package:convo_coach/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

const privateSentinel = 'phase-thirteen-private-mobile-token';

MobileRuntimeConfiguration productionConfiguration({
  String name = 'ConvoCoach',
  String environment = 'production',
  bool mockMode = false,
  bool conversationCoachPreviewEnabled = false,
  String authenticationMode = 'oidc',
  String apiBaseUrl = 'https://api.example.invalid',
  String apiAccessToken = '',
  String oidcDiscoveryUrl =
      'https://identity.example.invalid/.well-known/openid-configuration',
  String oidcClientId = 'convocoach-mobile',
  String oidcAudience = 'convocoach-api',
  String oidcRedirectUrl = 'com.convocoach.convo-coach:/oauthredirect',
  String oidcPostLogoutRedirectUrl = 'com.convocoach.convo-coach:/logout',
  String oidcGoogleConnection = 'google-oauth2',
  String oidcAppleConnection = 'apple',
  String appleMonthlyProductId = 'com.convocoach.plus.monthly',
  String appleYearlyProductId = 'com.convocoach.plus.yearly',
  String googleMonthlyProductId = 'com.convocoach.plus.monthly',
  String googleYearlyProductId = 'com.convocoach.plus.yearly',
}) {
  return MobileRuntimeConfiguration(
    name: name,
    environment: environment,
    mockMode: mockMode,
    conversationCoachPreviewEnabled: conversationCoachPreviewEnabled,
    authenticationMode: authenticationMode,
    apiBaseUrl: apiBaseUrl,
    apiAccessToken: apiAccessToken,
    oidcDiscoveryUrl: oidcDiscoveryUrl,
    oidcClientId: oidcClientId,
    oidcAudience: oidcAudience,
    oidcRedirectUrl: oidcRedirectUrl,
    oidcPostLogoutRedirectUrl: oidcPostLogoutRedirectUrl,
    oidcGoogleConnection: oidcGoogleConnection,
    oidcAppleConnection: oidcAppleConnection,
    billingMode: 'store',
    appleMonthlyProductId: appleMonthlyProductId,
    appleYearlyProductId: appleYearlyProductId,
    googleMonthlyProductId: googleMonthlyProductId,
    googleYearlyProductId: googleYearlyProductId,
  );
}

void main() {
  group('Phase 13 release configuration', () {
    test('accepts only the hardened production baseline', () {
      final configuration = productionConfiguration();

      expect(configuration.validationFailures(releaseMode: true), isEmpty);
      expect(() => configuration.validate(releaseMode: true), returnsNormally);
    });

    test('store product identifiers may be reused across store namespaces', () {
      final configuration = productionConfiguration();

      expect(
        configuration.validationFailures(releaseMode: true),
        isNot(contains('store_product_identifiers_invalid')),
      );
    });

    test('monthly and yearly products remain distinct inside each store', () {
      final configuration = productionConfiguration(
        appleYearlyProductId: 'com.convocoach.plus.monthly',
      );

      expect(
        configuration.validationFailures(releaseMode: true),
        contains('store_product_identifiers_invalid'),
      );
    });

    test('fails closed for mock, environment, URL, and token', () {
      final configuration = productionConfiguration(
        environment: 'local',
        mockMode: true,
        conversationCoachPreviewEnabled: true,
        authenticationMode: 'mock',
        apiBaseUrl: 'http://localhost:8000',
        apiAccessToken: privateSentinel,
      );

      expect(
        configuration.validationFailures(releaseMode: true),
        containsAll({
          'release_environment_not_production',
          'release_mock_mode_enabled',
          'release_authentication_mode_unsafe',
          'release_api_url_not_https',
          'release_embedded_access_token',
        }),
      );
    });

    test('configuration errors never disclose embedded token values', () {
      final configuration = productionConfiguration(
        apiAccessToken: privateSentinel,
      );

      Object? captured;
      try {
        configuration.validate(releaseMode: true);
      } on Object catch (error) {
        captured = error;
      }

      expect(captured, isA<MobileConfigurationError>());
      expect(captured.toString(), isNot(contains(privateSentinel)));
    });

    test('release URL cannot embed credentials, query, or fragment', () {
      final configuration = productionConfiguration(
        apiBaseUrl:
            'https://user:secret@api.example.invalid?token=value#private',
      );

      expect(
        configuration.validationFailures(releaseMode: true),
        contains('release_api_url_not_https'),
      );
    });

    test(
      'production OIDC requires safe discovery, client, redirect, and scopes',
      () {
        const configuration = MobileRuntimeConfiguration(
          name: 'ConvoCoach',
          environment: 'production',
          mockMode: false,
          conversationCoachPreviewEnabled: true,
          authenticationMode: 'oidc',
          apiBaseUrl: 'https://api.example.invalid',
          apiAccessToken: '',
          oidcDiscoveryUrl: 'http://identity.example.invalid/config',
          oidcClientId: '',
          oidcAudience: '',
          oidcRedirectUrl: 'https://attacker.example.invalid/callback',
          oidcPostLogoutRedirectUrl: 'https://attacker.example.invalid/logout',
          oidcScopes: 'profile,email',
        );

        expect(
          configuration.validationFailures(releaseMode: true),
          containsAll({
            'oidc_discovery_url_unsafe',
            'oidc_client_id_missing',
            'oidc_audience_invalid',
            'oidc_redirect_url_unsafe',
            'oidc_post_logout_redirect_url_unsafe',
            'oidc_openid_scope_missing',
          }),
        );
      },
    );

    test('debug startup keeps the local deterministic development flow', () {
      const configuration = MobileRuntimeConfiguration(
        name: 'ConvoCoach',
        environment: 'local',
        mockMode: true,
        conversationCoachPreviewEnabled: false,
        authenticationMode: 'mock',
        apiBaseUrl: '',
        apiAccessToken: '',
      );

      expect(configuration.validationFailures(releaseMode: false), isEmpty);
    });

    test('rejects malformed shared configuration in every build mode', () {
      const configuration = MobileRuntimeConfiguration(
        name: '',
        environment: 'unknown',
        mockMode: false,
        conversationCoachPreviewEnabled: false,
        authenticationMode: 'unavailable',
        apiBaseUrl: 'not a url',
        apiAccessToken: '',
      );

      expect(
        configuration.validationFailures(releaseMode: false),
        containsAll({
          'app_name_missing',
          'app_environment_unsupported',
          'api_base_url_invalid',
        }),
      );
    });
  });
}
