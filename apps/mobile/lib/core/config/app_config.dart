enum MobileReleasePlatform { android, ios, all }

final class MobileRuntimeConfiguration {
  const MobileRuntimeConfiguration({
    required this.name,
    required this.environment,
    required this.mockMode,
    required this.conversationCoachPreviewEnabled,
    required this.authenticationMode,
    required this.apiBaseUrl,
    required this.apiAccessToken,
    this.oidcDiscoveryUrl = '',
    this.oidcClientId = '',
    this.oidcAudience = '',
    this.oidcRedirectUrl = '',
    this.oidcPostLogoutRedirectUrl = '',
    this.oidcScopes = 'openid,profile,email,offline_access',
    this.oidcProviderParameter = 'connection',
    this.oidcGoogleConnection = '',
    this.oidcAppleConnection = '',
    this.oidcDatabaseConnection = '',
    this.billingMode = 'unavailable',
    this.appleMonthlyProductId = '',
    this.appleYearlyProductId = '',
    this.googleMonthlyProductId = '',
    this.googleYearlyProductId = '',
  });

  final String name;
  final String environment;
  final bool mockMode;
  final bool conversationCoachPreviewEnabled;
  final String authenticationMode;
  final String apiBaseUrl;
  final String apiAccessToken;
  final String oidcDiscoveryUrl;
  final String oidcClientId;
  final String oidcAudience;
  final String oidcRedirectUrl;
  final String oidcPostLogoutRedirectUrl;
  final String oidcScopes;
  final String oidcProviderParameter;
  final String oidcGoogleConnection;
  final String oidcAppleConnection;
  final String oidcDatabaseConnection;
  final String billingMode;
  final String appleMonthlyProductId;
  final String appleYearlyProductId;
  final String googleMonthlyProductId;
  final String googleYearlyProductId;

