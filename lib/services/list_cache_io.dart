import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Mobile/desktop list-cache backend (selected via conditional import).

Future<String?> listCacheDocumentsPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return dir.path;
}

Future<String?> readListCacheFile(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsString();
}

Future<void> writeListCacheFile(String path, String contents) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
}
