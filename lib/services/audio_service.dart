import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class AudioService {
  MediaStream? _localStream;
  bool _isRecording = false;
  StreamController<Uint8List>? _audioStreamController;
  RTCDataChannel? _dataChannel; // 用于传输音频数据

  /// Start audio recording
  Future<void> startRecording() async {
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
      
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _isRecording = true;
      
      // Create stream controller for audio data
      _audioStreamController = StreamController<Uint8List>();
      
      print('Started recording from microphone');
      
      // Start capturing audio data
      _captureAudioData();
    } catch (e) {
      throw Exception('Failed to start recording: $e');
    }
  }

  /// Stop audio recording
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    
    try {
      await _localStream?.dispose();
      _localStream = null;
      _isRecording = false;
      await _audioStreamController?.close();
      _audioStreamController = null;
    } catch (e) {
      throw Exception('Failed to stop recording: $e');
    }
  }

  /// Capture audio data from the media stream
  void _captureAudioData() {
    // Note: In a real implementation, we would need to use a more complex approach
    // to extract raw PCM data from the WebRTC stream. This is a simplified version
    // that simulates the process.
    
    // For now, we'll simulate audio data capture with periodic chunks
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
  bool get isRecording => _isRecording;
  
  /// Get stream of audio data
  Stream<Uint8List> getAudioDataStream() {
    return _audioStreamController?.stream ?? Stream.empty();
  }
  
  /// Detect participant voice based on audio characteristics (no pre-registered voice profiles)
  Stream<String> detectParticipantVoice() async* {
    try {
      // In a real implementation, this would use voice recognition algorithms
      // to identify who is speaking based on audio characteristics in real-time
      // For now, we'll cycle through participants to simulate the behavior
      const participants = ['发言人1', '发言人2', '发言人3'];
      int currentParticipantIndex = 0;
      
      while (true) {
        await Future.delayed(const Duration(seconds: 5));
        yield participants[currentParticipantIndex];
        currentParticipantIndex = (currentParticipantIndex + 1) % participants.length;
      }
    } catch (e, stackTrace) {
      print('Participant detection error: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Participant detection failed: $e');
    }
  }
}