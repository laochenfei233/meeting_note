import 'dart:typed_data';
import 'package:meeting_note/services/asr_service.dart';

class ASRUsageExample {
  final ASRService _asrService = ASRService();
  
  /// 示例：使用WebSocket进行实时语音识别
  Future<void> startRealTimeTranscription(ASRModelConfig config) async {
    try {
      // 创建模拟的音频数据
      final audioData = AudioData(List<int>.filled(1000, 0));
      
      // 开始实时转录
      final transcriptionStream = _asrService.realTimeTranscription(
        audioData,
        'Aliyun',
        config,
        language: 'zh-CN',
        sampleRate: 16000,
        audioFormat: 'pcm',
      );
      
      // 监听转录结果
      transcriptionStream.listen(
        (text) {
          print('Transcription result: $text');
        },
        onError: (error) {
          print('Transcription error: $error');
        },
        onDone: () {
          print('Transcription completed');
        },
      );
      
      // 模拟发送实时音频数据
      // 在实际应用中，这些数据将来自麦克风或其他音频源
      for (int i = 0; i < 10; i++) {
        await Future.delayed(Duration(milliseconds: 100));
        final simulatedAudioChunk = Uint8List(160); // 10ms of 16kHz 16-bit mono audio
        // 填充一些模拟数据
        for (int j = 0; j < simulatedAudioChunk.length; j++) {
          simulatedAudioChunk[j] = (i * j) % 256;
        }
        
        try {
          await _asrService.sendAudioData(simulatedAudioChunk.toList());
        } catch (e) {
          print('Error sending audio data: $e');
          break;
        }
      }
      
      // 关闭连接
      await _asrService.closeConnection();
    } catch (e) {
      print('Error in real-time transcription: $e');
    }
  }
  
  /// 示例：检查连接状态
  void monitorConnectionStatus() {
    print('Current connection status: ${_asrService.connectionStatus}');
  }
}