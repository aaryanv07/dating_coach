enum MobileAuthenticationMethod { apple, google, emailLink, oidc }

enum MobileAuthenticationLifecycle {
  signedOut,
  authenticating,
  authenticated,
  expired,
  unavailable,
}

final class MobileAuthenticationSession {
  const MobileAuthenticationSession({
    required this.lifecycle,
    this.method,
    this.opaqueAccountReference,
  }) : assert(
         lifecycle == MobileAuthenticationLifecycle.authenticated ||
             opaqueAccountReference == null,
         'Only an authenticated session may expose an opaque account reference.',
       );

  const MobileAuthenticationSession.signedOut()
    : lifecycle = MobileAuthenticationLifecycle.signedOut,
      method = null,
      opaqueAccountReference = null;

  const MobileAuthenticationSession.unavailable()
    : lifecycle = MobileAuthenticationLifecycle.unavailable,
      method = null,
      opaqueAccountReference = null;

  final MobileAuthenticationLifecycle lifecycle;
  final MobileAuthenticationMethod? method;

  /// Server-opaque reference for UI identity only. Never a credential or token.
  final String? opaqueAccountReference;

  bool get isAuthenticated =>
      lifecycle == MobileAuthenticationLifecycle.authenticated;
}

sealed class MobileAuthenticationResult {
  const MobileAuthenticationResult();
}

final class MobileAuthenticationSucceeded extends MobileAuthenticationResult {
  MobileAuthenticationSucceeded(this.session)
    : assert(session.lifecycle == MobileAuthenticationLifecycle.authenticated);

  final MobileAuthenticationSession session;
}

final class MobileAuthenticationRejected extends MobileAuthenticationResult {
  const MobileAuthenticationRejected(this.code);

  final String code;
}

abstract interface class MobileAuthenticationGateway {
  /// Observes sanitized session state; credentials never cross this contract.
  Stream<MobileAuthenticationSession> watchSession();

  /// Starts a user-initiated provider flow.
  Future<MobileAuthenticationResult> signIn(MobileAuthenticationMethod method);

  /// Removes the provider session and locally protected credential material.
  Future<void> signOut();
}

abstract interface class MobileAccessTokenProvider {
  /// Returns a valid short-lived token, refreshing it when safely possible.
  Future<String?> accessToken();
}
