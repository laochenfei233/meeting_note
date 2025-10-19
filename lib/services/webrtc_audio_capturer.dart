import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:meeting_note/services/audio_capturer_interface.dart';

class WebRTCAudioCapturer implements AudioCapturer {
  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;
  bool _isRecording = false;
  StreamController<Uint8List>? _audioStreamController;
  
  /// Audio constraints for proper PCM format
  Map<String, dynamic> get _audioConstraints => {
        'audio': {
          'sampleRate': 16000,
          'channelCount': 1,
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      };

  /// Start audio recording with proper WebRTC setup
  @override
  Future<void> startRecording() async {
    if (_isRecording) return;
    
    try {
      // Create peer connection
      final configuration = <String, dynamic>{
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ]
      };
      
      _peerConnection = await createPeerConnection(configuration);
      
      // Get audio stream from microphone
      _localStream = await navigator.mediaDevices.getUserMedia(_audioConstraints);
      _isRecording = true;
      
      // Add audio track to peer connection
      _localStream!.getAudioTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });
      
      // Create stream controller for audio data
      _audioStreamController = StreamController<Uint8List>();
      
      print('Started WebRTC audio recording');
      
      // Start capturing audio data
      _captureAudioData();
    } catch (e) {
      throw Exception('Failed to start WebRTC recording: $e');
    }
  }

  /// Stop audio recording
  @override
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    
    try {
      await _localStream?.dispose();
      _localStream = null;
      
      await _peerConnection?.close();
      _peerConnection = null;
      
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
  @override
  bool get isRecording => _isRecording;
  
  /// Get stream of audio data
  @override
  Stream<Uint8List> getAudioDataStream() {
    return _audioStreamController?.stream ?? Stream.empty();
  }
}