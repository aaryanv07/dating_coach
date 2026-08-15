import 'dart:convert';

import 'package:convo_coach/features/conversation_coach/domain/conversation_coach_preview.dart';

class ConversationCoachTransportException implements Exception {
  const ConversationCoachTransportException();
}

const _successKeys = {
  'schema_version',
  'execution_status',
  'response_schema_version',
  'renderer_schema_version',
  'response_id',
  'locale',
  'calculation_versions',
  'sections',
  'notices',
  'provenance',
  'correlation_id',
};
const _sectionKeys = {
  'schema_version',
  'identifier',
  'heading_localization_key',
  'semantic_label_localization_key',
  'status',
  'item_localization_keys',
  'evidence_reference_count',
};
const _calculationKeys = {
  'analytics_schema_version',
  'analytics_calculation_version',
  'source_event_schema_version',
};
const _provenanceKeys = {
  'provider_identifier',
  'generator_identifier',
  'mock_execution',
};
const _failureKeys = {'schema_version', 'error'};
const _errorKeys = {
  'error_id',
  'code',
  'localization_key',
  'retryable',
  'retry_guidance_localization_key',
  'correlation_id',
};
const _liveSuccessKeys = {
  'schema_version',
  'execution_status',
  'response_schema_version',
  'response_id',
  'locale',
  'summary',
  'observations',
  'next_steps',
  'reply_drafts',
  'safety_notices',
  'limitations',
  'provenance',
  'usage',
  'allowance',
  'correlation_id',
};
const _liveObservationKeys = {
  'heading',
  'observation',
  'uncertainty',
  'alternative_interpretations',
  'evidence_event_ids',
};
const _liveReplyDraftKeys = {'text', 'tone', 'rationale'};
const _liveProvenanceKeys = {
  'provider_identifier',
  'model',
  'mock_execution',
  'response_stored_by_application',
};
const _liveUsageKeys = {'input_tokens', 'output_tokens', 'total_tokens'};
const _liveAllowanceKeys = {
  'schema_version',
  'server_version',
  'plan_code',
  'plan_status',
  'allowance_kind',
  'limit',
  'consumed',
  'reserved',
  'remaining',
  'reset_at',
};
const _sectionIdentifiers = [
  'supported_capabilities',
  'unavailable_capabilities',
  'explanations',
  'safety_notices',
];
const _localizationKeys = {
  'coaching.section.supported.heading',
  'coaching.section.supported.semantic',
  'coaching.section.unavailable.heading',
  'coaching.section.unavailable.semantic',
  'coaching.section.explanations.heading',
  'coaching.section.explanations.semantic',
  'coaching.section.safety.heading',
  'coaching.section.safety.semantic',
  'coaching.capability.response_schema',
  'coaching.capability.evidence_references',
  'coaching.capability.explanation_placeholders',
  'coaching.capability.safety_notices',
  'coaching.capability.coaching_guidance.unavailable',
  'coaching.capability.recommendations.unavailable',
  'coaching.capability.reply_drafting.unavailable',
  'coaching.capability.first_message_drafting.unavailable',
  'coaching.capability.communication_dna.unavailable',
  'coaching.capability.relationship_scoring.unavailable',
  'coaching.capability.compatibility_scoring.unavailable',
  'coaching.foundation.placeholder',
  'coaching.foundation.no_coaching_generated',
  'coaching.foundation.mock_only',
};

ConversationCoachRepositoryResult parseConversationCoachTransport(
  String source,
) {
  try {
    final decoded = jsonDecode(source);
    final root = _object(decoded);
    if (root['schema_version'] == 'conversation-coach-preview-error.v1') {
      return ConversationCoachRepositoryFailure(_parseFailure(root));
    }
    if (root['schema_version'] == 'conversation-coach.v2') {
      return ConversationCoachRepositorySuccess(_parseLiveSuccess(root));
    }
    return ConversationCoachRepositorySuccess(_parseSuccess(root));
  } on ConversationCoachTransportException {
    rethrow;
  } on Object {
    throw const ConversationCoachTransportException();
  }
}

