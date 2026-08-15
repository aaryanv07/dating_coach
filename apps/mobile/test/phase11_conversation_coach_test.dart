import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convo_coach/app/app.dart';
import 'package:convo_coach/app/router.dart';
import 'package:convo_coach/core/haptics/app_haptics.dart';
import 'package:convo_coach/features/conversation_coach/application/conversation_coach_controller.dart';
import 'package:convo_coach/features/conversation_coach/data/conversation_coach_transport.dart';
import 'package:convo_coach/features/conversation_coach/domain/conversation_coach_preview.dart';
import 'package:convo_coach/features/conversation_coach/domain/conversation_coach_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

const _conversationId = '00000000-0000-4000-8000-000000000001';
const _privateSentinel = 'private synthetic coach source';

Map<String, Object?> _successPayload() => {
  'schema_version': 'conversation-coach-preview.v1',
  'execution_status': 'completed',
  'response_schema_version': 'ai-coaching-response.v1',
  'renderer_schema_version': 'ai-coaching-renderer-projection.v1',
  'response_id': '00000000-0000-4000-8000-000000000002',
  'locale': 'en',
  'calculation_versions': {
    'analytics_schema_version': 'conversation-analytics.v1',
    'analytics_calculation_version': 'deterministic-conversation-analytics.v1',
    'source_event_schema_version': 'conversation-events.v1',
  },
  'sections': [
    {
      'schema_version': 'conversation-coach-preview-section.v1',
      'identifier': 'supported_capabilities',
      'heading_localization_key': 'coaching.section.supported.heading',
      'semantic_label_localization_key': 'coaching.section.supported.semantic',
      'status': 'available',
      'item_localization_keys': [
        'coaching.capability.response_schema',
        'coaching.capability.evidence_references',
      ],
      'evidence_reference_count': 0,
    },
    {
      'schema_version': 'conversation-coach-preview-section.v1',
      'identifier': 'unavailable_capabilities',
      'heading_localization_key': 'coaching.section.unavailable.heading',
      'semantic_label_localization_key':
          'coaching.section.unavailable.semantic',
      'status': 'unavailable',
      'item_localization_keys': [
        'coaching.capability.coaching_guidance.unavailable',
        'coaching.capability.reply_drafting.unavailable',
      ],
      'evidence_reference_count': 0,
    },
    {
      'schema_version': 'conversation-coach-preview-section.v1',
      'identifier': 'explanations',
      'heading_localization_key': 'coaching.section.explanations.heading',
      'semantic_label_localization_key':
          'coaching.section.explanations.semantic',
      'status': 'unavailable',
      'item_localization_keys': ['coaching.foundation.placeholder'],
      'evidence_reference_count': 4,
    },
    {
      'schema_version': 'conversation-coach-preview-section.v1',
      'identifier': 'safety_notices',
      'heading_localization_key': 'coaching.section.safety.heading',
      'semantic_label_localization_key': 'coaching.section.safety.semantic',
      'status': 'notice',
      'item_localization_keys': ['coaching.foundation.no_coaching_generated'],
      'evidence_reference_count': 0,
    },
  ],
  'notices': [
    'coaching.foundation.mock_only',
    'coaching.foundation.no_coaching_generated',
  ],
  'provenance': {
    'provider_identifier': 'mock-ai-provider.v1',
    'generator_identifier': 'deterministic-coaching-response-mock.v1',
    'mock_execution': true,
  },
  'correlation_id': '00000000-0000-4000-8000-000000000003',
};

Map<String, Object?> _failurePayload(String code, {bool retryable = false}) => {
  'schema_version': 'conversation-coach-preview-error.v1',
  'error': {
    'error_id': 'coach-preview:$code',
    'code': code,
    'localization_key': 'coaching.error.$code',
    'retryable': retryable,
    'retry_guidance_localization_key': retryable
        ? 'coaching.error.$code.retry'
        : null,
    'correlation_id': '00000000-0000-4000-8000-000000000003',
  },
};

class _FakeCoachRepository implements ConversationCoachRepository {
  const _FakeCoachRepository(this.result);

  final ConversationCoachRepositoryResult result;

  @override
  Future<ConversationCoachRepositoryResult> fetchPreview(
    String conversationId, {
    required ConversationCoachCancellationToken cancellationToken,
  }) async => result;
}

class _ThrowingCoachRepository implements ConversationCoachRepository {
  const _ThrowingCoachRepository(this.error);

  final Object error;

  @override
  Future<ConversationCoachRepositoryResult> fetchPreview(
    String conversationId, {
    required ConversationCoachCancellationToken cancellationToken,
  }) async {
    throw error;
  }
}

