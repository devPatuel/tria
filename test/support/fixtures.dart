import 'dart:io';
import 'dart:typed_data';

/// Writes a deterministic byte blob that stands in for a photo.
///
/// Real images are never committed: they would leak personal data into a
/// repository that is treated as public.
File writeFakeImage(Directory dir, String name, {int bytes = 1024}) {
  final file = File('${dir.path}/$name');
  file.parent.createSync(recursive: true);
  final data = Uint8List.fromList(List.generate(bytes, (i) => i % 256));
  file.writeAsBytesSync(data);
  return file;
}