ConversationCoachPreview _parseSuccess(Map<String, Object?> root) {
  _exactKeys(root, _successKeys);
  _expect(root, 'schema_version', conversationCoachPreviewSchemaVersion);
  _expect(root, 'execution_status', 'completed');
  _expect(
    root,
    'response_schema_version',
    conversationCoachResponseSchemaVersion,
  );
  _expect(
    root,
    'renderer_schema_version',
    conversationCoachRendererSchemaVersion,
  );
  _expect(root, 'locale', 'en');
  final responseId = _identifier(root['response_id']);
  final correlationId = _identifier(root['correlation_id']);

  final calculation = _object(root['calculation_versions']);
  _exactKeys(calculation, _calculationKeys);
  _expect(calculation, 'analytics_schema_version', 'conversation-analytics.v1');
  _expect(
    calculation,
    'analytics_calculation_version',
    'deterministic-conversation-analytics.v1',
  );
  _expect(calculation, 'source_event_schema_version', 'conversation-events.v1');

  final provenance = _object(root['provenance']);
  _exactKeys(provenance, _provenanceKeys);
  _expect(provenance, 'provider_identifier', 'mock-ai-provider.v1');
  _expect(
    provenance,
    'generator_identifier',
    'deterministic-coaching-response-mock.v1',
  );
  _expect(provenance, 'mock_execution', true);

  final rawSections = _list(root['sections']);
  if (rawSections.length != _sectionIdentifiers.length) {
    throw const ConversationCoachTransportException();
  }
  final sections = <ConversationCoachSection>[];
  for (var index = 0; index < rawSections.length; index++) {
    final section = _object(rawSections[index]);
    _exactKeys(section, _sectionKeys);
    _expect(section, 'schema_version', 'conversation-coach-preview-section.v1');
    _expect(section, 'identifier', _sectionIdentifiers[index]);
    final headingKey = _localized(section['heading_localization_key']);
    final semanticKey = _localized(section['semantic_label_localization_key']);
    final itemKeys = _list(
      section['item_localization_keys'],
    ).map(_localized).toList(growable: false);
    final count = section['evidence_reference_count'];
    if (count is! int || count < 0) {
      throw const ConversationCoachTransportException();
    }
    sections.add(
      ConversationCoachSection(
        identifier: _sectionIdentifiers[index],
        headingLocalizationKey: headingKey,
        semanticLabelLocalizationKey: semanticKey,
        status: switch (_string(section['status'])) {
          'available' => ConversationCoachSectionStatus.available,
          'unavailable' => ConversationCoachSectionStatus.unavailable,
          'notice' => ConversationCoachSectionStatus.notice,
          _ => throw const ConversationCoachTransportException(),
        },
        itemLocalizationKeys: itemKeys,
        evidenceReferenceCount: count,
      ),
    );
  }
  final notices = _list(
    root['notices'],
  ).map(_localized).toList(growable: false);
  return ConversationCoachPreview(
    responseId: responseId,
    locale: 'en',
    calculationVersions: ConversationCoachCalculationVersions(
      analyticsSchemaVersion: 'conversation-analytics.v1',
      analyticsCalculationVersion: 'deterministic-conversation-analytics.v1',
      sourceEventSchemaVersion: 'conversation-events.v1',
    ),
    sections: sections,
    notices: notices,
    correlationId: correlationId,
  );
}

