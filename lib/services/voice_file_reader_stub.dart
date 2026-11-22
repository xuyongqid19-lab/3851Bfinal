import 'dart:typed_data';

/// Web stub: recordings are read from blob URLs instead (voice_blob_reader_web).
Future<Uint8List?> readRecordingFile(String path) async => null;

/// Web stub: data URIs play directly via UrlSource, no temp file needed.
Future<String> writeTempAudioFile(String dataUri) async {
  throw UnsupportedError('writeTempAudioFile is only available on native.');
}
