import 'dart:async';
import 'dart:typed_data';
import 'package:meeting_note/services/asr_service.dart';
import 'package:meeting_note/services/audio_service.dart';

class RealtimeAudioHandler {
  final ASRService _asrService;
  final AudioService _audioService;
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  RealtimeAudioHandler(this._asrService, this._audioService);

  /// Start handling real-time audio data
  Future<void> startHandling() async {
    try {
      // Listen to audio data stream from audio service
      _audioStreamSubscription?.cancel();
      _audioStreamSubscription = _audioService.getAudioDataStream().listen(
        (audioData) {
          // Send audio data to ASR service
          _asrService.sendAudioData(audioData);
        },
        onError: (error) {
          print('Error in audio stream: $error');
        },
        onDone: () {
          print('Audio stream completed');
        },
      );
      
      print('Started handling real-time audio data');
    } catch (e) {
      print('Error starting audio handling: $e');
      rethrow;
    }
  }

  /// Stop handling real-time audio data
  Future<void> stopHandling() async {
    try {
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      print('Stopped handling real-time audio data');
    } catch (e) {
      print('Error stopping audio handling: $e');
      rethrow;
    }
  }
}