ConversationCoachPreview _parseLiveSuccess(Map<String, Object?> root) {
  _exactKeys(root, _liveSuccessKeys);
  _expect(root, 'schema_version', 'conversation-coach.v2');
  _expect(root, 'execution_status', 'completed');
  final responseSchemaVersion = _string(root['response_schema_version']);
  _expect(root, 'locale', 'en');
  final responseId = _identifier(root['response_id']);
  final correlationId = _identifier(root['correlation_id']);

  final provenance = _object(root['provenance']);
  _exactKeys(provenance, _liveProvenanceKeys);
  final providerIdentifier = _string(provenance['provider_identifier']);
  final model = _string(provenance['model']);
  final providerLabel = switch ((
    responseSchemaVersion,
    providerIdentifier,
    model,
  )) {
    (
      'terra-coach-output.v1',
      'openai-responses-gpt-5.6-terra.v1',
      'gpt-5.6-terra',
    ) =>
      'GPT-5.6 Terra via OpenAI',
    ('glm-coach-output.v1', 'zai-chat-completions-glm-5.2.v1', 'glm-5.2') =>
      'GLM-5.2 via Z.ai',
    ('openrouter-coach-output.v1', 'openrouter-chat-completions-tiered.v1', _)
        when _isOpenRouterModel(model) =>
      switch (model) {
        'openai/gpt-4o-mini' => 'GPT-4o mini via OpenRouter',
        'openai/gpt-5.6-terra' => 'GPT-5.6 Terra via OpenRouter',
        _ => 'AI coaching via OpenRouter',
      },
    _ => throw const ConversationCoachTransportException(),
  };
  _expect(provenance, 'mock_execution', false);
  _expect(provenance, 'response_stored_by_application', false);

  final usage = _object(root['usage']);
  _exactKeys(usage, _liveUsageKeys);
  final inputTokens = _nonNegativeInteger(usage['input_tokens']);
  final outputTokens = _nonNegativeInteger(usage['output_tokens']);
  final totalTokens = _nonNegativeInteger(usage['total_tokens']);
  if (inputTokens + outputTokens > totalTokens) {
    throw const ConversationCoachTransportException();
  }

  final allowance = _object(root['allowance']);
  _exactKeys(allowance, _liveAllowanceKeys);
  _expect(allowance, 'schema_version', 'coach-allowance.v1');
  _expect(allowance, 'server_version', 'subscription-runtime.v1');
  _expect(allowance, 'allowance_kind', 'conversation_analysis');
  final planCode = _string(allowance['plan_code']);
  if (!const {'welcome', 'free', 'plus'}.contains(planCode)) {
    throw const ConversationCoachTransportException();
  }
  final planStatus = _string(allowance['plan_status']);
  if (!const {'active', 'grace'}.contains(planStatus)) {
    throw const ConversationCoachTransportException();
  }
  final limit = _nonNegativeInteger(allowance['limit']);
  final consumed = _nonNegativeInteger(allowance['consumed']);
  final reserved = _nonNegativeInteger(allowance['reserved']);
  final remaining = _nonNegativeInteger(allowance['remaining']);
  if (limit == 0 || consumed + reserved + remaining != limit) {
    throw const ConversationCoachTransportException();
  }
  final resetAt = DateTime.tryParse(_string(allowance['reset_at']))?.toUtc();
  if (resetAt == null) throw const ConversationCoachTransportException();

  final observations = _list(root['observations']);
  if (observations.isEmpty || observations.length > 5) {
    throw const ConversationCoachTransportException();
  }
  final observationItems = <String>[];
  var evidenceReferenceCount = 0;
  for (final value in observations) {
    final observation = _object(value);
    _exactKeys(observation, _liveObservationKeys);
    final heading = _boundedText(observation['heading'], 100);
    final body = _boundedText(observation['observation'], 700);
    final uncertainty = _boundedText(observation['uncertainty'], 400);
    final alternatives = _textList(
      observation['alternative_interpretations'],
      minimum: 1,
      maximum: 3,
      maximumItemLength: 300,
    );
    final evidenceIds = _list(observation['evidence_event_ids']);
    if (evidenceIds.isEmpty || evidenceIds.length > 8) {
      throw const ConversationCoachTransportException();
    }
    final identifiers = evidenceIds.map(_identifier).toSet();
    if (identifiers.length != evidenceIds.length) {
      throw const ConversationCoachTransportException();
    }
    evidenceReferenceCount += identifiers.length;
    observationItems.add(
      '$heading\n$body\nUncertainty: $uncertainty\n'
      'Other possibilities: ${alternatives.join(' • ')}',
    );
  }

  final drafts = _list(root['reply_drafts']);
  if (drafts.length > 3) throw const ConversationCoachTransportException();
  final draftItems = <String>[];
  for (final value in drafts) {
    final draft = _object(value);
    _exactKeys(draft, _liveReplyDraftKeys);
    draftItems.add(
      '${_boundedText(draft['text'], 500)}\n'
      'Tone: ${_boundedText(draft['tone'], 80)}\n'
      'Why: ${_boundedText(draft['rationale'], 300)}',
    );
  }

  final nextSteps = _textList(
    root['next_steps'],
    minimum: 1,
    maximum: 5,
    maximumItemLength: 350,
  );
  final safetyNotices = _textList(
    root['safety_notices'],
    minimum: 0,
    maximum: 4,
    maximumItemLength: 350,
  );
  final limitations = _textList(
    root['limitations'],
    minimum: 1,
    maximum: 7,
    maximumItemLength: 350,
  );

  return ConversationCoachPreview(
    responseId: responseId,
    locale: 'en',
    sections: [
      _liveSection(
        identifier: 'summary',
        heading: 'Summary',
        semanticLabel: 'AI-generated coaching summary',
        items: [_boundedText(root['summary'], 900)],
      ),
      _liveSection(
        identifier: 'observations',
        heading: 'What stands out',
        semanticLabel: 'Evidence-linked observations with uncertainty',
        items: observationItems,
        evidenceCount: evidenceReferenceCount,
      ),
      _liveSection(
        identifier: 'next_steps',
        heading: 'Possible next steps',
        semanticLabel: 'Optional communication next steps',
        items: nextSteps,
      ),
      _liveSection(
        identifier: 'reply_drafts',
        heading: 'Drafts to review',
        semanticLabel: 'AI-generated reply drafts requiring user review',
        items: draftItems,
      ),
      _liveSection(
        identifier: 'safety_notices',
        heading: 'Safety and boundaries',
        semanticLabel: 'Safety and boundary guidance',
        items: safetyNotices,
        status: ConversationCoachSectionStatus.notice,
      ),
      _liveSection(
        identifier: 'limitations',
        heading: 'Limitations',
        semanticLabel: 'Important limitations and uncertainty',
        items: limitations,
        status: ConversationCoachSectionStatus.notice,
      ),
    ],
    notices: const [
      'AI-generated coaching can be wrong. Review every interpretation and draft.',
    ],
    correlationId: correlationId,
    mockExecution: false,
    providerLabel: providerLabel,
    inputTokens: inputTokens,
    outputTokens: outputTokens,
    planCode: planCode,
    allowanceLimit: limit,
    allowanceRemaining: remaining,
    allowanceResetAt: resetAt,
  );
}

