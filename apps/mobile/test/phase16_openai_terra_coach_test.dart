import 'dart:convert';

import 'package:convo_coach/features/conversation_coach/data/conversation_coach_transport.dart';
import 'package:convo_coach/features/conversation_coach/domain/conversation_coach_preview.dart';
import 'package:convo_coach/features/conversation_coach/domain/conversation_coach_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

const _conversationId = '00000000-0000-4000-8000-000000000001';

Map<String, Object?> _livePayload() => {
  'schema_version': 'conversation-coach.v2',
  'execution_status': 'completed',
  'response_schema_version': 'terra-coach-output.v1',
  'response_id': '00000000-0000-4000-8000-000000000002',
  'locale': 'en',
  'summary': 'The exchange appears open, but the available context is limited.',
  'observations': [
    {
      'heading': 'Clear exchange',
      'observation': 'Both people contributed to the reviewed exchange.',
      'uncertainty':
          'Message participation alone does not establish romantic interest.',
      'alternative_interpretations': [
        'The exchange may be friendly.',
        'The exchange may be exploratory.',
      ],
      'evidence_event_ids': [
        '00000000-0000-4000-8000-000000001601',
        '00000000-0000-4000-8000-000000001602',
      ],
    },
  ],
  'next_steps': ['Ask an open question and leave room for a no.'],
  'reply_drafts': [
    {
      'text': 'I enjoyed chatting. Would you like to continue sometime?',
      'tone': 'warm and direct',
      'rationale': 'It expresses interest without pressure.',
    },
  ],
  'safety_notices': <Object?>[],
  'limitations': [
    'This is one possible interpretation, not a fact about intent.',
  ],
  'provenance': {
    'provider_identifier': 'openai-responses-gpt-5.6-terra.v1',
    'model': 'gpt-5.6-terra',
    'mock_execution': false,
    'response_stored_by_application': false,
  },
  'usage': {'input_tokens': 120, 'output_tokens': 80, 'total_tokens': 200},
  'allowance': {
    'schema_version': 'coach-allowance.v1',
    'server_version': 'subscription-runtime.v1',
    'plan_code': 'welcome',
    'plan_status': 'active',
    'allowance_kind': 'conversation_analysis',
    'limit': 5,
    'consumed': 1,
    'reserved': 0,
    'remaining': 4,
    'reset_at': '2026-08-26T10:00:00Z',
  },
  'correlation_id': '00000000-0000-4000-8000-000000000003',
};

Map<String, Object?> _glmPayload() {
  final payload = _livePayload();
  payload['response_schema_version'] = 'glm-coach-output.v1';
  payload['provenance'] = <String, Object?>{
    'provider_identifier': 'zai-chat-completions-glm-5.2.v1',
    'model': 'glm-5.2',
    'mock_execution': false,
    'response_stored_by_application': false,
  };
  return payload;
}

Map<String, Object?> _openRouterPayload({
  String model = 'openai/gpt-4o-mini',
  String planCode = 'welcome',
}) {
  final payload = _livePayload();
  payload['response_schema_version'] = 'openrouter-coach-output.v1';
  payload['provenance'] = <String, Object?>{
    'provider_identifier': 'openrouter-chat-completions-tiered.v1',
    'model': model,
    'mock_execution': false,
    'response_stored_by_application': false,
  };
  (payload['allowance']! as Map<String, Object?>)['plan_code'] = planCode;
  return payload;
}

ConversationCoachRepositoryResult _externalConsentRequired() =>
    const ConversationCoachRepositoryFailure(
      ConversationCoachFailure(
        code: ConversationCoachErrorCode.externalProcessingConsentRequired,
        localizationKey: 'coaching.error.external_processing_consent_required',
        retryable: false,
        retryGuidanceLocalizationKey: null,
        correlationId: '00000000-0000-4000-8000-000000000003',
      ),
    );

