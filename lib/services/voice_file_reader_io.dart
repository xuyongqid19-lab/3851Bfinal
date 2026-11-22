import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Reads a finished native recording from disk for base64 transport.
Future<Uint8List?> readRecordingFile(String path) async {
  try {
    final file = File(path);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}

/// Writes a base64 data: URI (a received voice message) to a temp file so the
/// native audio player can play it.
Future<String> writeTempAudioFile(String dataUri) async {
  final commaIndex = dataUri.indexOf(',');
  if (commaIndex < 0) {
    throw const FormatException('Invalid data URI');
  }
  final meta = dataUri.substring(5, commaIndex);
  final payload = dataUri.substring(commaIndex + 1);
  final bytes = base64Decode(payload);
  final extension = meta.contains('audio/webm')
      ? 'webm'
      : meta.contains('audio/wav')
          ? 'wav'
          : 'm4a';
  final dir = await Directory.systemTemp.createTemp('voice_play');
  final file = File(
      '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.$extension');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