  List<String> validationFailures({
    required bool releaseMode,
    MobileReleasePlatform platform = MobileReleasePlatform.all,
  }) {
    final failures = <String>[];
    final normalizedEnvironment = environment.trim().toLowerCase();
    final normalizedAuthenticationMode = authenticationMode
        .trim()
        .toLowerCase();
    final parsedApiBaseUrl = Uri.tryParse(apiBaseUrl.trim());

    if (name.trim().isEmpty) {
      failures.add('app_name_missing');
    }
    if (!const {
      'local',
      'test',
      'staging',
      'production',
    }.contains(normalizedEnvironment)) {
      failures.add('app_environment_unsupported');
    }
    if (apiBaseUrl.isNotEmpty &&
        (parsedApiBaseUrl == null ||
            !parsedApiBaseUrl.hasScheme ||
            !parsedApiBaseUrl.hasAuthority)) {
      failures.add('api_base_url_invalid');
    }
    if (!const {
      'mock',
      'oidc',
      'unavailable',
    }.contains(normalizedAuthenticationMode)) {
      failures.add('authentication_mode_unsupported');
    }
    final discoveryUrl = Uri.tryParse(oidcDiscoveryUrl.trim());
    final redirectUrl = Uri.tryParse(oidcRedirectUrl.trim());
    final postLogoutRedirectUrl = Uri.tryParse(
      oidcPostLogoutRedirectUrl.trim(),
    );
    final scopes = oidcScopes
        .split(',')
        .map((scope) => scope.trim())
        .where((scope) => scope.isNotEmpty)
        .toSet();
    if (normalizedAuthenticationMode == 'oidc') {
      if (discoveryUrl == null ||
          discoveryUrl.scheme != 'https' ||
          discoveryUrl.host.isEmpty ||
          discoveryUrl.userInfo.isNotEmpty ||
          discoveryUrl.hasQuery ||
          discoveryUrl.hasFragment) {
        failures.add('oidc_discovery_url_unsafe');
      }
      if (oidcClientId.trim().isEmpty) {
        failures.add('oidc_client_id_missing');
      }
      if (oidcAudience.trim().isEmpty ||
          oidcAudience != oidcAudience.trim() ||
          oidcAudience.length > 256 ||
          RegExp(r'[\s\x00-\x1F\x7F]').hasMatch(oidcAudience)) {
        failures.add('oidc_audience_invalid');
      }
      if (redirectUrl == null ||
          !redirectUrl.hasScheme ||
          redirectUrl.scheme != 'com.convocoach.convo-coach' ||
          redirectUrl.userInfo.isNotEmpty ||
          redirectUrl.hasQuery ||
          redirectUrl.hasFragment) {
        failures.add('oidc_redirect_url_unsafe');
      }
      if (postLogoutRedirectUrl == null ||
          !postLogoutRedirectUrl.hasScheme ||
          postLogoutRedirectUrl.scheme != 'com.convocoach.convo-coach' ||
          postLogoutRedirectUrl.userInfo.isNotEmpty ||
          postLogoutRedirectUrl.hasQuery ||
          postLogoutRedirectUrl.hasFragment) {
        failures.add('oidc_post_logout_redirect_url_unsafe');
      }
      if (!scopes.contains('openid')) {
        failures.add('oidc_openid_scope_missing');
      }
      final providerValuePattern = RegExp(r'^[A-Za-z0-9._-]+$');
      if (!providerValuePattern.hasMatch(oidcProviderParameter)) {
        failures.add('oidc_provider_parameter_invalid');
      }
      for (final connection in [
        oidcGoogleConnection,
        oidcAppleConnection,
        oidcDatabaseConnection,
      ]) {
        if (connection.isNotEmpty &&
            !providerValuePattern.hasMatch(connection)) {
          failures.add('oidc_provider_connection_invalid');
        }
      }
    }
    if (!const {'unavailable', 'store'}.contains(billingMode)) {
      failures.add('billing_mode_unsupported');
    }
    final productPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$');
    if (billingMode == 'store') {
      final appleProductIds = {appleMonthlyProductId, appleYearlyProductId};
      final googleProductIds = {googleMonthlyProductId, googleYearlyProductId};
      final requiredProductIds = switch (platform) {
        MobileReleasePlatform.android => googleProductIds,
        MobileReleasePlatform.ios => appleProductIds,
        MobileReleasePlatform.all => {...appleProductIds, ...googleProductIds},
      };
      final productsAreDistinct = switch (platform) {
        MobileReleasePlatform.android => googleProductIds.length == 2,
        MobileReleasePlatform.ios => appleProductIds.length == 2,
        MobileReleasePlatform.all =>
          googleProductIds.length == 2 && appleProductIds.length == 2,
      };
      if (!productsAreDistinct ||
          requiredProductIds.any(
            (product) => !productPattern.hasMatch(product),
          )) {
        failures.add('store_product_identifiers_invalid');
      }
      if (!authenticatedApiConfigured) {
        failures.add('store_billing_requires_authenticated_api');
      }
    }

    if (releaseMode) {
      if (normalizedEnvironment != 'production') {
        failures.add('release_environment_not_production');
      }
      if (mockMode) {
        failures.add('release_mock_mode_enabled');
      }
      if (normalizedAuthenticationMode != 'oidc') {
        failures.add('release_authentication_mode_unsafe');
      }
      if (parsedApiBaseUrl == null ||
          parsedApiBaseUrl.scheme != 'https' ||
          parsedApiBaseUrl.host.isEmpty ||
          parsedApiBaseUrl.userInfo.isNotEmpty ||
          parsedApiBaseUrl.hasQuery ||
          parsedApiBaseUrl.hasFragment) {
        failures.add('release_api_url_not_https');
      }
      if (apiAccessToken.isNotEmpty) {
        failures.add('release_embedded_access_token');
      }
      if (oidcGoogleConnection.isEmpty && oidcAppleConnection.isEmpty) {
        failures.add('release_identity_connection_missing');
      }
      if (platform != MobileReleasePlatform.android &&
          oidcGoogleConnection.isNotEmpty &&
          oidcAppleConnection.isEmpty) {
        failures.add('release_apple_sign_in_missing');
      }
      if (platform == MobileReleasePlatform.android &&
          oidcGoogleConnection.isEmpty) {
        failures.add('release_google_sign_in_missing');
      }
      if (billingMode != 'store') {
        failures.add('release_store_billing_missing');
      }
    }

    return List.unmodifiable(failures);
  }

  bool get previewAuthenticationEnabled =>
      mockMode && authenticationMode.trim().toLowerCase() == 'mock';

  bool get oidcAuthenticationEnabled =>
      authenticationMode.trim().toLowerCase() == 'oidc';

  bool get authenticatedApiConfigured =>
      apiBaseUrl.trim().isNotEmpty &&
      (oidcAuthenticationEnabled ||
          (previewAuthenticationEnabled && apiAccessToken.isNotEmpty));

  List<String> get parsedOidcScopes => List.unmodifiable(
    oidcScopes
        .split(',')
        .map((scope) => scope.trim())
        .where((scope) => scope.isNotEmpty),
  );

  bool get googleSignInEnabled =>
      oidcAuthenticationEnabled && oidcGoogleConnection.isNotEmpty;

  bool get appleSignInEnabled =>
      oidcAuthenticationEnabled && oidcAppleConnection.isNotEmpty;

  bool get emailPasswordSignInEnabled =>
      oidcAuthenticationEnabled && oidcDatabaseConnection.isNotEmpty;

  bool get storeBillingEnabled => billingMode == 'store';

  void validate({
    required bool releaseMode,
    MobileReleasePlatform platform = MobileReleasePlatform.all,
  }) {
    final failures = validationFailures(
      releaseMode: releaseMode,
      platform: platform,
    );
    if (failures.isNotEmpty) {
      throw MobileConfigurationError(failures);
    }
  }
}

