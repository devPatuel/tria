import 'dart:io';

/// Runs an external command. Injectable so tests never open a real window.
typedef ProcessRunner = Future<int> Function(
    String executable, List<String> arguments);

/// Reveals a folder in the operating system's file manager.
///
/// This is the last step of a session: the user wants to see where their files
/// ended up, in the tool they already know.
class FolderOpener {
  final ProcessRunner _runner;
  final String _platform;

  FolderOpener({ProcessRunner? runner, String? platformOverride})
      : _runner = runner ?? _defaultRunner,
        _platform = platformOverride ?? Platform.operatingSystem;

  static Future<int> _defaultRunner(
      String executable, List<String> arguments) async {
    final result = await Process.run(executable, arguments);
    return result.exitCode;
  }

  /// Opens [path], returning whether it worked.
  ///
  /// A missing folder or a command that will not launch returns false instead
  /// of throwing: another program deleting a folder mid-session is routine, and
  /// failing to open a window is not worth losing a session over.
  Future<bool> reveal(String path) async {
    if (!await Directory(path).exists()) return false;

    final executable = switch (_platform) {
      'windows' => 'explorer',
      _ => 'open',
    };

    try {
      return await _runner(executable, [path]) == 0;
    } on ProcessException {
      return false;
    }
  }
}
