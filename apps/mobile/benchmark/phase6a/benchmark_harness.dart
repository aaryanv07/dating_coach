import 'dart:async';
import 'dart:io';

import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/ocr_engine.dart';

import 'benchmark_metrics.dart';
import 'benchmark_report.dart';
import 'benchmark_session.dart';
import 'fixture_models.dart';
import 'fixture_renderer.dart';

typedef BenchmarkEngineFactory =
    OcrEngine Function(GeneratedBenchmarkFixture fixture);

class ExtractionBenchmarkHarness {
  const ExtractionBenchmarkHarness({
    this.renderer = const SyntheticScreenshotFixtureRenderer(),
    this.evaluator = const ExtractionBenchmarkEvaluator(),
  });

  final SyntheticScreenshotFixtureRenderer renderer;
  final ExtractionBenchmarkEvaluator evaluator;

  Future<BenchmarkSuiteReport> run({
    required List<BenchmarkFixture> fixtures,
    required BenchmarkEngineFactory engineFactory,
    required BenchmarkSessionEnvironment sessionEnvironment,
    required bool nativeDeviceRun,
  }) async {
    if (fixtures.isEmpty) {
      throw ArgumentError.value(fixtures, 'fixtures', 'must not be empty');
    }
    final recorder = BenchmarkSessionRecorder.start(sessionEnvironment);
    final cancellationProbePassed = await _runCancellationProbe(
      fixtures.first,
      engineFactory,
    );
    final results = <BenchmarkCaseResult>[];
    for (final fixture in fixtures) {
      results.add(await _runCase(fixture, engineFactory));
    }
    final session = recorder.complete(
      failureCount: results
          .where((result) => result.status == BenchmarkCaseStatus.failed)
          .length,
      cancelledCaseCount: results
          .where((result) => result.status == BenchmarkCaseStatus.cancelled)
          .length,
      peakRssBytes: _maximumMeasured(
        results.map((result) => result.peakRssBytes),
      ),
      peakRssDeltaBytes: _maximumMeasured(
        results.map((result) => result.peakRssDeltaBytes),
      ),
      cancellationProbePassed: cancellationProbePassed,
    );
    return BenchmarkSuiteReport(
      generatedAt: session.completedAt,
      session: session,
      nativeDeviceRun: nativeDeviceRun,
      cancellationProbePassed: cancellationProbePassed,
      cases: List.unmodifiable(results),
    );
  }

