import 'dart:convert';
import 'dart:io';

import '../../domain/session_config.dart';

/// Named, reusable session configurations.
///
/// Returning to the same folder is the common case, and re-picking nine
/// destinations by hand every time is exactly the friction the app exists to
/// remove.
class ProfileStore {
  final File file;

  ProfileStore(this.file);

  Future<Map<String, SessionConfig>> loadAll() async {
    if (!await file.exists()) return {};
    final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return raw.map(
      (name, json) =>
          MapEntry(name, SessionConfig.fromJson(json as Map<String, dynamic>)),
    );
  }

  Future<void> save(String name, SessionConfig config) async {
    final all = await loadAll();
    all[name] = config;
    await _write(all);
  }

  Future<void> delete(String name) async {
    final all = await loadAll();
    all.remove(name);
    await _write(all);
  }

  Future<void> _write(Map<String, SessionConfig> all) async {
    final json = all.map((name, config) => MapEntry(name, config.toJson()));
    await file.writeAsString(jsonEncode(json));
  }
}