final class MobileConfigurationError implements Exception {
  const MobileConfigurationError(this.failures);

  final List<String> failures;

  @override
  String toString() => 'Invalid mobile configuration: ${failures.join(',')}';
}

abstract final class AppConfig {
  static const String name = String.fromEnvironment(
    'CONVOCOACH_APP_NAME',
    defaultValue: 'ConvoCoach',
  );

  static const bool mockMode = bool.fromEnvironment(
    'CONVOCOACH_MOCK_MODE',
    defaultValue: true,
  );

  static const String environment = String.fromEnvironment(
    'CONVOCOACH_ENVIRONMENT',
    defaultValue: 'local',
  );

  static const bool conversationCoachPreviewEnabled = bool.fromEnvironment(
    'CONVOCOACH_COACH_PREVIEW_ENABLED',
    defaultValue: false,
  );

  static const String authenticationMode = String.fromEnvironment(
    'CONVOCOACH_AUTHENTICATION_MODE',
    defaultValue: 'mock',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'CONVOCOACH_API_BASE_URL',
    defaultValue: '',
  );

  static const String apiAccessToken = String.fromEnvironment(
    'CONVOCOACH_API_ACCESS_TOKEN',
    defaultValue: '',
  );

  static const String oidcDiscoveryUrl = String.fromEnvironment(
    'CONVOCOACH_OIDC_DISCOVERY_URL',
    defaultValue: '',
  );

  static const String oidcClientId = String.fromEnvironment(
    'CONVOCOACH_OIDC_CLIENT_ID',
    defaultValue: '',
  );

  static const String oidcAudience = String.fromEnvironment(
    'CONVOCOACH_OIDC_AUDIENCE',
    defaultValue: '',
  );

  static const String oidcRedirectUrl = String.fromEnvironment(
    'CONVOCOACH_OIDC_REDIRECT_URL',
    defaultValue: '',
  );

  static const String oidcPostLogoutRedirectUrl = String.fromEnvironment(
    'CONVOCOACH_OIDC_POST_LOGOUT_REDIRECT_URL',
    defaultValue: '',
  );

  static const String oidcScopes = String.fromEnvironment(
    'CONVOCOACH_OIDC_SCOPES',
    defaultValue: 'openid,profile,email,offline_access',
  );

  static const String oidcProviderParameter = String.fromEnvironment(
    'CONVOCOACH_OIDC_PROVIDER_PARAMETER',
    defaultValue: 'connection',
  );

  static const String oidcGoogleConnection = String.fromEnvironment(
    'CONVOCOACH_OIDC_GOOGLE_CONNECTION',
    defaultValue: '',
  );

  static const String oidcAppleConnection = String.fromEnvironment(
    'CONVOCOACH_OIDC_APPLE_CONNECTION',
    defaultValue: '',
  );

  static const String oidcDatabaseConnection = String.fromEnvironment(
    'CONVOCOACH_OIDC_DATABASE_CONNECTION',
    defaultValue: '',
  );

  static const String billingMode = String.fromEnvironment(
    'CONVOCOACH_BILLING_MODE',
    defaultValue: 'unavailable',
  );

  static const String appleMonthlyProductId = String.fromEnvironment(
    'CONVOCOACH_APPLE_MONTHLY_PRODUCT_ID',
    defaultValue: '',
  );

  static const String appleYearlyProductId = String.fromEnvironment(
    'CONVOCOACH_APPLE_YEARLY_PRODUCT_ID',
    defaultValue: '',
  );

  static const String googleMonthlyProductId = String.fromEnvironment(
    'CONVOCOACH_GOOGLE_MONTHLY_PRODUCT_ID',
    defaultValue: '',
  );

  static const String googleYearlyProductId = String.fromEnvironment(
    'CONVOCOACH_GOOGLE_YEARLY_PRODUCT_ID',
    defaultValue: '',
  );

  static const MobileRuntimeConfiguration runtime = MobileRuntimeConfiguration(
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
    oidcScopes: oidcScopes,
    oidcProviderParameter: oidcProviderParameter,
    oidcGoogleConnection: oidcGoogleConnection,
    oidcAppleConnection: oidcAppleConnection,
    oidcDatabaseConnection: oidcDatabaseConnection,
    billingMode: billingMode,
    appleMonthlyProductId: appleMonthlyProductId,
    appleYearlyProductId: appleYearlyProductId,
    googleMonthlyProductId: googleMonthlyProductId,
    googleYearlyProductId: googleYearlyProductId,
  );

  static void validateForStartup({
    required bool releaseMode,
    MobileReleasePlatform platform = MobileReleasePlatform.all,
  }) {
    runtime.validate(releaseMode: releaseMode, platform: platform);
  }
}
