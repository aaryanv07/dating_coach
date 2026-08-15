import 'dart:async';

import 'package:convo_coach/features/authentication/domain/authentication_contracts.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _accessTokenKey = 'convocoach.oidc.access-token';
const _refreshTokenKey = 'convocoach.oidc.refresh-token';
const _accessTokenExpiryKey = 'convocoach.oidc.access-token-expiry';
const _idTokenKey = 'convocoach.oidc.id-token';

final class OidcAuthenticationConfiguration {
  OidcAuthenticationConfiguration({
    required this.discoveryUrl,
    required this.clientId,
    required this.audience,
    required this.redirectUrl,
    required this.postLogoutRedirectUrl,
    required Iterable<String> scopes,
    Map<MobileAuthenticationMethod, Map<String, String>>
        authorizationParameters =
        const {},
  }) : scopes = List.unmodifiable(scopes),
       authorizationParameters = Map.unmodifiable({
         for (final entry in authorizationParameters.entries)
           entry.key: Map<String, String>.unmodifiable(entry.value),
       });

  final String discoveryUrl;
  final String clientId;
  final String audience;
  final String redirectUrl;
  final String postLogoutRedirectUrl;
  final List<String> scopes;
  final Map<MobileAuthenticationMethod, Map<String, String>>
  authorizationParameters;

  bool supports(MobileAuthenticationMethod method) =>
      method == MobileAuthenticationMethod.oidc ||
      authorizationParameters.containsKey(method);

  Map<String, String> parametersFor(MobileAuthenticationMethod method) =>
      Map.unmodifiable({
        'audience': audience,
        ...?authorizationParameters[method],
      });

  OidcAuthorizationRequestParameters requestParametersFor(
    MobileAuthenticationMethod method,
  ) {
    final additionalParameters = Map<String, String>.of(parametersFor(method));
    final prompt = additionalParameters.remove('prompt');
    return OidcAuthorizationRequestParameters(
      additionalParameters: Map.unmodifiable(additionalParameters),
      promptValues: prompt == null || prompt.isEmpty
          ? null
          : List.unmodifiable([prompt]),
    );
  }
}

final class OidcAuthorizationRequestParameters {
  const OidcAuthorizationRequestParameters({
    required this.additionalParameters,
    required this.promptValues,
  });

  final Map<String, String> additionalParameters;
  final List<String>? promptValues;
}

