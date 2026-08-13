import 'dart:typed_data';

import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/theme/app_typography.dart';
import 'package:convo_coach/core/widgets/app_background.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/app_skeleton.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/communication_profile/application/communication_profile_controller.dart';
import 'package:convo_coach/features/communication_profile/domain/communication_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class CommunicationProfileScreen extends ConsumerWidget {
  const CommunicationProfileScreen({this.setupMode = false, super.key});

  final bool setupMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(communicationProfileProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: !setupMode,
        title: Text(setupMode ? 'Set up your profile' : 'Your profile'),
      ),
      body: AppBackground(
        child: profile.when(
          loading: () => const _ProfileSkeleton(),
          error: (error, stackTrace) => AppErrorState(
            title: 'Your profile is unavailable.',
            message: 'Try loading your preferences again.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(communicationProfileProvider),
          ),
          data: (value) {
            if (setupMode && value.profileSetupCompleted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/home');
              });
              return const _ProfileSkeleton();
            }
            return _ProfileForm(profile: value, setupMode: setupMode);
          },
        ),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile, required this.setupMode});

  final CommunicationProfile profile;
  final bool setupMode;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.profile.preferredName,
  );
  late final TextEditingController _jobController = TextEditingController(
    text: widget.profile.jobTitle,
  );
  late final TextEditingController _ageController = TextEditingController(
    text: widget.profile.age?.toString() ?? '',
  );
  late final TextEditingController _genderController = TextEditingController(
    text: widget.profile.gender,
  );
  late final TextEditingController _likesController = TextEditingController(
    text: widget.profile.likes.join(', '),
  );
  late final TextEditingController _lookingForController =
      TextEditingController(text: widget.profile.lookingFor.join(', '));
  late RelationshipIntention _intention = widget.profile.relationshipIntention;
  late CommunicationTone _tone = widget.profile.communicationTone;
  late MessageLength _messageLength = widget.profile.messageLength;
  late bool _usesEmojis = widget.profile.usesEmojis;
  bool _saving = false;
  late Uint8List? _photoBytes = widget.profile.profilePhotoBytes;
  bool _photoChanged = false;
  String _photoContentType = 'image/jpeg';

  @override
  void dispose() {
    _nameController.dispose();
    _jobController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _likesController.dispose();
    _lookingForController.dispose();
    super.dispose();
  }

  List<String> _items(TextEditingController controller) {
    final seen = <String>{};
    return controller.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && seen.add(value.toLowerCase()))
        .toList(growable: false);
  }

  Future<void> _pickPhoto() async {
    final selected = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 78,
    );
    if (selected == null || !mounted) return;
    final bytes = await selected.readAsBytes();
    if (!mounted) return;
    if (bytes.isEmpty || bytes.length > 900 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a photo smaller than 900 KB.')),
      );
      return;
    }
    final extension = selected.path.toLowerCase();
    setState(() {
      _photoBytes = bytes;
      _photoChanged = true;
      _photoContentType = extension.endsWith('.png')
          ? 'image/png'
          : extension.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';
    });
  }

  Future<void> _save() async {
    final likes = _items(_likesController);
    final lookingFor = _items(_lookingForController);
    if ([...likes, ...lookingFor].any((item) => item.length > 48) ||
        likes.length > 12 ||
        lookingFor.length > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use up to 12 items, with 48 characters per item.'),
        ),
      );
      return;
    }
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());
    final gender = _genderController.text.trim();
    if (widget.setupMode && (name.isEmpty || age == null || likes.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your name, adult age, and at least one hobby.'),
        ),
      );
      return;
    }
    if (age != null && (age < 18 || age > 120)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ConvoCoach is only for adults 18+.')),
      );
      return;
    }
    setState(() => _saving = true);
    var saved = await ref
        .read(communicationProfileProvider.notifier)
        .save(
          CommunicationProfile(
            preferredName: name,
            age: age,
            gender: gender,
            profileSetupCompleted: widget.setupMode
                ? true
                : widget.profile.profileSetupCompleted,
            relationshipIntention: _intention,
            communicationTone: _tone,
            messageLength: _messageLength,
            usesEmojis: _usesEmojis,
            jobTitle: _jobController.text.trim(),
            likes: likes,
            lookingFor: lookingFor,
            profilePhotoBytes: widget.profile.profilePhotoBytes,
          ),
        );
    if (saved && _photoChanged) {
      saved = _photoBytes == null
          ? await ref.read(communicationProfileProvider.notifier).deletePhoto()
          : await ref
                .read(communicationProfileProvider.notifier)
                .updatePhoto(_photoBytes!, _photoContentType);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved ? 'Profile saved.' : 'Profile could not be saved.'),
      ),
    );
    if (saved && widget.setupMode && context.mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveContent(
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          AppReveal(
            child: GradientText(
              'Tell us what feels natural to you.',
              gradient: LinearGradient(
                colors: [
                  context.appColors.gradientStart,
                  context.appColors.gradientEnd,
                ],
              ),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppReveal(
            delay: const Duration(milliseconds: 60),
            child: Text(
              widget.setupMode
                  ? 'A few details help tailor your drafts. You stay in control and can edit them later.'
                  : 'These are your choices, not personality conclusions.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppReveal(
            delay: const Duration(milliseconds: 120),
            child: AppCard(
              child: Column(
                children: [
                  Semantics(
                    label: _photoBytes == null
                        ? 'No profile picture selected'
                        : 'Selected profile picture',
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: context.appColors.surfaceRaised,
                      backgroundImage: _photoBytes == null
                          ? null
                          : MemoryImage(_photoBytes!),
                      child: _photoBytes == null
                          ? const Icon(Icons.person_outline_rounded, size: 48)
                          : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      TextButton.icon(
                        onPressed: _saving ? null : _pickPhoto,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: Text(
                          _photoBytes == null ? 'Add photo' : 'Change photo',
                        ),
                      ),
                      if (_photoBytes != null)
                        TextButton.icon(
                          onPressed: _saving
                              ? null
                              : () => setState(() {
                                  _photoBytes = null;
                                  _photoChanged = true;
                                }),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Remove'),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _nameController,
                    maxLength: 80,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Preferred name',
                      hintText: 'What should we call you?',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    maxLength: 3,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      hintText: '18 or older',
                      prefixIcon: Icon(Icons.cake_outlined),
                      helperText: 'Required for first-time setup.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _genderController,
                    maxLength: 64,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Gender or self-description',
                      hintText: 'Optional and self-described',
                      prefixIcon: Icon(Icons.badge_outlined),
                      helperText:
                          'Used only for wording you request, never stereotypes.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _jobController,
                    maxLength: 100,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Job or occupation',
                      hintText: 'Optional',
                      prefixIcon: Icon(Icons.work_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _likesController,
                    maxLength: 600,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Things you like',
                      hintText: 'Music, hiking, coffee (comma separated)',
                      prefixIcon: Icon(Icons.favorite_border_rounded),
                      helperText:
                          'At least one during setup. Used only to tailor your drafts.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _lookingForController,
                    maxLength: 600,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'What you want',
                      hintText: 'Honesty, serious dating (comma separated)',
                      prefixIcon: Icon(Icons.explore_outlined),
                      helperText:
                          'Your stated preferences, never an AI conclusion.',
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
          ),
          const SizedBox(height: AppSpacing.lg),
          AppReveal(
            delay: const Duration(milliseconds: 180),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                title: const Text('I usually use emojis'),
                subtitle: const Text('You can change this anytime'),
                secondary: const Icon(Icons.emoji_emotions_outlined),
                value: _usesEmojis,
                onChanged: (value) => setState(() => _usesEmojis = value),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppReveal(
            delay: const Duration(milliseconds: 240),
            child: AppButton(
              label: 'Save profile',
              icon: Icons.check_rounded,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
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
