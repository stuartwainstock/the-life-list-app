import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Mobile/desktop taxonomy cache backend (selected via conditional import).
/// Uses a real file under the app documents directory.

Future<String?> taxonomyDocumentsPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return dir.path;
}

Future<String?> readTaxonomyCacheFile(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsString();
}

Future<void> writeTaxonomyCacheFile(String path, String contents) async {
  final file = File(path);
  await file.writeAsString(contents);
}