final class OidcAuthenticationGateway
    implements MobileAuthenticationGateway, MobileAccessTokenProvider {
  OidcAuthenticationGateway({
    required this.configuration,
    FlutterAppAuth? appAuth,
    FlutterSecureStorage? storage,
  }) : _appAuth = appAuth ?? const FlutterAppAuth(),
       _storage = storage ?? const FlutterSecureStorage();

  final OidcAuthenticationConfiguration configuration;
  final FlutterAppAuth _appAuth;
  final FlutterSecureStorage _storage;
  final StreamController<MobileAuthenticationSession> _sessions =
      StreamController.broadcast();
  Future<String?>? _accessTokenOperation;

  @override
  Stream<MobileAuthenticationSession> watchSession() async* {
    yield await _restoredSession();
    yield* _sessions.stream;
  }

  @override
  Future<MobileAuthenticationResult> signIn(
    MobileAuthenticationMethod method,
  ) async {
    if (!configuration.supports(method)) {
      return const MobileAuthenticationRejected(
        'authentication_method_unsupported',
      );
    }
    final requestParameters = configuration.requestParametersFor(method);
    _sessions.add(
      MobileAuthenticationSession(
        lifecycle: MobileAuthenticationLifecycle.authenticating,
        method: method,
      ),
    );
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          configuration.clientId,
          configuration.redirectUrl,
          discoveryUrl: configuration.discoveryUrl,
          scopes: configuration.scopes,
          promptValues: requestParameters.promptValues,
          additionalParameters: requestParameters.additionalParameters,
          externalUserAgent: ExternalUserAgent.asWebAuthenticationSession,
        ),
      );
      if (result.accessToken == null ||
          result.refreshToken == null ||
          result.refreshToken!.isEmpty ||
          result.idToken == null ||
          result.idToken!.isEmpty ||
          result.accessTokenExpirationDateTime == null) {
        return _rejectPreservingStoredSession(
          'authentication_session_incomplete',
        );
      }
      await _storeTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken,
        idToken: result.idToken,
        accessTokenExpirationDateTime: result.accessTokenExpirationDateTime,
      );
      final session = MobileAuthenticationSession(
        lifecycle: MobileAuthenticationLifecycle.authenticated,
        method: method,
        opaqueAccountReference: 'current-account',
      );
      _sessions.add(session);
      return MobileAuthenticationSucceeded(session);
    } on FlutterAppAuthUserCancelledException {
      return _rejectPreservingStoredSession('authentication_cancelled');
    } on FlutterAppAuthPlatformException catch (error) {
      return _rejectPreservingStoredSession(
        _safeInteractiveFailureCode(error.platformErrorDetails.error),
      );
    } on Object {
      // A failed account switch or provider outage must not destroy a valid
      // session that was already protected on this device.
      return _rejectPreservingStoredSession('authentication_failed');
    }
  }

  @override
  Future<String?> accessToken() async {
    final inFlight = _accessTokenOperation;
    if (inFlight != null) return inFlight;
    final operation = _resolveAccessToken();
    _accessTokenOperation = operation;
    try {
      return await operation;
    } finally {
      if (identical(_accessTokenOperation, operation)) {
        _accessTokenOperation = null;
      }
    }
  }

  Future<String?> _resolveAccessToken() async {
    final token = await _storage.read(key: _accessTokenKey);
    final expiryText = await _storage.read(key: _accessTokenExpiryKey);
    final expiry = expiryText == null
        ? null
        : DateTime.tryParse(expiryText)?.toUtc();
    if (token != null &&
        token.isNotEmpty &&
        expiry != null &&
        expiry.isAfter(
          DateTime.now().toUtc().add(const Duration(minutes: 1)),
        )) {
      return token;
    }
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      await _clearTokens();
      _sessions.add(const MobileAuthenticationSession.signedOut());
      return null;
    }
    try {
      final result = await _appAuth.token(
        TokenRequest(
          configuration.clientId,
          configuration.redirectUrl,
          refreshToken: refreshToken,
          discoveryUrl: configuration.discoveryUrl,
          scopes: configuration.scopes,
        ),
      );
      if (result.accessToken == null) {
        return null;
      }
      await _storeTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken ?? refreshToken,
        idToken: result.idToken ?? await _storage.read(key: _idTokenKey),
        accessTokenExpirationDateTime: result.accessTokenExpirationDateTime,
      );
      return result.accessToken;
    } on FlutterAppAuthPlatformException catch (error) {
      if (_isTerminalRefreshFailure(error)) {
        await _expireSession();
      }
      return null;
    } on Object {
      // Keep protected credentials on temporary connectivity, discovery, and
      // provider failures so a later request can recover without another login.
      return null;
    }
  }

  bool _isTerminalRefreshFailure(FlutterAppAuthPlatformException error) =>
      error.platformErrorDetails.error == FlutterAppAuthOAuthError.invalidGrant;

  String _safeInteractiveFailureCode(String? error) => switch (error) {
    'access_denied' => 'authentication_access_denied',
    FlutterAppAuthOAuthError.invalidRequest ||
    FlutterAppAuthOAuthError.invalidClient ||
    FlutterAppAuthOAuthError.unauthorizedClient ||
    FlutterAppAuthOAuthError.invalidScope =>
      'authentication_configuration_invalid',
    'server_error' ||
    'temporarily_unavailable' => 'authentication_provider_unavailable',
    _ => 'authentication_failed',
  };

  Future<void> _expireSession() async {
    await _clearTokens();
    _sessions.add(
      const MobileAuthenticationSession(
        lifecycle: MobileAuthenticationLifecycle.expired,
        method: MobileAuthenticationMethod.oidc,
      ),
    );
  }

  @override
  Future<void> signOut() async {
    final idToken = await _storage.read(key: _idTokenKey);
    try {
      if (idToken != null && idToken.isNotEmpty) {
        await _appAuth.endSession(
          EndSessionRequest(
            idTokenHint: idToken,
            postLogoutRedirectUrl: configuration.postLogoutRedirectUrl,
            discoveryUrl: configuration.discoveryUrl,
            externalUserAgent: ExternalUserAgent.asWebAuthenticationSession,
          ),
        );
      }
    } on Object {
      // Local credentials are still removed if the identity provider is down.
    } finally {
      await _clearTokens();
      _sessions.add(const MobileAuthenticationSession.signedOut());
    }
  }

  Future<MobileAuthenticationSession> _restoredSession() async {
    final token = await accessToken();
    if (token != null) {
      return const MobileAuthenticationSession(
        lifecycle: MobileAuthenticationLifecycle.authenticated,
        method: MobileAuthenticationMethod.oidc,
        opaqueAccountReference: 'current-account',
      );
    }
    final recoverableCredential = await _storage.read(key: _refreshTokenKey);
    return recoverableCredential != null && recoverableCredential.isNotEmpty
        ? const MobileAuthenticationSession(
            lifecycle: MobileAuthenticationLifecycle.authenticated,
            method: MobileAuthenticationMethod.oidc,
            opaqueAccountReference: 'current-account',
          )
        : const MobileAuthenticationSession.signedOut();
  }

  Future<MobileAuthenticationRejected> _rejectPreservingStoredSession(
    String code,
  ) async {
    _sessions.add(await _restoredSession());
    return MobileAuthenticationRejected(code);
  }

  Future<void> _storeTokens({
    required String accessToken,
    required String? refreshToken,
    required String? idToken,
    required DateTime? accessTokenExpirationDateTime,
  }) async {
    final expiry = accessTokenExpirationDateTime?.toUtc();
    if (expiry == null) throw StateError('token_expiry_missing');
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(
      key: _accessTokenExpiryKey,
      value: expiry.toIso8601String(),
    );
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
    if (idToken != null) {
      await _storage.write(key: _idTokenKey, value: idToken);
    }
  }

  Future<void> _clearTokens() async {
    for (final key in const [
      _accessTokenKey,
      _refreshTokenKey,
      _accessTokenExpiryKey,
      _idTokenKey,
    ]) {
      await _storage.delete(key: key);
    }
  }
}
