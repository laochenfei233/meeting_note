import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';

// 定义连接状态枚举
enum WebSocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class ASRServiceV2 {
  WebSocketChannel? _channel;
  WebSocketConnectionStatus _connectionStatus = WebSocketConnectionStatus.disconnected;
  String? _currentTaskId;
  bool _taskStarted = false;
  bool _isConnected = false;
  
  // 添加状态变更回调，避免频繁更新UI
  Function(WebSocketConnectionStatus)? onConnectionStatusChanged;
  
  // 获取当前连接状态
  WebSocketConnectionStatus get connectionStatus => _connectionStatus;
  
  /// 更新连接状态并通知监听者
  void _updateConnectionStatus(WebSocketConnectionStatus status) {
    if (_connectionStatus != status) {
      _connectionStatus = status;
      // 通知连接状态变更
      onConnectionStatusChanged?.call(_connectionStatus);
    }
  }
  
  /// Real-time transcription using WebSocket with correct protocol
  Stream<String> realTimeTranscriptionV2(
    String apiKey,
    String modelName, {
    String language = 'zh-CN',
    int sampleRate = 16000,
    String audioFormat = 'pcm',
  }) async* {
    try {
      // 更新连接状态
      _updateConnectionStatus(WebSocketConnectionStatus.connecting);
      
      // WebSocket URL for DashScope
      final wsUrl = 'wss://dashscope.aliyuncs.com/api-ws/v1/inference';
      
      // Generate task ID
      _currentTaskId = const Uuid().v4();
      _taskStarted = false;
      _isConnected = false;
      
      print('Connecting to WebSocket: $wsUrl');
      
      // Connect to WebSocket
      final uri = Uri.parse('${wsUrl}?authorization=bearer $apiKey&x-dashscope-async=enable');
      _channel = WebSocketChannel.connect(uri);
      
      _isConnected = true;
      // 更新连接状态
      _updateConnectionStatus(WebSocketConnectionStatus.connected);
      
      // Listen for messages from the server
      final messageStream = _channel!.stream.asBroadcastStream();
      
      // Send the run-task message to start the transcription
      final taskMessage = {
        'header': {
          'action': 'run-task',
          'task_id': _currentTaskId,
          'streaming': 'duplex'
        },
        'payload': {
          'task_group': 'audio',
          'task': 'asr',
          'function': 'recognition',
          'model': modelName, // 使用传入的模型名称
          'parameters': {
            'format': audioFormat,
            'sample_rate': sampleRate,
            'language': language,
          },
          'input': {}
        }
      };
      
      print('Sending run-task message: ${jsonEncode(taskMessage)}');
      _channel!.sink.add(jsonEncode(taskMessage));
      
      // Listen for results
      String accumulatedText = '';
      
      await for (final message in messageStream) {
        try {
          print('Received message type: ${message.runtimeType}');
          
          // 检查是否是文本消息（JSON格式）还是二进制音频数据
          if (message is String) {
            print('Received text message: $message');
            // 文本消息（JSON格式）
            final Map<String, dynamic> response = jsonDecode(message);
            
            // 检查是否有错误信息
            if (response['error'] != null) {
              final error = response['error'];
              throw Exception('WebSocket error: ${error['message'] ?? error.toString()}');
            }
            
            final header = response['header'];
            if (header != null) {
              final action = header['action'];
              print('Received action: $action');
              
              if (action == 'task-started') {
                // 任务已启动，现在可以发送音频数据
                _taskStarted = true;
                print('Task started, ready to send audio data');
              } else if (action == 'result-generated' && response['payload'] != null) {
                final payload = response['payload'];
                print('Received payload: $payload');
                
                // 处理识别结果
                if (payload['output'] != null) {
                  final output = payload['output'];
                  if (output['sentence'] != null) {
                    // 处理句子级别的输出
                    final sentence = output['sentence'];
                    if (sentence['text'] != null) {
                      final text = sentence['text'];
                      accumulatedText += text;
                      yield accumulatedText;
                    }
                  } else if (output['text'] != null) {
                    // 处理直接的文本输出
                    final text = output['text'];
                    accumulatedText += text;
                    yield accumulatedText;
                  }
                }
              } else if (action == 'task-finished') {
                // Task finished, close the connection
                print('Task finished');
                await _closeConnection();
                break;
              }
            }
          } else {
            // 二进制音频数据，跳过处理
            print('Skipping binary data message of type: ${message.runtimeType}');
          }
        } catch (e, stackTrace) {
          // Handle JSON parsing errors
          print('Error parsing WebSocket message: $e');
          print('Stack trace: $stackTrace');
          if (e is FormatException) {
            // 可能是二进制音频数据，跳过处理
            print('Skipping binary data message due to format exception');
          } else {
            rethrow;
          }
        }
      }
    } catch (error, stackTrace) {
      _updateConnectionStatus(WebSocketConnectionStatus.error);
      print('WebSocket connection error: $error');
      print('Stack trace: $stackTrace');
      await _closeConnection();
      rethrow;
    }
  }
  
  /// 发送实时音频数据
  Future<void> sendAudioData(Uint8List audioData) async {
    if (_channel != null && _isConnected && _taskStarted) {
      try {
        // 直接发送Uint8List格式的音频数据
        _channel!.sink.add(audioData);
        print('Sent audio data with length: ${audioData.length}');
      } catch (e, stackTrace) {
        print('Error sending audio data: $e');
        print('Stack trace: $stackTrace');
        _updateConnectionStatus(WebSocketConnectionStatus.error);
        throw Exception('Failed to send audio data: $e');
      }
    } else {
      if (!_taskStarted) {
        print('Task not started yet, cannot send audio data');
      } else {
        print('WebSocket is not connected, cannot send audio data');
      }
    }
  }
  
  /// 发送完成任务指令
  Future<void> sendFinishTask() async {
    if (_channel != null && _isConnected && _currentTaskId != null) {
      try {
        final finishMessage = {
          'header': {
            'action': 'finish-task',
            'task_id': _currentTaskId,
          }
        };
        print('Sending finish-task message: ${jsonEncode(finishMessage)}');
        _channel!.sink.add(jsonEncode(finishMessage));
      } catch (e, stackTrace) {
        print('Error sending finish-task message: $e');
        print('Stack trace: $stackTrace');
        throw Exception('Failed to send finish-task message: $e');
      }
    }
  }
  
  /// 关闭WebSocket连接
  Future<void> _closeConnection() async {
    if (_channel != null) {
      try {
        await _channel!.sink.close(status.goingAway);
      } catch (e, stackTrace) {
        print('Error closing WebSocket connection: $e');
        print('Stack trace: $stackTrace');
      } finally {
        _channel = null;
        _updateConnectionStatus(WebSocketConnectionStatus.disconnected);
        _currentTaskId = null;
        _taskStarted = false;
        _isConnected = false;
      }
    }
  }
  
  /// 手动关闭连接
  Future<void> closeConnection() async {
    await _closeConnection();
  }
}