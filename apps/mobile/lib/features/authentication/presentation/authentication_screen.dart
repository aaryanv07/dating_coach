import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/core/haptics/app_haptics.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_input.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/authentication/application/mock_auth_controller.dart';
import 'package:convo_coach/features/authentication/application/authentication_providers.dart';
import 'package:convo_coach/features/authentication/domain/authentication_contracts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AuthenticationScreen extends ConsumerStatefulWidget {
  const AuthenticationScreen({this.previewAuthenticationEnabled, super.key});

  final bool? previewAuthenticationEnabled;

  @override
  ConsumerState<AuthenticationScreen> createState() =>
      _AuthenticationScreenState();
}

class _AuthenticationScreenState extends ConsumerState<AuthenticationScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _emailLooksValid = false;
  bool _authenticating = false;
  String? _authenticationError;

  bool get _previewAuthenticationEnabled =>
      widget.previewAuthenticationEnabled ??
      AppConfig.runtime.previewAuthenticationEnabled;

  bool get _oidcAuthenticationEnabled =>
      widget.previewAuthenticationEnabled == null &&
      AppConfig.runtime.oidcAuthenticationEnabled;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _continue(MockAuthMethod method) {
    if (!_previewAuthenticationEnabled) {
      return;
    }
    ref.read(mockAuthProvider.notifier).signIn(method);
    ref.read(hapticsProvider).success();
    context.go('/profile/setup');
  }

  Future<void> _continueSecurely(MobileAuthenticationMethod method) async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _authenticationError = null;
    });
    try {
      final result = await ref
          .read(authenticationGatewayProvider)
          .signIn(method);
      if (!mounted) return;
      if (result is MobileAuthenticationSucceeded) {
        context.go('/profile/setup');
        return;
      }
      setState(() {
        _authenticationError = authenticationFailureMessage(
          (result as MobileAuthenticationRejected).code,
        );
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _authenticationError =
            'Secure sign-in is temporarily unavailable. Try again without re-entering your details.';
      });
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_oidcAuthenticationEnabled) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: ResponsiveContent(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              Text(
                'Sign in securely.',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Continue to the protected sign-in page. ELLIS uses authorization code with PKCE and stores session credentials in your device keychain.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                key: const Key('production-google-sign-in'),
                label: _authenticating
                    ? 'Signing in…'
                    : AppConfig.runtime.googleSignInEnabled
                    ? 'Continue with Google'
                    : 'Continue securely',
                icon: AppConfig.runtime.googleSignInEnabled
                    ? Icons.public_rounded
                    : Icons.lock_outline_rounded,
                onPressed: _authenticating
                    ? null
                    : () => _continueSecurely(
                        AppConfig.runtime.googleSignInEnabled
                            ? MobileAuthenticationMethod.google
                            : MobileAuthenticationMethod.oidc,
                      ),
              ),
              if (AppConfig.runtime.appleSignInEnabled) ...[
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  key: const Key('production-apple-sign-in'),
                  label: 'Continue with Apple',
                  icon: Icons.apple,
                  variant: AppButtonVariant.secondary,
                  onPressed: _authenticating
                      ? null
                      : () =>
                            _continueSecurely(MobileAuthenticationMethod.apple),
                ),
              ],
              if (AppConfig.runtime.emailPasswordSignInEnabled) ...[
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  key: const Key('production-email-password-sign-in'),
                  label: 'Continue with email & password',
                  icon: Icons.mail_outline_rounded,
                  variant: AppButtonVariant.secondary,
                  onPressed: _authenticating
                      ? null
                      : () => _continueSecurely(
                          MobileAuthenticationMethod.emailPassword,
                        ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.md,
                  children: [
                    TextButton(
                      key: const Key('production-create-account'),
                      onPressed: _authenticating
                          ? null
                          : () => _continueSecurely(
                              MobileAuthenticationMethod.emailSignup,
                            ),
                      child: const Text('Create account'),
                    ),
                    TextButton(
                      key: const Key('production-forgot-password'),
                      onPressed: _authenticating
                          ? null
                          : () => _continueSecurely(
                              MobileAuthenticationMethod.emailPassword,
                            ),
                      child: const Text('Forgot password?'),
                    ),
                  ],
                ),
                Text(
                  'The protected sign-in page lets you reset your password by email. ELLIS never sees it.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_authenticationError case final message?) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: TextStyle(color: context.appColors.risk),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Your identity provider may offer Apple, Google, or email sign-in. ELLIS never receives your provider password.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }
    if (!_previewAuthenticationEnabled) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: ResponsiveContent(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              Text(
                'Secure sign-in is not available yet.',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'This qualification build does not include a production identity provider. No preview account or network session will be created.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: context.appColors.info,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Release remains blocked until production authentication is implemented and independently qualified.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            Text(
              'Your space in ${AppConfig.name}.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Choose a preview sign-in. No account or network request is created in this build.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.science_outlined, color: context.appColors.info),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Mock mode',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Continue with Apple',
              icon: Icons.apple,
              variant: AppButtonVariant.secondary,
              onPressed: () => _continue(MockAuthMethod.apple),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Continue with Google',
              icon: Icons.public_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => _continue(MockAuthMethod.google),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    'or',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: 'Email',
              hint: 'you@example.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              prefixIcon: Icons.mail_outline_rounded,
              onChanged: (value) {
                final looksValid = value.contains('@') && value.contains('.');
                if (looksValid != _emailLooksValid) {
                  setState(() => _emailLooksValid = looksValid);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Continue with email',
              icon: Icons.arrow_forward_rounded,
              onPressed: _emailLooksValid
                  ? () => _continue(MockAuthMethod.email)
                  : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'By continuing, you confirm the age and privacy choices you just made.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String authenticationFailureMessage(String code) => switch (code) {
  'authentication_session_incomplete' =>
    'Sign-in reached Auth0, but a persistent session was not returned. Enable offline access for the API, then try again.',
  'authentication_configuration_invalid' =>
    'Secure sign-in configuration was rejected. Check the Auth0 native client, callback, audience, and allowed grants.',
  'authentication_provider_unavailable' =>
    'The sign-in provider is temporarily unavailable. Try again shortly.',
  'authentication_access_denied' =>
    'Google did not authorize this sign-in. Choose the intended account and approve the request.',
  'authentication_cancelled' =>
    'Sign-in was cancelled. Your existing session and account data were kept.',
  _ =>
    'Secure sign-in did not finish. Your existing session and account data were kept.',
};
