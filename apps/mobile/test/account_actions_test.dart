import 'dart:io';

import 'package:convo_coach/features/authentication/domain/authentication_contracts.dart';
import 'package:convo_coach/features/progress/domain/progress_journal.dart';
import 'package:convo_coach/features/progress/domain/progress_journal_repository.dart';
import 'package:convo_coach/features/settings/application/account_actions.dart';
import 'package:convo_coach/features/settings/application/account_export_sharer.dart';
import 'package:convo_coach/features/settings/data/http_account_privacy_repository.dart';
import 'package:convo_coach/features/settings/domain/account_privacy_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account export transport is authenticated and non-cacheable', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final repository = HttpAccountPrivacyRepository(
      baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      accessTokenProvider: () async => 'synthetic-token',
    );

    final export = repository.exportAccountData();
    final request = await server.first;
    expect(request.method, 'GET');
    expect(request.uri.path, '/api/v1/privacy/export');
    expect(
      request.headers.value(HttpHeaders.authorizationHeader),
      'Bearer synthetic-token',
    );
    expect(request.headers.value(HttpHeaders.cacheControlHeader), 'no-store');
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      '{"schema_version":"account-export.v1","data":{"conversations":[]}}',
    );
    await request.response.close();

    expect(await export, contains('account-export.v1'));
  });

  test(
    'account deletion transport is authenticated and owner-scoped',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final repository = HttpAccountPrivacyRepository(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        accessTokenProvider: () async => 'synthetic-token',
      );

      final deletion = repository.requestAccountDeletion();
      final request = await server.first;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/privacy/delete-account');
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Bearer synthetic-token',
      );
      expect(request.headers.value(HttpHeaders.cacheControlHeader), 'no-store');
      request.response.statusCode = HttpStatus.accepted;
      await request.response.close();

      await expectLater(deletion, completes);
    },
  );

  test(
    'account deletion transport fails before network without a token',
    () async {
      final repository = HttpAccountPrivacyRepository(
        baseUri: Uri.parse('https://api.example.invalid'),
        accessTokenProvider: () async => null,
      );

      await expectLater(
        repository.requestAccountDeletion(),
        throwsA(
          isA<AccountPrivacyException>().having(
            (error) => error.code,
            'code',
            'authentication_required',
          ),
        ),
      );
      await expectLater(
        repository.exportAccountData(),
        throwsA(
          isA<AccountPrivacyException>().having(
            (error) => error.code,
            'code',
            'authentication_required',
          ),
        ),
      );
    },
  );

  test(
    'temporary account export is deleted after the share sheet returns',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'convocoach-export-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      String? sharedPath;
      String? sharedContents;
      final sharer = AccountExportSharer(
        temporaryDirectoryProvider: () async => directory,
        shareInvoker: (params) async {
          sharedPath = params.files!.single.path;
          sharedContents = await File(sharedPath!).readAsString();
        },
      );

      await sharer.share('{"schema_version":"account-export.v1"}');

      expect(sharedContents, contains('account-export.v1'));
      expect(sharedPath, isNotNull);
      expect(await File(sharedPath!).exists(), isFalse);
    },
  );

  test(
    'sign out clears protected local progress before ending the session',
    () async {
      final journal = MemoryProgressJournalRepository(
        ProgressJournal(privateReflection: 'private note'),
      );
      final authentication = _RecordingAuthenticationGateway();
      final actions = AccountActions(
        authentication: authentication,
        progressJournal: journal,
        accountPrivacy: _RecordingAccountPrivacyRepository(),
      );

      expect(await actions.signOut(), isTrue);
      expect((await journal.load()).privateReflection, isEmpty);
      expect(authentication.signOutCount, 1);
    },
  );

  test('confirmed server deletion also clears local protected data', () async {
    final journal = MemoryProgressJournalRepository(
      ProgressJournal(privateReflection: 'private note'),
    );
    final authentication = _RecordingAuthenticationGateway();
    final privacy = _RecordingAccountPrivacyRepository();
    final actions = AccountActions(
      authentication: authentication,
      progressJournal: journal,
      accountPrivacy: privacy,
    );

    expect(await actions.deleteAccount(), isTrue);
    expect(privacy.deleteCount, 1);
    expect((await journal.load()).privateReflection, isEmpty);
    expect(authentication.signOutCount, 1);
  });

  test(
    'account export is prepared without signing out or clearing data',
    () async {
      final journal = MemoryProgressJournalRepository(
        ProgressJournal(privateReflection: 'keep me'),
      );
      final authentication = _RecordingAuthenticationGateway();
      final privacy = _RecordingAccountPrivacyRepository();
      final actions = AccountActions(
        authentication: authentication,
        progressJournal: journal,
        accountPrivacy: privacy,
      );

      expect(await actions.exportAccount(), contains('account-export.v1'));
      expect(privacy.exportCount, 1);
      expect((await journal.load()).privateReflection, 'keep me');
      expect(authentication.signOutCount, 0);
    },
  );

  test('failed server deletion preserves the session and local data', () async {
    final journal = MemoryProgressJournalRepository(
      ProgressJournal(privateReflection: 'keep me'),
    );
    final authentication = _RecordingAuthenticationGateway();
    final actions = AccountActions(
      authentication: authentication,
      progressJournal: journal,
      accountPrivacy: _RecordingAccountPrivacyRepository(fail: true),
    );

    expect(await actions.deleteAccount(), isFalse);
    expect((await journal.load()).privateReflection, 'keep me');
    expect(authentication.signOutCount, 0);
  });
}

class _RecordingAuthenticationGateway implements MobileAuthenticationGateway {
  int signOutCount = 0;

  @override
  Future<MobileAuthenticationResult> signIn(
    MobileAuthenticationMethod method,
  ) async => const MobileAuthenticationRejected('not_used');

  @override
  Future<void> signOut() async {
    signOutCount += 1;
  }

  @override
  Stream<MobileAuthenticationSession> watchSession() =>
      Stream.value(const MobileAuthenticationSession.signedOut());
}

class _RecordingAccountPrivacyRepository implements AccountPrivacyRepository {
  _RecordingAccountPrivacyRepository({this.fail = false});

  final bool fail;
  int deleteCount = 0;
  int exportCount = 0;

  @override
  Future<String> exportAccountData() async {
    exportCount += 1;
    if (fail) throw StateError('synthetic failure');
    return '{"schema_version":"account-export.v1"}';
  }

  @override
  Future<void> requestAccountDeletion() async {
    deleteCount += 1;
    if (fail) throw StateError('synthetic failure');
  }
}