bool _isOpenRouterModel(String value) =>
    RegExp(r'^[A-Za-z0-9._~:-]+/[A-Za-z0-9._~:-]+$').hasMatch(value) &&
    value.length <= 96;

ConversationCoachSection _liveSection({
  required String identifier,
  required String heading,
  required String semanticLabel,
  required List<String> items,
  ConversationCoachSectionStatus status =
      ConversationCoachSectionStatus.available,
  int evidenceCount = 0,
}) => ConversationCoachSection(
  identifier: identifier,
  headingLocalizationKey: heading,
  semanticLabelLocalizationKey: semanticLabel,
  status: status,
  itemLocalizationKeys: const [],
  displayItems: items,
  evidenceReferenceCount: evidenceCount,
);

ConversationCoachFailure _parseFailure(Map<String, Object?> root) {
  _exactKeys(root, _failureKeys);
  _expect(root, 'schema_version', 'conversation-coach-preview-error.v1');
  final error = _object(root['error']);
  _exactKeys(error, _errorKeys);
  final codeValue = _string(error['code']);
  final code = _errorCode(codeValue);
  _expect(error, 'error_id', 'coach-preview:$codeValue');
  _expect(error, 'localization_key', 'coaching.error.$codeValue');
  final retryable = error['retryable'];
  if (retryable is! bool) {
    throw const ConversationCoachTransportException();
  }
  final retryKey = error['retry_guidance_localization_key'];
  if (retryKey != null && retryKey is! String) {
    throw const ConversationCoachTransportException();
  }
  final expectedRetryKey = retryable ? 'coaching.error.$codeValue.retry' : null;
  if (retryKey != expectedRetryKey) {
    throw const ConversationCoachTransportException();
  }
  return ConversationCoachFailure(
    code: code,
    localizationKey: 'coaching.error.$codeValue',
    retryable: retryable,
    retryGuidanceLocalizationKey: retryKey as String?,
    correlationId: _identifier(error['correlation_id']),
  );
}

