import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/widgets/app_background.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:flutter/material.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Progress')),
      body: const AppBackground(
        child: AppReveal(
          child: AppEmptyState(
            title: 'No patterns yet.',
            message:
                'Future progress summaries will use only conversations you choose to save.',
          ),
        ),
      ),
    );
  }
}
