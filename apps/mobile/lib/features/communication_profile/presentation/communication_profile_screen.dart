import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/app_skeleton.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/communication_profile/application/communication_profile_controller.dart';
import 'package:convo_coach/features/communication_profile/domain/communication_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommunicationProfileScreen extends ConsumerWidget {
  const CommunicationProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(communicationProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Communication profile')),
      body: profile.when(
        loading: () => const _ProfileSkeleton(),
        error: (error, stackTrace) => AppErrorState(
          title: 'Your profile is unavailable.',
          message: 'Try loading your preferences again.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(communicationProfileProvider),
        ),
        data: (value) => _ProfileForm(profile: value),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile});

  final CommunicationProfile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.profile.preferredName,
  );
  late RelationshipIntention _intention = widget.profile.relationshipIntention;
  late CommunicationTone _tone = widget.profile.communicationTone;
  late MessageLength _messageLength = widget.profile.messageLength;
  late bool _usesEmojis = widget.profile.usesEmojis;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await ref
        .read(communicationProfileProvider.notifier)
        .save(
          CommunicationProfile(
            preferredName: _nameController.text.trim(),
            relationshipIntention: _intention,
            communicationTone: _tone,
            messageLength: _messageLength,
            usesEmojis: _usesEmojis,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Communication profile saved.'
              : 'Profile could not be saved.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveContent(
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          Text(
            'Tell us what feels natural to you.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'These are your choices, not personality conclusions.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  maxLength: 80,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Preferred name',
                    hintText: 'Optional',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<RelationshipIntention>(
                  initialValue: _intention,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Relationship intention',
                  ),
                  items: [
                    for (final value in RelationshipIntention.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          value.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _intention = value);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<CommunicationTone>(
                  initialValue: _tone,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Preferred tone',
                  ),
                  items: [
                    for (final value in CommunicationTone.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          value.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _tone = value);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<MessageLength>(
                  initialValue: _messageLength,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Preferred message length',
                  ),
                  items: [
                    for (final value in MessageLength.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          value.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _messageLength = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              title: const Text('I usually use emojis'),
              subtitle: const Text('You can change this anytime'),
              secondary: const Icon(Icons.emoji_emotions_outlined),
              value: _usesEmojis,
              onChanged: (value) => setState(() => _usesEmojis = value),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Save profile',
            icon: Icons.check_rounded,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ResponsiveContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(height: 30, width: 280),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 20, width: 340),
          SizedBox(height: AppSpacing.xl),
          AppSkeleton(height: 320),
        ],
      ),
    );
  }
}
