import 'dart:async';
import 'dart:typed_data';

/// Abstract interface for audio capturers
abstract class AudioCapturer {
  /// Start audio recording
  Future<void> startRecording();

  /// Stop audio recording
  Future<void> stopRecording();

  /// Check if currently recording
  bool get isRecording;

  /// Get stream of audio data
  Stream<Uint8List> getAudioDataStream();
}