import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/features/authentication/domain/authentication_contracts.dart';
import 'package:convo_coach/features/authentication/data/oidc_authentication_gateway.dart';
import 'package:convo_coach/features/authentication/presentation/authentication_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 14 mobile authentication boundary', () {
    test('session contract exposes no credential field', () {
      const session = MobileAuthenticationSession(
        lifecycle: MobileAuthenticationLifecycle.authenticated,
        method: MobileAuthenticationMethod.apple,
        opaqueAccountReference: 'opaque-account-reference',
      );

      expect(session.isAuthenticated, isTrue);
      expect(session.opaqueAccountReference, 'opaque-account-reference');
      expect(session.toString(), isNot(contains('token')));
      expect(session.toString(), isNot(contains('credential')));
    });

    test('release build requires configured OIDC without an embedded token', () {
      const configuration = MobileRuntimeConfiguration(
        name: 'ConvoCoach',
        environment: 'production',
        mockMode: false,
        conversationCoachPreviewEnabled: false,
        authenticationMode: 'oidc',
        apiBaseUrl: 'https://api.example.invalid',
        apiAccessToken: '',
        oidcDiscoveryUrl:
            'https://identity.example.invalid/.well-known/openid-configuration',
        oidcClientId: 'convocoach-mobile',
        oidcAudience: 'convocoach-api',
        oidcRedirectUrl: 'com.convocoach.convo-coach:/oauthredirect',
        oidcPostLogoutRedirectUrl: 'com.convocoach.convo-coach:/logout',
        oidcGoogleConnection: 'google-oauth2',
        oidcAppleConnection: 'apple',
        oidcDatabaseConnection: 'Username-Password-Authentication',
        billingMode: 'store',
        appleMonthlyProductId: 'com.convocoach.plus.monthly.ios',
        appleYearlyProductId: 'com.convocoach.plus.yearly.ios',
        googleMonthlyProductId: 'com.convocoach.plus.monthly.android',
        googleYearlyProductId: 'com.convocoach.plus.yearly.android',
      );

      expect(configuration.validationFailures(releaseMode: true), isEmpty);
      expect(configuration.previewAuthenticationEnabled, isFalse);
      expect(configuration.oidcAuthenticationEnabled, isTrue);
      expect(configuration.googleSignInEnabled, isTrue);
      expect(configuration.appleSignInEnabled, isTrue);
      expect(configuration.emailPasswordSignInEnabled, isTrue);
    });

    test('release refuses Google sign-in without the Apple alternative', () {
      const configuration = MobileRuntimeConfiguration(
        name: 'ConvoCoach',
        environment: 'production',
        mockMode: false,
        conversationCoachPreviewEnabled: false,
        authenticationMode: 'oidc',
        apiBaseUrl: 'https://api.example.invalid',
        apiAccessToken: '',
        oidcDiscoveryUrl:
            'https://identity.example.invalid/.well-known/openid-configuration',
        oidcClientId: 'convocoach-mobile',
        oidcAudience: 'convocoach-api',
        oidcRedirectUrl: 'com.convocoach.convo-coach:/oauthredirect',
        oidcPostLogoutRedirectUrl: 'com.convocoach.convo-coach:/logout',
        oidcGoogleConnection: 'google-oauth2',
      );

      expect(
        configuration.validationFailures(releaseMode: true),
        contains('release_apple_sign_in_missing'),
      );
    });

    test('OIDC connection routing is bounded and immutable', () {
      final configuration = OidcAuthenticationConfiguration(
        discoveryUrl:
            'https://identity.example.invalid/.well-known/openid-configuration',
        clientId: 'convocoach-mobile',
        audience: 'convocoach-api',
        redirectUrl: 'com.convocoach.convo-coach:/oauthredirect',
        postLogoutRedirectUrl: 'com.convocoach.convo-coach:/logout',
        scopes: const ['openid', 'profile', 'email'],
        authorizationParameters: const {
          MobileAuthenticationMethod.google: {'connection': 'google-oauth2'},
          MobileAuthenticationMethod.apple: {'connection': 'apple'},
          MobileAuthenticationMethod.emailPassword: {
            'connection': 'Username-Password-Authentication',
            'prompt': 'login',
          },
          MobileAuthenticationMethod.emailSignup: {
            'connection': 'Username-Password-Authentication',
            'screen_hint': 'signup',
          },
        },
      );

      expect(configuration.supports(MobileAuthenticationMethod.google), isTrue);
      expect(configuration.supports(MobileAuthenticationMethod.apple), isTrue);
      expect(
        configuration.supports(MobileAuthenticationMethod.emailPassword),
        isTrue,
      );
      expect(
        configuration.supports(MobileAuthenticationMethod.emailSignup),
        isTrue,
      );
      expect(
        configuration.supports(MobileAuthenticationMethod.emailLink),
        isFalse,
      );
      expect(configuration.parametersFor(MobileAuthenticationMethod.google), {
        'audience': 'convocoach-api',
        'connection': 'google-oauth2',
      });
      expect(
        () => configuration
            .parametersFor(MobileAuthenticationMethod.google)
            .clear(),
        throwsUnsupportedError,
      );
      final emailRequest = configuration.requestParametersFor(
        MobileAuthenticationMethod.emailPassword,
      );
      expect(emailRequest.promptValues, ['login']);
      expect(emailRequest.additionalParameters, {
        'audience': 'convocoach-api',
        'connection': 'Username-Password-Authentication',
      });
      expect(emailRequest.additionalParameters, isNot(contains('prompt')));
    });

    test('release build rejects the unavailable placeholder', () {
      const configuration = MobileRuntimeConfiguration(
        name: 'ConvoCoach',
        environment: 'production',
        mockMode: false,
        conversationCoachPreviewEnabled: false,
        authenticationMode: 'unavailable',
        apiBaseUrl: 'https://api.example.invalid',
        apiAccessToken: '',
      );

      expect(
        configuration.validationFailures(releaseMode: true),
        contains('release_authentication_mode_unsafe'),
      );
    });

    test('release build rejects mock authentication', () {
      const configuration = MobileRuntimeConfiguration(
        name: 'ConvoCoach',
        environment: 'production',
        mockMode: false,
        conversationCoachPreviewEnabled: false,
        authenticationMode: 'mock',
        apiBaseUrl: 'https://api.example.invalid',
        apiAccessToken: '',
      );

      expect(
        configuration.validationFailures(releaseMode: true),
        contains('release_authentication_mode_unsafe'),
      );
    });

    test('debug preview is available only with both mock controls', () {
      const enabled = MobileRuntimeConfiguration(
        name: 'ConvoCoach',
        environment: 'local',
        mockMode: true,
        conversationCoachPreviewEnabled: false,
        authenticationMode: 'mock',
        apiBaseUrl: '',
        apiAccessToken: '',
      );
      const disabled = MobileRuntimeConfiguration(
        name: 'ConvoCoach',
        environment: 'local',
        mockMode: false,
        conversationCoachPreviewEnabled: false,
        authenticationMode: 'mock',
        apiBaseUrl: '',
        apiAccessToken: '',
      );

      expect(enabled.previewAuthenticationEnabled, isTrue);
      expect(disabled.previewAuthenticationEnabled, isFalse);
    });

    testWidgets('unavailable boundary exposes no preview sign-in action', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AuthenticationScreen(previewAuthenticationEnabled: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Secure sign-in is not available yet.'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Continue with email'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
