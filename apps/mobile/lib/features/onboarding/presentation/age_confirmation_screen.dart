import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AgeConfirmationScreen extends StatefulWidget {
  const AgeConfirmationScreen({super.key});

  @override
  State<AgeConfirmationScreen> createState() => _AgeConfirmationScreenState();
}

class _AgeConfirmationScreenState extends State<AgeConfirmationScreen> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
              semanticLabel: 'Adult access',
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'For adults, with adult boundaries.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'ConvoCoach is intended only for people aged 18 and above.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppCard(
              child: CheckboxListTile(
                key: const Key('age-confirmation-checkbox'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _confirmed,
                title: const Text('I confirm that I am 18 or older'),
                subtitle: const Text('Required to continue'),
                onChanged: (value) {
                  setState(() => _confirmed = value ?? false);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              key: const Key('age-continue-button'),
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
              semanticLabel: 'Continue after confirming age',
              onPressed: _confirmed ? () => context.go('/auth') : null,
            ),
          ],
        ),
      ),
    );
  }
}
