import 'dart:convert';

import 'fixture_models.dart';
import 'generated_fixture_catalog.dart';

class BenchmarkFixtureCatalog {
  const BenchmarkFixtureCatalog._();

  static List<String> get groundTruthPaths =>
      phase6aEmbeddedGroundTruth.keys.toList(growable: false);

  static Future<List<BenchmarkFixture>> load() async {
    final fixtures = <BenchmarkFixture>[];
    for (final entry in phase6aEmbeddedGroundTruth.entries) {
      final decoded = jsonDecode(entry.value);
      if (decoded is! Map) {
        throw FormatException(
          'Fixture ground truth ${entry.key} must contain an object.',
        );
      }
      fixtures.add(BenchmarkFixture.fromJson(decoded.cast<String, Object?>()));
    }
    return List.unmodifiable(fixtures);
  }
}
