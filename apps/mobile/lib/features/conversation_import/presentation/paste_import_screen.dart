import 'dart:async';

import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/conversation_import/application/conversation_import_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PasteImportScreen extends ConsumerStatefulWidget {
  const PasteImportScreen({super.key});

  @override
  ConsumerState<PasteImportScreen> createState() => _PasteImportScreenState();
}

class _PasteImportScreenState extends ConsumerState<PasteImportScreen> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _continue() {
    final parsed = ref
        .read(conversationImportProvider.notifier)
        .parsePaste(_textController.text);
    if (parsed) context.push('/import/review');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationImportProvider);
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          unawaited(ref.read(conversationImportProvider.notifier).cancel());
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Paste conversation')),
        body: ResponsiveContent(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Paste first. Perfect it next.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your text becomes editable message blocks before anything is saved.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                key: const Key('paste-conversation-field'),
                controller: _textController,
                minLines: 10,
                maxLines: 18,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Conversation text',
                  hintText:
                      'Other: Are we still meeting tomorrow?\nMe: Yes, noon works.',
                  alignLabelWithHint: true,
                ),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppErrorState(
                  title: 'More context is needed',
                  message: state.errorMessage!,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Prepare review',
                icon: Icons.arrow_forward_rounded,
                onPressed: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
