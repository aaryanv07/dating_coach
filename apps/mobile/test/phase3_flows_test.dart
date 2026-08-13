import 'dart:async';

import 'package:convo_coach/features/communication_profile/application/communication_profile_controller.dart';
import 'package:convo_coach/features/communication_profile/domain/communication_profile.dart';
import 'package:convo_coach/features/communication_profile/domain/communication_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets(
    'first-login profile form renders while the API is still loading',
    (tester) async {
      final repository = _PendingCommunicationProfileRepository();
      await pumpConvoCoach(
        tester,
        initialLocation: '/profile/setup',
        overrides: [
          communicationProfileRepositoryProvider.overrideWithValue(repository),
        ],
        settle: false,
      );
      await tester.pump();

      expect(find.text('Set up your profile'), findsOneWidget);
      expect(find.text('Preferred name'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);
      expect(
        find.text(
          'Loading any saved details in the background. You can start now.',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).first, 'Typed now');
      repository.complete(
        const CommunicationProfile.empty().copyWith(
          preferredName: 'Loaded later',
        ),
      );
      await tester.pump();
      expect(find.text('Typed now'), findsOneWidget);
      expect(find.text('Loaded later'), findsNothing);
    },
  );

  testWidgets('profile hub opens and saves the communication profile', (
    tester,
  ) async {
    await pumpConvoCoach(tester, initialLocation: '/profile');

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.text('Tell us what feels natural to you.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Ari');
    expect(find.text('Job or occupation'), findsOneWidget);
    expect(find.text('Things you like'), findsOneWidget);
    expect(find.text('What you want'), findsOneWidget);
    final saveButton = find.text('Save profile');
    await tester.scrollUntilVisible(
      saveButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Profile saved.'), findsOneWidget);
  });

  testWidgets('first login requires adult profile basics before home', (
    tester,
  ) async {
    final router = await pumpConvoCoach(
      tester,
      initialLocation: '/profile/setup',
    );

    expect(find.text('Set up your profile'), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
    expect(find.text('Gender or self-description'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Ari');
    await tester.enterText(find.byType(TextField).at(1), '17');
    await tester.enterText(find.byType(TextField).at(4), 'music');
    final saveButton = find.text('Save profile');
    await tester.scrollUntilVisible(
      saveButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('ConvoCoach is only for adults 18+.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '24');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home');
  });

  testWidgets(
    'conversation list renders mock summaries and supports deletion',
    (tester) async {
      await pumpConvoCoach(tester, initialLocation: '/conversations');

      expect(find.text('Weekend plans'), findsOneWidget);
      expect(find.text('Sam · 18 messages'), findsOneWidget);
      expect(find.text('A synthetic hello.'), findsNothing);

      await tester.tap(find.byTooltip('Delete Weekend plans'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this conversation?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Weekend plans'), findsNothing);
      expect(find.text('Conversation deleted.'), findsOneWidget);
      expect(find.text('Coffee after work'), findsOneWidget);
    },
  );

  testWidgets(
    'Phase 3 flows remain usable with large text on a compact phone',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await pumpConvoCoach(tester, initialLocation: '/profile/edit');

      expect(find.text('Your profile'), findsOneWidget);
      expect(find.text('Tell us what feels natural to you.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _PendingCommunicationProfileRepository
    implements CommunicationProfileRepository {
  final Completer<CommunicationProfile> _fetch = Completer();

  void complete([
    CommunicationProfile profile = const CommunicationProfile.empty(),
  ]) {
    if (!_fetch.isCompleted) {
      _fetch.complete(profile);
    }
  }

  @override
  Future<CommunicationProfile> fetch() => _fetch.future;

  @override
  Future<CommunicationProfile> save(CommunicationProfile profile) async =>
      profile;

  @override
  Future<CommunicationProfile> updatePhoto(
    CommunicationProfile profile,
    List<int> bytes,
    String contentType,
  ) async => profile;

  @override
  Future<CommunicationProfile> deletePhoto(
    CommunicationProfile profile,
  ) async => profile;
}
