import 'dart:async';

import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:convo_coach/features/shell/presentation/create_actions_sheet.dart';
import 'package:flutter/material.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      body: AppEmptyState(
        title: 'A quiet start.',
        message:
            'Saved conversations will appear here only after you choose to keep them.',
        actionLabel: 'Create',
        onAction: () => unawaited(showCreateActions(context)),
      ),
    );
  }
}
