import 'dart:typed_data';

import 'file_reader_io.dart' if (dart.library.html) 'file_reader_web.dart' as platform_file_reader;

Future<Uint8List> readFileAsBytes(String path) {
  return platform_file_reader.readFileAsBytes(path);
}