class _ConsentThenLiveRepository
    implements
        ConversationCoachRepository,
        ExternalProcessingConsentRepository,
        AIOutputReportingRepository {
  _ConsentThenLiveRepository({this.consentGranted = false});

  bool consentGranted;
  int grantCalls = 0;
  int reportCalls = 0;
  CoachOutputReportCategory? reportedCategory;

  @override
  Future<ConversationCoachRepositoryResult> fetchPreview(
    String conversationId, {
    required ConversationCoachCancellationToken cancellationToken,
  }) async {
    if (!consentGranted) return _externalConsentRequired();
    return parseConversationCoachTransport(jsonEncode(_livePayload()));
  }

  @override
  Future<bool> grantExternalProcessingConsent({
    required ConversationCoachCancellationToken cancellationToken,
  }) async {
    grantCalls += 1;
    consentGranted = true;
    return true;
  }

  @override
  Future<bool> reportOutput({
    required String conversationId,
    required String responseId,
    required CoachOutputReportCategory category,
    required ConversationCoachCancellationToken cancellationToken,
  }) async {
    expect(conversationId, _conversationId);
    expect(responseId, '00000000-0000-4000-8000-000000000002');
    reportCalls += 1;
    reportedCategory = category;
    return true;
  }
}

void main() {
  group('Phase 16 Terra transport', () {
    test('accepts only the exact validated live contract', () {
      final result = parseConversationCoachTransport(
        jsonEncode(_livePayload()),
      );

      expect(result, isA<ConversationCoachRepositorySuccess>());
      final preview = (result as ConversationCoachRepositorySuccess).preview;
      expect(preview.mockExecution, isFalse);
      expect(preview.providerLabel, 'GPT-5.6 Terra via OpenAI');
      expect(preview.inputTokens, 120);
      expect(preview.outputTokens, 80);
      expect(preview.planCode, 'welcome');
      expect(preview.allowanceLimit, 5);
      expect(preview.allowanceRemaining, 4);
      expect(preview.sections.map((section) => section.identifier), [
        'summary',
        'observations',
        'next_steps',
        'reply_drafts',
        'safety_notices',
        'limitations',
      ]);
      expect(
        preview.sections[1].displayItems!.single,
        contains('Uncertainty:'),
      );
    });

    test('rejects unknown fields, invalid provenance, and invalid usage', () {
      final extra = _livePayload()..['raw_provider_response'] = 'forbidden';
      final mock = _livePayload();
      (mock['provenance']! as Map<String, Object?>)['mock_execution'] = true;
      final usage = _livePayload();
      (usage['usage']! as Map<String, Object?>)['total_tokens'] = 10;

      for (final payload in [extra, mock, usage]) {
        expect(
          () => parseConversationCoachTransport(jsonEncode(payload)),
          throwsA(isA<ConversationCoachTransportException>()),
        );
      }
    });
  });

  group('Phase 18 GLM transport', () {
    test('accepts the exact Z.ai GLM schema and provenance triple', () {
      final result = parseConversationCoachTransport(jsonEncode(_glmPayload()));

      expect(result, isA<ConversationCoachRepositorySuccess>());
      final preview = (result as ConversationCoachRepositorySuccess).preview;
      expect(preview.providerLabel, 'GLM-5.2 via Z.ai');
      expect(preview.mockExecution, isFalse);
    });

    test('rejects mismatched GLM model, provider, or response schema', () {
      final wrongModel = _glmPayload();
      (wrongModel['provenance']! as Map<String, Object?>)['model'] =
          'gpt-5.6-terra';
      final wrongSchema = _glmPayload()
        ..['response_schema_version'] = 'terra-coach-output.v1';

      for (final payload in [wrongModel, wrongSchema]) {
        expect(
          () => parseConversationCoachTransport(jsonEncode(payload)),
          throwsA(isA<ConversationCoachTransportException>()),
        );
      }
    });
  });

  group('OpenRouter tiered transport', () {
    test('labels the configured free and paid models', () {
      final freeResult = parseConversationCoachTransport(
        jsonEncode(_openRouterPayload()),
      );
      final paidResult = parseConversationCoachTransport(
        jsonEncode(
          _openRouterPayload(model: 'openai/gpt-5.6-terra', planCode: 'plus'),
        ),
      );

      expect(
        (freeResult as ConversationCoachRepositorySuccess)
            .preview
            .providerLabel,
        'GPT-4o mini via OpenRouter',
      );
      expect(
        (paidResult as ConversationCoachRepositorySuccess)
            .preview
            .providerLabel,
        'GPT-5.6 Terra via OpenRouter',
      );
    });

    test('accepts a safe future model slug without a mobile release', () {
      final result = parseConversationCoachTransport(
        jsonEncode(_openRouterPayload(model: 'provider/future-model-v2')),
      );

      expect(
        (result as ConversationCoachRepositorySuccess).preview.providerLabel,
        'AI coaching via OpenRouter',
      );
    });

    test('rejects malformed model slugs and mismatched provenance', () {
      final malformed = _openRouterPayload(model: 'future-model');
      final wrongProvider = _openRouterPayload();
      (wrongProvider['provenance']!
              as Map<String, Object?>)['provider_identifier'] =
          'openai-responses-gpt-5.6-terra.v1';

      for (final payload in [malformed, wrongProvider]) {
        expect(
          () => parseConversationCoachTransport(jsonEncode(payload)),
          throwsA(isA<ConversationCoachTransportException>()),
        );
      }
    });
  });

  group('Phase 16 informed consent and presentation', () {
    testWidgets('records separate consent before rendering Terra coaching', (
      tester,
    ) async {
      final repository = _ConsentThenLiveRepository();
      await pumpConvoCoach(
        tester,
        initialLocation: '/conversations/$_conversationId/coach-preview',
        conversationCoachEntryAvailable: true,
        conversationCoachRepository: repository,
      );

      expect(find.byKey(const Key('external-ai-consent')), findsOneWidget);
      expect(find.text('Before external AI coaching'), findsOneWidget);
      expect(find.textContaining('through OpenRouter'), findsOneWidget);
      expect(
        find.textContaining('Free coaching uses GPT-4o mini'),
        findsOneWidget,
      );
      expect(find.textContaining('zero-data-retention'), findsOneWidget);
      expect(find.textContaining('Screenshot bytes'), findsOneWidget);
      expect(find.textContaining('account ID are not sent'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('I consent and want coaching'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('AI interpretations can be wrong'),
        findsOneWidget,
      );
      await tester.tap(find.text('I consent and want coaching'));
      await tester.pumpAndSettle();

      expect(repository.grantCalls, 1);
      expect(find.text('AI conversation coaching'), findsOneWidget);
      expect(find.textContaining('GPT-5.6 Terra via OpenAI'), findsOneWidget);
      expect(find.textContaining('The exchange appears open'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Uncertainty:'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Uncertainty:'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('I enjoyed chatting'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('I enjoyed chatting'), findsOneWidget);
      expect(find.textContaining('not a fact about intent'), findsOneWidget);
      expect(find.textContaining('Mock infrastructure'), findsNothing);
    });

    testWidgets('supports large text on the external-processing disclosure', (
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
      await pumpConvoCoach(
        tester,
        initialLocation: '/conversations/$_conversationId/coach-preview',
        conversationCoachEntryAvailable: true,
        conversationCoachRepository: _ConsentThenLiveRepository(),
      );

      expect(find.byKey(const Key('external-ai-consent')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports live AI output without attaching private content', (
      tester,
    ) async {
      final repository = _ConsentThenLiveRepository(consentGranted: true);
      await pumpConvoCoach(
        tester,
        initialLocation: '/conversations/$_conversationId/coach-preview',
        conversationCoachEntryAvailable: true,
        conversationCoachRepository: repository,
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('report-ai-output')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('report-ai-output')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('report-ai-output-sheet')), findsOneWidget);
      expect(find.textContaining('opaque response ID'), findsOneWidget);
      expect(
        find.textContaining('generated response are not included'),
        findsOneWidget,
      );
      await tester.tap(find.text('Harmful or unsafe'));
      await tester.pumpAndSettle();

      expect(repository.reportCalls, 1);
      expect(
        repository.reportedCategory,
        CoachOutputReportCategory.harmfulOrUnsafe,
      );
      expect(find.textContaining('Report received'), findsOneWidget);
    });
  });
}