class _PendingCoachRepository implements ConversationCoachRepository {
  _PendingCoachRepository(this.completer);

  final Completer<ConversationCoachRepositoryResult> completer;

  @override
  Future<ConversationCoachRepositoryResult> fetchPreview(
    String conversationId, {
    required ConversationCoachCancellationToken cancellationToken,
  }) => completer.future;
}

void main() {
  group('Phase 11 strict transport', () {
    test('parses the exact immutable success projection', () {
      final result = parseConversationCoachTransport(
        jsonEncode(_successPayload()),
      );

      expect(result, isA<ConversationCoachRepositorySuccess>());
      final preview = (result as ConversationCoachRepositorySuccess).preview;
      expect(preview.sections.map((item) => item.identifier), [
        'supported_capabilities',
        'unavailable_capabilities',
        'explanations',
        'safety_notices',
      ]);
      expect(preview.sections[2].evidenceReferenceCount, 4);
      expect(
        () => preview.sections.add(preview.sections.first),
        throwsUnsupportedError,
      );
      expect(jsonEncode(_successPayload()), isNot(contains(_privateSentinel)));
    });

    test('rejects unknown fields, keys, versions, and section order', () {
      final extra = _successPayload()..['raw_provider_response'] = 'forbidden';
      final version = _successPayload()
        ..['schema_version'] = 'conversation-coach-preview.v2';
      final unknownKey = _successPayload();
      final sections = unknownKey['sections']! as List<Object?>;
      final first = sections.first! as Map<String, Object?>;
      first['item_localization_keys'] = ['coaching.generated.answer'];
      final reordered = _successPayload();
      final reorderedSections = reordered['sections']! as List<Object?>;
      final moved = reorderedSections.removeAt(0);
      reorderedSections.add(moved);

      for (final payload in [extra, version, unknownKey, reordered]) {
        expect(
          () => parseConversationCoachTransport(jsonEncode(payload)),
          throwsA(isA<ConversationCoachTransportException>()),
        );
      }
    });

    test('keeps server failures distinct', () {
      final feature = parseConversationCoachTransport(
        jsonEncode(_failurePayload('feature_disabled')),
      );
      final timeout = parseConversationCoachTransport(
        jsonEncode(_failurePayload('timed_out', retryable: true)),
      );

      expect(
        (feature as ConversationCoachRepositoryFailure).failure.code,
        ConversationCoachErrorCode.featureDisabled,
      );
      expect(
        (timeout as ConversationCoachRepositoryFailure).failure.code,
        ConversationCoachErrorCode.timedOut,
      );
    });

    test(
      'Phase 12 keeps transport mock-only with no provider selection input',
      () {
        final unsupportedProvider = _successPayload();
        final provenance =
            unsupportedProvider['provenance']! as Map<String, Object?>;
        provenance['provider_identifier'] = 'future-provider-placeholder.v1';

        expect(
          () =>
              parseConversationCoachTransport(jsonEncode(unsupportedProvider)),
          throwsA(isA<ConversationCoachTransportException>()),
        );
        expect(
          parseConversationCoachTransport(jsonEncode(_successPayload())),
          isA<ConversationCoachRepositorySuccess>(),
        );
      },
    );
  });

  group('Phase 11 preview presentation', () {
    testWidgets('renders structural placeholders and accessible mock labels', (
      tester,
    ) async {
      final parsed =
          parseConversationCoachTransport(jsonEncode(_successPayload()))
              as ConversationCoachRepositorySuccess;
      await pumpConvoCoach(
        tester,
        initialLocation: '/conversations/$_conversationId/coach-preview',
        conversationCoachEntryAvailable: true,
        conversationCoachRepository: _FakeCoachRepository(parsed),
      );

      expect(find.text('Mock infrastructure preview'), findsOneWidget);
      expect(
        find.byKey(const Key('coach-result-depth-reveal')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('app-depth-reveal-animation')),
        findsOneWidget,
      );
      expect(
        find.text('This is a deterministic mock infrastructure preview.'),
        findsOneWidget,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Coaching remains unavailable'), findsOneWidget);
      expect(find.textContaining(_privateSentinel), findsNothing);
      expect(find.textContaining('generated reply'), findsNothing);
      expect(find.byKey(const Key('provider-selector')), findsNothing);
      expect(find.text('Choose AI provider'), findsNothing);
      final semantics = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'Unavailable coaching capabilities')),
      );
      expect(semantics.label, contains('Unavailable coaching capabilities'));
    });

    testWidgets(
      'keeps disabled, review, consent, timeout, and failure states distinct',
      (tester) async {
        final cases = <String, String>{
          'feature_disabled': 'Preview is disabled',
          'mock_disabled': 'Mock execution is disabled',
          'review_incomplete': 'Review is incomplete',
          'consent_required': 'Consent is required',
          'timed_out': 'Preview timed out',
          'provider_unavailable': 'Preview execution failed',
          'internal_safe_failure': 'Preview unavailable',
        };
        for (final entry in cases.entries) {
          final retryable = {
            'timed_out',
            'provider_unavailable',
            'internal_safe_failure',
          }.contains(entry.key);
          final parsed =
              parseConversationCoachTransport(
                    jsonEncode(
                      _failurePayload(entry.key, retryable: retryable),
                    ),
                  )
                  as ConversationCoachRepositoryFailure;
          await pumpConvoCoach(
            tester,
            initialLocation: '/conversations/$_conversationId/coach-preview',
            conversationCoachEntryAvailable: true,
            conversationCoachRepository: _FakeCoachRepository(parsed),
          );
          expect(find.text(entry.value), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );

    testWidgets('is unavailable when local build configuration is off', (
      tester,
    ) async {
      await pumpConvoCoach(
        tester,
        initialLocation: '/conversations/$_conversationId/coach-preview',
        conversationCoachEntryAvailable: false,
      );

      expect(find.text('Preview unavailable'), findsOneWidget);
      expect(find.textContaining('disabled by default'), findsNothing);
    });

    testWidgets(
      'keeps loading, cancellation, empty, unsupported, and network states distinct',
      (tester) async {
        final pending = Completer<ConversationCoachRepositoryResult>();
        final router = createAppRouter(
          initialLocation: '/conversations/$_conversationId/coach-preview',
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hapticsProvider.overrideWithValue(const NoopAppHaptics()),
              conversationCoachEntryAvailableProvider.overrideWithValue(true),
              conversationCoachRepositoryProvider.overrideWithValue(
                _PendingCoachRepository(pending),
              ),
            ],
            child: ConvoCoachApp(router: router),
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('coach-preview-loading')), findsOneWidget);
        await tester.tap(find.text('Cancel preview'));
        await tester.pumpAndSettle();
        expect(find.text('Preview cancelled'), findsOneWidget);
        pending.complete(
          const ConversationCoachRepositoryFailure(
            ConversationCoachFailure(
              code: ConversationCoachErrorCode.cancelled,
              localizationKey: 'coaching.error.cancelled',
              retryable: true,
              retryGuidanceLocalizationKey: 'coaching.error.cancelled.retry',
              correlationId: 'local-cancelled',
            ),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());

        final empty = ConversationCoachRepositorySuccess(
          ConversationCoachPreview(
            responseId: '00000000-0000-4000-8000-000000000002',
            locale: 'en',
            calculationVersions: const ConversationCoachCalculationVersions(
              analyticsSchemaVersion: 'conversation-analytics.v1',
              analyticsCalculationVersion:
                  'deterministic-conversation-analytics.v1',
              sourceEventSchemaVersion: 'conversation-events.v1',
            ),
            sections: const [],
            notices: const [],
            correlationId: '00000000-0000-4000-8000-000000000003',
          ),
        );
        await pumpConvoCoach(
          tester,
          initialLocation: '/conversations/$_conversationId/coach-preview',
          conversationCoachEntryAvailable: true,
          conversationCoachRepository: _FakeCoachRepository(empty),
        );
        expect(find.text('No preview sections'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());

        await pumpConvoCoach(
          tester,
          initialLocation: '/conversations/$_conversationId/coach-preview',
          conversationCoachEntryAvailable: true,
          conversationCoachRepository: const _ThrowingCoachRepository(
            ConversationCoachTransportException(),
          ),
        );
        expect(find.text('Conversation version unsupported'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());

        await pumpConvoCoach(
          tester,
          initialLocation: '/conversations/$_conversationId/coach-preview',
          conversationCoachEntryAvailable: true,
          conversationCoachRepository: const _ThrowingCoachRepository(
            SocketException('synthetic offline'),
          ),
        );
        expect(find.text('You are offline'), findsOneWidget);
      },
    );

    testWidgets('supports large text without horizontal overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final parsed =
          parseConversationCoachTransport(jsonEncode(_successPayload()))
              as ConversationCoachRepositorySuccess;
      await pumpConvoCoach(
        tester,
        initialLocation: '/conversations/$_conversationId/coach-preview',
        conversationCoachEntryAvailable: true,
        conversationCoachRepository: _FakeCoachRepository(parsed),
      );
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
