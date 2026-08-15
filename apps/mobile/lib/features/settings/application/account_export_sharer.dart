import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

typedef TemporaryDirectoryProvider = Future<Directory> Function();
typedef ShareInvoker = Future<void> Function(ShareParams params);

class AccountExportSharer {
  AccountExportSharer({
    TemporaryDirectoryProvider? temporaryDirectoryProvider,
    ShareInvoker? shareInvoker,
  }) : _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _shareInvoker =
           shareInvoker ??
           ((params) async {
             await SharePlus.instance.share(params);
           });

  final TemporaryDirectoryProvider _temporaryDirectoryProvider;
  final ShareInvoker _shareInvoker;

  Future<void> share(String exportJson, {Rect? sharePositionOrigin}) async {
    final directory = await _temporaryDirectoryProvider();
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      ':',
      '-',
    );
    final file = File(
      '${directory.path}/convocoach-account-export-$timestamp.json',
    );
    try {
      await file.writeAsString(exportJson, flush: true);
      await _shareInvoker(
        ShareParams(
          subject: 'ELLIS account export',
          title: 'Export ELLIS data',
          files: [XFile(file.path, mimeType: 'application/json')],
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}

final accountExportSharerProvider = Provider<AccountExportSharer>(
  (ref) => AccountExportSharer(),
);