  Future<BenchmarkCaseResult> _runCase(
    BenchmarkFixture fixture,
    BenchmarkEngineFactory engineFactory,
  ) async {
    GeneratedBenchmarkFixture? generated;
    BenchmarkCaseResult? result;
    try {
      generated = await renderer.generate(fixture);
      final engine = engineFactory(generated);
      final memory = _PeakMemorySampler()..start();
      final stopwatch = Stopwatch()..start();
      try {
        final extraction = await engine.extract(
          generated.sources,
          locale: _localeFor(fixture.language),
          onProgress: (_) {},
          cancellationToken: ExtractionCancellationToken(),
        );
        stopwatch.stop();
        memory.stop();
        result = BenchmarkCaseResult(
          fixtureId: fixture.id,
          inspiration: fixture.inspiration,
          traits: fixture.traits,
          imageCount: fixture.pages.length,
          expectedMessageCount: fixture.messages.length,
          status: BenchmarkCaseStatus.completed,
          latencyMilliseconds: stopwatch.elapsedMilliseconds,
          peakRssBytes: memory.peakBytes,
          peakRssDeltaBytes: memory.deltaBytes,
          cleanupSucceeded: false,
          provider: extraction.metadata.provider,
          providerVersion: extraction.metadata.providerVersion,
          confidenceAvailable: extraction.metadata.confidenceAvailable,
          metrics: evaluator.evaluate(fixture, extraction),
        );
      } on ExtractionCancelledException {
        stopwatch.stop();
        memory.stop();
        result = BenchmarkCaseResult(
          fixtureId: fixture.id,
          inspiration: fixture.inspiration,
          traits: fixture.traits,
          imageCount: fixture.pages.length,
          expectedMessageCount: fixture.messages.length,
          status: BenchmarkCaseStatus.cancelled,
          latencyMilliseconds: stopwatch.elapsedMilliseconds,
          peakRssBytes: memory.peakBytes,
          peakRssDeltaBytes: memory.deltaBytes,
          cleanupSucceeded: false,
          provider: engine.providerId,
          providerVersion: engine.providerVersion,
          confidenceAvailable: false,
          failureCategory: 'cancelled',
        );
      } on Object catch (error) {
        stopwatch.stop();
        memory.stop();
        result = BenchmarkCaseResult(
          fixtureId: fixture.id,
          inspiration: fixture.inspiration,
          traits: fixture.traits,
          imageCount: fixture.pages.length,
          expectedMessageCount: fixture.messages.length,
          status: BenchmarkCaseStatus.failed,
          latencyMilliseconds: stopwatch.elapsedMilliseconds,
          peakRssBytes: memory.peakBytes,
          peakRssDeltaBytes: memory.deltaBytes,
          cleanupSucceeded: false,
          provider: engine.providerId,
          providerVersion: engine.providerVersion,
          confidenceAvailable: false,
          failureCategory: error.runtimeType.toString(),
        );
      }
    } on Object catch (error) {
      result = BenchmarkCaseResult(
        fixtureId: fixture.id,
        inspiration: fixture.inspiration,
        traits: fixture.traits,
        imageCount: fixture.pages.length,
        expectedMessageCount: fixture.messages.length,
        status: BenchmarkCaseStatus.failed,
        latencyMilliseconds: 0,
        peakRssBytes: null,
        peakRssDeltaBytes: null,
        cleanupSucceeded: false,
        provider: 'not_started',
        providerVersion: 'not_started',
        confidenceAvailable: false,
        failureCategory: error.runtimeType.toString(),
      );
    } finally {
      await generated?.dispose();
    }
    final cleaned = generated == null || !await generated.workspace.exists();
    return result.copyWithCleanup(cleaned);
  }

  Future<bool> _runCancellationProbe(
    BenchmarkFixture fixture,
    BenchmarkEngineFactory engineFactory,
  ) async {
    GeneratedBenchmarkFixture? generated;
    var cancelled = false;
    try {
      generated = await renderer.generate(fixture);
      final token = ExtractionCancellationToken()..cancel();
      try {
        await engineFactory(generated).extract(
          generated.sources,
          locale: _localeFor(fixture.language),
          onProgress: (_) {},
          cancellationToken: token,
        );
      } on ExtractionCancelledException {
        cancelled = true;
      }
    } on Object {
      cancelled = false;
    } finally {
      await generated?.dispose();
    }
    return cancelled &&
        (generated == null || !await generated.workspace.exists());
  }

  String _localeFor(String language) => switch (language) {
    'english' => 'en_IN',
    'hinglish' || 'roman_hindi' => 'en_IN',
    _ => 'en_IN',
  };
}

int? _maximumMeasured(Iterable<int?> values) {
  int? maximum;
  for (final value in values.whereType<int>()) {
    if (maximum == null || value > maximum) maximum = value;
  }
  return maximum;
}

class _PeakMemorySampler {
  int? _baseline;
  int? _peak;
  Timer? _timer;

  int? get peakBytes => _peak;
  int? get deltaBytes => _baseline == null || _peak == null
      ? null
      : (_peak! - _baseline!).clamp(0, _peak!);

  void start() {
    _sample();
    _timer = Timer.periodic(const Duration(milliseconds: 10), (_) => _sample());
  }

  void stop() {
    _sample();
    _timer?.cancel();
  }

  void _sample() {
    try {
      final value = ProcessInfo.currentRss;
      _baseline ??= value;
      if (_peak == null || value > _peak!) _peak = value;
    } on Object {
      _timer?.cancel();
      _baseline = null;
      _peak = null;
    }
  }
}
