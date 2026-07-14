import 'package:convo_coach/features/authentication/presentation/authentication_screen.dart';
import 'package:convo_coach/features/conversations/presentation/conversations_screen.dart';
import 'package:convo_coach/features/home/presentation/home_screen.dart';
import 'package:convo_coach/features/onboarding/presentation/age_confirmation_screen.dart';
import 'package:convo_coach/features/onboarding/presentation/onboarding_screen.dart';
import 'package:convo_coach/features/onboarding/presentation/privacy_screen.dart';
import 'package:convo_coach/features/progress/presentation/progress_screen.dart';
import 'package:convo_coach/features/settings/presentation/settings_screen.dart';
import 'package:convo_coach/features/shell/presentation/app_shell.dart';
import 'package:convo_coach/features/splash/presentation/splash_screen.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

GoRouter createAppRouter({String initialLocation = '/splash'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/age',
        builder: (context, state) => const AgeConfirmationScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthenticationScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/conversations',
                builder: (context, state) => const ConversationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      return const Scaffold(
        body: AppErrorState(
          title: 'This page is unavailable.',
          message: 'Return to the app and try a different path.',
        ),
      );
    },
  );
}
