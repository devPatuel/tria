import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves where Tría keeps its own data.
///
/// Journals, profiles and thumbnail caches live in the OS application-support
/// directory, never beside the user's files and never inside the repository:
/// a session file carries full paths and would leak personal data.
class AppPaths {
  static Future<Directory> dataDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'Tria'));
    return dir.create(recursive: true);
  }

  static Future<File> journalFor(String sessionId) async {
    final dir = await dataDir();
    final journals = await Directory(p.join(dir.path, 'journals')).create();
    return File(p.join(journals.path, '$sessionId.jsonl'));
  }

  static Future<File> profilesFile() async {
    final dir = await dataDir();
    return File(p.join(dir.path, 'profiles.json'));
  }
}