ConversationCoachErrorCode _errorCode(String value) => switch (value) {
  'feature_disabled' => ConversationCoachErrorCode.featureDisabled,
  'mock_disabled' => ConversationCoachErrorCode.mockDisabled,
  'authentication_required' =>
    ConversationCoachErrorCode.authenticationRequired,
  'authorization_failed' => ConversationCoachErrorCode.authorizationFailed,
  'consent_required' => ConversationCoachErrorCode.consentRequired,
  'external_processing_consent_required' =>
    ConversationCoachErrorCode.externalProcessingConsentRequired,
  'conversation_unavailable' =>
    ConversationCoachErrorCode.conversationUnavailable,
  'review_incomplete' => ConversationCoachErrorCode.reviewIncomplete,
  'schema_unsupported' => ConversationCoachErrorCode.schemaUnsupported,
  'incomplete_timeline' => ConversationCoachErrorCode.incompleteTimeline,
  'safety_rejected' => ConversationCoachErrorCode.safetyRejected,
  'cancelled' => ConversationCoachErrorCode.cancelled,
  'timed_out' => ConversationCoachErrorCode.timedOut,
  'provider_unavailable' => ConversationCoachErrorCode.providerUnavailable,
  'response_validation_failed' =>
    ConversationCoachErrorCode.responseValidationFailed,
  'capability_unsupported' => ConversationCoachErrorCode.capabilityUnsupported,
  'idempotency_required' => ConversationCoachErrorCode.idempotencyRequired,
  'idempotency_conflict' => ConversationCoachErrorCode.idempotencyConflict,
  'idempotency_in_progress' => ConversationCoachErrorCode.idempotencyInProgress,
  'idempotency_replayed' => ConversationCoachErrorCode.idempotencyReplayed,
  'allowance_exhausted' => ConversationCoachErrorCode.allowanceExhausted,
  'rate_limited' => ConversationCoachErrorCode.rateLimited,
  'budget_exhausted' => ConversationCoachErrorCode.budgetExhausted,
  'usage_unavailable' => ConversationCoachErrorCode.usageUnavailable,
  'internal_safe_failure' => ConversationCoachErrorCode.internalSafeFailure,
  _ => throw const ConversationCoachTransportException(),
};

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const ConversationCoachTransportException();
  }
  return value;
}

List<Object?> _list(Object? value) {
  if (value is! List<Object?>) {
    throw const ConversationCoachTransportException();
  }
  return value;
}

String _string(Object? value) {
  if (value is! String || value.isEmpty) {
    throw const ConversationCoachTransportException();
  }
  return value;
}

String _boundedText(Object? value, int maximumLength) {
  final text = _string(value).trim();
  if (text.isEmpty || text.length > maximumLength) {
    throw const ConversationCoachTransportException();
  }
  return text;
}

List<String> _textList(
  Object? value, {
  required int minimum,
  required int maximum,
  required int maximumItemLength,
}) {
  final values = _list(value);
  if (values.length < minimum || values.length > maximum) {
    throw const ConversationCoachTransportException();
  }
  return values
      .map((item) => _boundedText(item, maximumItemLength))
      .toList(growable: false);
}

int _nonNegativeInteger(Object? value) {
  if (value is! int || value < 0) {
    throw const ConversationCoachTransportException();
  }
  return value;
}

String _identifier(Object? value) {
  final identifier = _string(value);
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  ).hasMatch(identifier)) {
    throw const ConversationCoachTransportException();
  }
  return identifier;
}

String _localized(Object? value) {
  final key = _string(value);
  if (!_localizationKeys.contains(key)) {
    throw const ConversationCoachTransportException();
  }
  return key;
}

void _expect(Map<String, Object?> source, String key, Object expected) {
  if (source[key] != expected) {
    throw const ConversationCoachTransportException();
  }
}

void _exactKeys(Map<String, Object?> source, Set<String> expected) {
  if (source.length != expected.length ||
      !source.keys.every(expected.contains)) {
    throw const ConversationCoachTransportException();
  }
}
