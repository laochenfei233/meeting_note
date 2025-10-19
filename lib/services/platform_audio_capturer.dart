import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:meeting_note/services/audio_capturer_interface.dart';

class PlatformAudioCapturer implements AudioCapturer {
  static const MethodChannel _channel = MethodChannel('meeting_note/audio_capturer');
  static const EventChannel _audioStreamChannel = EventChannel('meeting_note/audio_stream');
  
  bool _isRecording = false;
  StreamController<Uint8List>? _audioStreamController;
  StreamSubscription? _audioStreamSubscription;

  @override
  Future<void> startRecording() async {
    if (_isRecording) return;
    
    try {
      // Initialize stream controller
      _audioStreamController = StreamController<Uint8List>();
      
      // Listen to audio stream events
      _audioStreamSubscription = _audioStreamChannel.receiveBroadcastStream().listen(
        (dynamic data) {
          if (data is Uint8List) {
            _audioStreamController?.add(data);
          }
        },
        onError: (error) {
          print('Error receiving audio stream: $error');
        },
      );
      
      // Start recording on platform side
      await _channel.invokeMethod('startRecording');
      _isRecording = true;
      
      print('Started platform audio recording');
    } on PlatformException catch (e) {
      throw Exception('Failed to start recording: ${e.message}');
    }
  }

  @override
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    
    try {
      // Stop recording on platform side
      await _channel.invokeMethod('stopRecording');
      _isRecording = false;
      
      // Cancel stream subscription
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      
      // Close stream controller
      await _audioStreamController?.close();
      _audioStreamController = null;
      
      print('Stopped platform audio recording');
    } on PlatformException catch (e) {
      throw Exception('Failed to stop recording: ${e.message}');
    }
  }

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<Uint8List> getAudioDataStream() {
    return _audioStreamController?.stream ?? Stream.empty();
  }
}