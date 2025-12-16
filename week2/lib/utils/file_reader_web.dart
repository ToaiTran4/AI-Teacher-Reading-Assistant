import 'dart:typed_data';

Future<Uint8List> readFileAsBytes(String path) async {
  // On Web a path is not available; throw to indicate unsupported operation.
  throw UnsupportedError('readFileAsBytes is not supported on Web; use bytes from file picker instead.');
}
