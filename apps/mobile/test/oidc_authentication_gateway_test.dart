import 'package:convo_coach/features/authentication/data/oidc_authentication_gateway.dart';
import 'package:convo_coach/features/authentication/domain/authentication_contracts.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _accessTokenKey = 'convocoach.oidc.access-token';
const _refreshTokenKey = 'convocoach.oidc.refresh-token';
const _accessTokenExpiryKey = 'convocoach.oidc.access-token-expiry';
const _idTokenKey = 'convocoach.oidc.id-token';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      _accessTokenKey: 'expired-access',
      _refreshTokenKey: 'refresh-original',
      _accessTokenExpiryKey: DateTime.utc(2020).toIso8601String(),
      _idTokenKey: 'id-original',
    });
  });

  test('concurrent access requests perform one rotating refresh', () async {
    final appAuth = _FakeAppAuth(
      tokenHandler: (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _tokenResponse();
      },
    );
    final gateway = _gateway(appAuth);

    final tokens = await Future.wait([
      gateway.accessToken(),
      gateway.accessToken(),
      gateway.accessToken(),
    ]);

    expect(tokens, everyElement('access-new'));
    expect(appAuth.tokenCalls, 1);
    expect(
      await const FlutterSecureStorage().read(key: _refreshTokenKey),
      'refresh-new',
    );
  });

  test('temporary refresh failure keeps the recoverable session', () async {
    final gateway = _gateway(
      _FakeAppAuth(
        tokenHandler: (_) => Future<TokenResponse>.error(
          _platformError('temporarily_unavailable'),
        ),
      ),
    );

    final session = await gateway.watchSession().first;

    expect(session.isAuthenticated, isTrue);
    expect(
      await const FlutterSecureStorage().read(key: _refreshTokenKey),
      'refresh-original',
    );
  });

  test('invalid grant expires and clears the protected session', () async {
    final gateway = _gateway(
      _FakeAppAuth(
        tokenHandler: (_) => Future<TokenResponse>.error(
          _platformError(FlutterAppAuthOAuthError.invalidGrant),
        ),
      ),
    );

    final session = await gateway.watchSession().first;

    expect(session.isAuthenticated, isFalse);
    expect(
      await const FlutterSecureStorage().read(key: _refreshTokenKey),
      isNull,
    );
  });

  test('incomplete account switch preserves the existing session', () async {
    FlutterSecureStorage.setMockInitialValues({
      _accessTokenKey: 'existing-access',
      _refreshTokenKey: 'existing-refresh',
      _accessTokenExpiryKey: DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      _idTokenKey: 'existing-id',
    });
    final gateway = _gateway(
      _FakeAppAuth(
        tokenHandler: (_) async => _tokenResponse(),
        authorizeHandler: (_) async => AuthorizationTokenResponse(
          'new-access',
          null,
          DateTime.now().toUtc().add(const Duration(hours: 1)),
          'new-id',
          'Bearer',
          const ['openid'],
          const {},
          const {},
        ),
      ),
    );

    final result = await gateway.signIn(MobileAuthenticationMethod.oidc);

    expect(
      (result as MobileAuthenticationRejected).code,
      'authentication_session_incomplete',
    );
    expect(
      await const FlutterSecureStorage().read(key: _accessTokenKey),
      'existing-access',
    );
    expect(
      await const FlutterSecureStorage().read(key: _refreshTokenKey),
      'existing-refresh',
    );
  });

  test(
    'interactive provider errors expose only a stable safe category',
    () async {
      final gateway = _gateway(
        _FakeAppAuth(
          tokenHandler: (_) async => _tokenResponse(),
          authorizeHandler: (_) => Future<AuthorizationTokenResponse>.error(
            _platformError(FlutterAppAuthOAuthError.invalidClient),
          ),
        ),
      );

      final result = await gateway.signIn(MobileAuthenticationMethod.oidc);

      expect(
        (result as MobileAuthenticationRejected).code,
        'authentication_configuration_invalid',
      );
    },
  );
}

OidcAuthenticationGateway _gateway(FlutterAppAuth appAuth) {
  return OidcAuthenticationGateway(
    configuration: OidcAuthenticationConfiguration(
      discoveryUrl:
          'https://convocoach.jp.auth0.com/.well-known/openid-configuration',
      clientId: 'mobile-client',
      audience: 'convocoach-api',
      redirectUrl: 'com.convocoach.convo-coach:/oauthredirect',
      postLogoutRedirectUrl: 'com.convocoach.convo-coach:/logout',
      scopes: const ['openid', 'profile', 'email', 'offline_access'],
    ),
    appAuth: appAuth,
    storage: const FlutterSecureStorage(),
  );
}

TokenResponse _tokenResponse() => TokenResponse(
  'access-new',
  'refresh-new',
  DateTime.now().toUtc().add(const Duration(hours: 1)),
  'id-new',
  'Bearer',
  const ['openid', 'offline_access'],
  const {},
);

FlutterAppAuthPlatformException _platformError(String error) {
  return FlutterAppAuthPlatformException(
    code: 'synthetic',
    platformErrorDetails: FlutterAppAuthPlatformErrorDetails(error: error),
  );
}

final class _FakeAppAuth extends FlutterAppAuth {
  _FakeAppAuth({required this.tokenHandler, this.authorizeHandler});

  final Future<TokenResponse> Function(TokenRequest request) tokenHandler;
  final Future<AuthorizationTokenResponse> Function(
    AuthorizationTokenRequest request,
  )?
  authorizeHandler;
  int tokenCalls = 0;

  @override
  Future<AuthorizationTokenResponse> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  ) {
    final handler = authorizeHandler;
    if (handler == null) {
      return Future<AuthorizationTokenResponse>.error(
        StateError('authorize_not_configured'),
      );
    }
    return handler(request);
  }

  @override
  Future<TokenResponse> token(TokenRequest request) {
    tokenCalls += 1;
    return tokenHandler(request);
  }
}
