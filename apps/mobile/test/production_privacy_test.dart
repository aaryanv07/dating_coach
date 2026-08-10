import 'dart:io';

import 'package:convo_coach/core/widgets/app_privacy_shield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('private UI is covered whenever the application is inactive', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppPrivacyShield(child: Text('private conversation')),
      ),
    );

    expect(find.byKey(const Key('app-privacy-shield')), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.byKey(const Key('app-privacy-shield')), findsOneWidget);
    expect(
      find.bySemanticsLabel('ConvoCoach is hidden to protect your privacy'),
      findsOneWidget,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const Key('app-privacy-shield')), findsNothing);
  });

  test('native release privacy controls are present', () {
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final androidDebugManifest = File(
      'android/app/src/debug/AndroidManifest.xml',
    ).readAsStringSync();
    final iosManifest = File(
      'ios/Runner/PrivacyInfo.xcprivacy',
    ).readAsStringSync();
    final iosReleaseEntitlements = File(
      'ios/Runner/Release.entitlements',
    ).readAsStringSync();
    final iosDebugEntitlements = File(
      'ios/Runner/DebugProfile.entitlements',
    ).readAsStringSync();
    final iosLocalInfo = File('ios/Runner/Info-Debug.plist').readAsStringSync();
    final iosReleaseInfo = File('ios/Runner/Info.plist').readAsStringSync();
    final iosProject = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(androidManifest, contains('android:allowBackup="false"'));
    expect(androidManifest, contains('android:usesCleartextTraffic="false"'));
    expect(
      androidDebugManifest,
      contains('tools:replace="android:usesCleartextTraffic"'),
    );
    expect(
      androidDebugManifest,
      contains('android:usesCleartextTraffic="true"'),
    );
    expect(androidManifest, contains('@xml/data_extraction_rules'));
    expect(iosManifest, contains('<key>NSPrivacyTracking</key>'));
    expect(iosManifest, contains('<false/>'));
    expect(iosManifest, contains('NSPrivacyCollectedDataTypeOtherUserContent'));
    expect(
      iosReleaseEntitlements,
      contains('com.apple.developer.default-data-protection'),
    );
    expect(iosReleaseEntitlements, contains('NSFileProtectionComplete'));
    expect(
      iosDebugEntitlements,
      isNot(contains('com.apple.developer.default-data-protection')),
    );
    expect(iosLocalInfo, contains('NSAllowsLocalNetworking'));
    expect(iosLocalInfo, contains('ConvoCoach development server'));
    expect(iosReleaseInfo, isNot(contains('NSAllowsLocalNetworking')));
    expect(iosReleaseInfo, contains('NSPhotoLibraryUsageDescription'));
    expect(
      iosReleaseInfo,
      contains('conversation screenshots that you explicitly choose'),
    );
    expect(
      RegExp(
        r'249021D4217E4FDB00AE95B9 /\* Profile \*/ = \{[\s\S]*?'
        r'INFOPLIST_FILE = Runner/Info-Debug\.plist;',
      ).hasMatch(iosProject),
      isTrue,
    );
    expect(
      RegExp(
        r'97C147071CF9000F007C117D /\* Release \*/ = \{[\s\S]*?'
        r'INFOPLIST_FILE = Runner/Info\.plist;',
      ).hasMatch(iosProject),
      isTrue,
    );
  });

  test('App Store icon assets do not contain an alpha channel', () {
    final icons = Directory(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset',
    ).listSync().whereType<File>().where((file) => file.path.endsWith('.png'));

    expect(icons, isNotEmpty);
    for (final icon in icons) {
      final bytes = icon.readAsBytesSync();
      expect(bytes.length, greaterThan(25), reason: icon.path);
      expect(bytes.sublist(1, 4), <int>[0x50, 0x4e, 0x47], reason: icon.path);
      expect(bytes[25], isNot(anyOf(4, 6)), reason: icon.path);
    }
  });

  test('local device scripts prefer a bounded Bonjour hostname', () {
    final backendScript = File(
      '../../scripts/run_local_backend.zsh',
    ).readAsStringSync();
    final mobileScript = File(
      '../../scripts/run_local_mobile.zsh',
    ).readAsStringSync();

    for (final script in [backendScript, mobileScript]) {
      expect(script, contains('scutil --get LocalHostName'));
      expect(script, contains(r'^[A-Za-z0-9-]+$'));
      expect(script, contains(r'${LOCAL_HOST:l}'));
      expect(script, contains(r'$LOCAL_HOST.local'));
    }
    expect(backendScript, contains(r'ALLOWED_HOSTS='));
    expect(mobileScript, contains(r'API_HOST='));
    expect(mobileScript, contains('CONVOCOACH_API_BASE_URL'));
  });
}
