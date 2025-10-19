import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class AudioTestService {
  MediaStream? _localStream;
  bool _isRecording = false;

  /// Start audio recording test
  Future<void> startRecordingTest() async {
    if (_isRecording) return;
    
    try {
      // Get audio stream from microphone
      final mediaConstraints = <String, dynamic>{
        'audio': {
          'sampleRate': 16000,
          'channelCount': 1,
          'echoCancellation': true,
          'noiseSuppression': true,
        },
        'video': false,
      };
      
      print('Requesting microphone access...');
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _isRecording = true;
      
      print('Microphone access granted. Audio tracks:');
      _localStream?.getAudioTracks().forEach((track) {
        print('Track ID: ${track.id}, Label: ${track.label}');
      });
      
      // Listen for audio data
      print('Listening for audio data...');
      
    } catch (e) {
      print('Failed to start recording test: $e');
      throw Exception('Failed to start recording test: $e');
    }
  }

  /// Stop audio recording test
  Future<void> stopRecordingTest() async {
    if (!_isRecording) return;
    
    try {
      await _localStream?.dispose();
      _localStream = null;
      _isRecording = false;
      print('Recording test stopped');
    } catch (e) {
      print('Failed to stop recording test: $e');
      throw Exception('Failed to stop recording test: $e');
    }
  }

  /// Check if currently recording
  bool get isRecording => _isRecording;
}