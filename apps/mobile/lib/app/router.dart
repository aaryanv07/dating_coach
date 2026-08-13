import 'package:convo_coach/features/authentication/presentation/authentication_screen.dart';
import 'package:convo_coach/features/conversations/presentation/conversations_screen.dart';
import 'package:convo_coach/features/conversations/presentation/conversation_detail_screen.dart';
import 'package:convo_coach/features/conversation_import/presentation/conversation_review_studio.dart';
import 'package:convo_coach/features/conversation_import/presentation/import_type_screen.dart';
import 'package:convo_coach/features/conversation_import/presentation/paste_import_screen.dart';
import 'package:convo_coach/features/conversation_import/presentation/screenshot_import_screen.dart';
import 'package:convo_coach/features/home/presentation/home_screen.dart';
import 'package:convo_coach/features/onboarding/presentation/age_confirmation_screen.dart';
import 'package:convo_coach/features/onboarding/presentation/onboarding_screen.dart';
import 'package:convo_coach/features/onboarding/presentation/privacy_screen.dart';
import 'package:convo_coach/features/progress/presentation/progress_screen.dart';
import 'package:convo_coach/features/settings/presentation/settings_screen.dart';
import 'package:convo_coach/features/shell/presentation/app_shell.dart';
import 'package:convo_coach/features/splash/presentation/splash_screen.dart';
import 'package:convo_coach/features/subscription/presentation/subscription_screen.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:convo_coach/features/communication_profile/presentation/communication_profile_screen.dart';
import 'package:convo_coach/features/conversation_dashboard/presentation/conversation_dashboard_screen.dart';
import 'package:convo_coach/features/conversation_coach/presentation/conversation_coach_screen.dart';
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
      GoRoute(path: '/settings', redirect: (context, state) => '/profile'),
      GoRoute(
        path: '/settings/profile',
        redirect: (context, state) => '/profile/edit',
      ),
      GoRoute(
        path: '/settings/subscription',
        redirect: (context, state) => '/profile/subscription',
      ),
      GoRoute(
        path: '/import',
        builder: (context, state) => const ImportTypeScreen(),
        routes: [
          GoRoute(
            path: 'screenshots',
            builder: (context, state) => const ScreenshotImportScreen(),
          ),
          GoRoute(
            path: 'paste',
            builder: (context, state) => const PasteImportScreen(),
          ),
          GoRoute(
            path: 'review',
            builder: (context, state) => const ConversationReviewStudio(),
          ),
        ],
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
                routes: [
                  GoRoute(
                    path: ':conversationId',
                    builder: (context, state) => ConversationDetailScreen(
                      conversationId: state.pathParameters['conversationId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'dashboard',
                        builder: (context, state) =>
                            ConversationDashboardScreen(
                              conversationId:
                                  state.pathParameters['conversationId']!,
                            ),
                      ),
                      GoRoute(
                        path: 'coach-preview',
                        builder: (context, state) => ConversationCoachScreen(
                          conversationId:
                              state.pathParameters['conversationId']!,
                        ),
                      ),
                    ],
                  ),
                ],
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
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) =>
                        const CommunicationProfileScreen(),
                  ),
                  GoRoute(
                    path: 'subscription',
                    builder: (context, state) => const SubscriptionScreen(),
                  ),
                ],
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
