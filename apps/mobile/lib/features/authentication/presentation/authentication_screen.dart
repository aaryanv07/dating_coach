import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/core/haptics/app_haptics.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_input.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/authentication/application/mock_auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AuthenticationScreen extends ConsumerStatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  ConsumerState<AuthenticationScreen> createState() =>
      _AuthenticationScreenState();
}

class _AuthenticationScreenState extends ConsumerState<AuthenticationScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _emailLooksValid = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _continue(MockAuthMethod method) {
    ref.read(mockAuthProvider.notifier).signIn(method);
    ref.read(hapticsProvider).success();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
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
