import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:meeting_note/services/audio_capturer_interface.dart';

/// Raw audio capturer that captures 16kHz mono PCM audio data
class RawAudioCapturer implements AudioCapturer {
  bool _isRecording = false;
  StreamController<Uint8List>? _audioStreamController;
  
  // Audio format constants
  static const int SAMPLE_RATE = 16000;
  static const int CHANNEL_COUNT = 1;
  static const int BITS_PER_SAMPLE = 16;

  /// Check and request microphone permission
  Future<bool> _requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      print('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Start audio recording
  @override
  Future<void> startRecording() async {
    if (_isRecording) return;
    
    try {
      // Request microphone permission
      final hasPermission = await _requestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('Microphone permission not granted');
      }
      
      // Initialize stream controller
      _audioStreamController = StreamController<Uint8List>();
      _isRecording = true;
      
      // Start capturing audio data
      _captureAudioData();
      
      print('Started raw audio recording at ${SAMPLE_RATE}Hz, ${CHANNEL_COUNT} channel(s)');
    } catch (e) {
      throw Exception('Failed to start recording: $e');
    }
  }

  /// Stop audio recording
  @override
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    
    try {
      _isRecording = false;
      await _audioStreamController?.close();
      _audioStreamController = null;
      print('Stopped raw audio recording');
    } catch (e) {
      throw Exception('Failed to stop recording: $e');
    }
  }

  /// Capture audio data - in a real implementation, this would interface with platform-specific code
  void _captureAudioData() {
    // This is a simulation of audio data capture
    // In a real implementation, this would use platform channels to capture actual microphone data
    
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording || _audioStreamController?.isClosed == true) {
        timer.cancel();
        return;
      }
      
      try {
        // Generate simulated 16kHz PCM audio data (16-bit, mono)
        // In a real implementation, this would come from the actual microphone
        final chunk = Uint8List(3200); // 100ms of 16kHz 16-bit mono audio
        for (int i = 0; i < chunk.length; i++) {
          // Generate some pseudo-audio data
          chunk[i] = ((i * 37) % 256).toInt();
        }
        
        // Add the audio data to the stream
        _audioStreamController?.add(chunk);
      } catch (e) {
        print('Error generating audio chunk: $e');
      }
    });
  }

  /// Check if currently recording
  @override
  bool get isRecording => _isRecording;
  
  /// Get stream of audio data
  @override
  Stream<Uint8List> getAudioDataStream() {
    return _audioStreamController?.stream ?? Stream.empty();
  }
  
  /// Convert audio data to the format required by ASR service
  Uint8List convertToASRFormat(Uint8List rawData) {
    // In this case, we're already generating data in the correct format
    // In a real implementation, this might involve resampling or format conversion
    return rawData;
  }
}