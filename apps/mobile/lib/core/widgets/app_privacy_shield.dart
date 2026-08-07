import 'package:flutter/material.dart';

/// Covers private conversation UI before the operating system snapshots the app.
class AppPrivacyShield extends StatefulWidget {
  const AppPrivacyShield({required this.child, super.key});

  final Widget child;

  @override
  State<AppPrivacyShield> createState() => _AppPrivacyShieldState();
}

class _AppPrivacyShieldState extends State<AppPrivacyShield>
    with WidgetsBindingObserver {
  late AppLifecycleState _lifecycleState =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || state == _lifecycleState) return;
    setState(() => _lifecycleState = state);
  }

  @override
  Widget build(BuildContext context) {
    final hidden = _lifecycleState != AppLifecycleState.resumed;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (hidden)
          ColoredBox(
            key: const Key('app-privacy-shield'),
            color: Theme.of(context).colorScheme.surface,
            child: Semantics(
              label: 'ConvoCoach is hidden to protect your privacy',
              container: true,
              child: const Center(
                child: ExcludeSemantics(
                  child: Icon(Icons.lock_outline_rounded, size: 40),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
