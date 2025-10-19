import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:uuid/uuid.dart';

// 定义连接状态枚举
enum WebSocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class ASRService {
  final Dio _dio = Dio();
  WebSocketChannel? _channel;
  WebSocketConnectionStatus _connectionStatus = WebSocketConnectionStatus.disconnected;
  String? _currentTaskId;
  bool _taskStarted = false;
  
  // 添加状态变更回调，避免频繁更新UI
  Function(WebSocketConnectionStatus)? onConnectionStatusChanged;
  
  // 获取当前连接状态
  WebSocketConnectionStatus get connectionStatus => _connectionStatus;
  
  /// Transcribe audio data using the specified model
  Future<String> transcribe(AudioData audio, String modelName, ASRModelConfig config) async {
    try {
      final response = await _dio.post(
        config.url,
        data: _buildRequestData(modelName, audio),
        options: Options(
          headers: _buildHeaders(modelName, config.key),
        ),
      );
      
      if (response.statusCode == 200) {
        final result = response.data;
        // Parse the response based on the model
        if (modelName == 'Aliyun') {
          return result['output']['text'] ?? '';
        } else if (modelName == 'Local') {
          return result['text'] ?? '';
        }
        return result.toString();
      } else {
        throw Exception('ASR request failed with status: ${response.statusCode}');
      }
    } catch (error, stackTrace) {
      // 添加堆栈跟踪信息以便更好地调试
      print('ASR transcription error: $error');
      print('Stack trace: $stackTrace');
      throw Exception('ASR transcription failed: $error');
    }
  }
  
  /// Real-time transcription using WebSocket
  Stream<String> realTimeTranscription(AudioData audio, String modelName, ASRModelConfig config, {
    String language = 'zh-CN',
    int sampleRate = 16000,
    String audioFormat = 'pcm',
  }) async* {
    try {
      if (modelName == 'Aliyun') {
        // Use WebSocket for real-time transcription with Aliyun
        yield* _aliyunWebSocketTranscription(audio, config, language, sampleRate, audioFormat);
      } else {
        // For other models, fallback to regular transcription
        final text = await transcribe(audio, modelName, config);
        yield text;
      }
    } catch (error, stackTrace) {
      // 添加堆栈跟踪信息以便更好地调试
      print('Real-time transcription error: $error');
      print('Stack trace: $stackTrace');
      throw Exception('Real-time transcription failed: $error');
    }
  }
  
  /// 更新连接状态并通知监听者
  void _updateConnectionStatus(WebSocketConnectionStatus status) {
    if (_connectionStatus != status) {
      _connectionStatus = status;
      // 通知连接状态变更
      onConnectionStatusChanged?.call(_connectionStatus);
    }
  }
  
  /// WebSocket implementation for Aliyun real-time transcription
  Stream<String> _aliyunWebSocketTranscription(
    AudioData audio,
    ASRModelConfig config,
    String language,
    int sampleRate,
    String audioFormat,
  ) async* {
    try {
      // 更新连接状态
      _updateConnectionStatus(WebSocketConnectionStatus.connecting);
      
      // WebSocket URL for DashScope
      final wsUrl = 'wss://dashscope.aliyuncs.com/api-ws/v1/inference';
      
      // Generate task ID
      _currentTaskId = const Uuid().v4();
      _taskStarted = false;
      
      // Connect to WebSocket
      final uri = Uri.parse('${wsUrl}?authorization=bearer ${config.key}&x-dashscope-async=enable');
      _channel = WebSocketChannel.connect(uri);
      
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
          'model': 'fun-asr-realtime', // 使用fun-asr-realtime模型
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
              
              if (action == 'task-started') {
                // 任务已启动，现在可以发送音频数据
                _taskStarted = true;
                print('Task started, ready to send audio data');
                
                // 发送音频数据
                try {
                  if (audio.data.isNotEmpty) {
                    if (audio.data is List<int>) {
                      _channel!.sink.add(Uint8List.fromList(audio.data));
                    } else if (audio.data is Uint8List) {
                      _channel!.sink.add(audio.data);
                    } else {
                      // 安全转换
                      final dataList = List<int>.from(audio.data);
                      _channel!.sink.add(Uint8List.fromList(dataList));
                    }
                  }
                  
                  // 发送finish-task指令
                  final finishMessage = {
                    'header': {
                      'action': 'finish-task',
                      'task_id': _currentTaskId,
                    }
                  };
                  print('Sending finish-task message: ${jsonEncode(finishMessage)}');
                  _channel!.sink.add(jsonEncode(finishMessage));
                } catch (e) {
                  print('Error sending audio data: $e');
                  rethrow;
                }
              } else if (action == 'result-generated' && response['payload'] != null) {
                final payload = response['payload'];
                if (payload['output'] != null && payload['output']['sentence'] != null) {
                  // 处理句子级别的输出
                  final sentence = payload['output']['sentence'];
                  if (sentence['text'] != null) {
                    accumulatedText += sentence['text'];
                    yield accumulatedText;
                  }
                } else if (payload['text'] != null) {
                  // 处理直接的文本输出
                  final text = payload['text'];
                  accumulatedText += text;
                  yield accumulatedText;
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
    if (_channel != null && _connectionStatus == WebSocketConnectionStatus.connected && _taskStarted) {
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
  
  /// 发送实时音频流（用于Aliyun模型）
  Stream<String> sendRealTimeAudioStream(Stream<Uint8List> audioStream, ASRModelConfig config, {
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
      
      // Connect to WebSocket
      final uri = Uri.parse('${wsUrl}?authorization=bearer ${config.key}&x-dashscope-async=enable');
      _channel = WebSocketChannel.connect(uri);
      
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
          'model': 'fun-asr-realtime', // 使用fun-asr-realtime模型
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
      
      // 同时监听服务器消息和音频流
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
              
              if (action == 'task-started') {
                // 任务已启动，现在可以发送音频数据
                _taskStarted = true;
                print('Task started, ready to send audio data');
                
                // 开始监听音频流并发送数据
                audioStream.listen(
                  (audioData) {
                    if (_channel != null && _taskStarted) {
                      _channel!.sink.add(audioData);
                      print('Sent audio data chunk: ${audioData.length} bytes');
                    }
                  },
                  onError: (error) {
                    print('Audio stream error: $error');
                  },
                  onDone: () {
                    // 音频流结束，发送finish-task指令
                    if (_channel != null && _taskStarted) {
                      final finishMessage = {
                        'header': {
                          'action': 'finish-task',
                          'task_id': _currentTaskId,
                        }
                      };
                      print('Sending finish-task message: ${jsonEncode(finishMessage)}');
                      _channel!.sink.add(jsonEncode(finishMessage));
                    }
                  },
                );
              } else if (action == 'result-generated' && response['payload'] != null) {
                final payload = response['payload'];
                if (payload['output'] != null && payload['output']['sentence'] != null) {
                  // 处理句子级别的输出
                  final sentence = payload['output']['sentence'];
                  if (sentence['text'] != null) {
                    accumulatedText += sentence['text'];
                    yield accumulatedText;
                  }
                } else if (payload['text'] != null) {
                  // 处理直接的文本输出
                  final text = payload['text'];
                  accumulatedText += text;
                  yield accumulatedText;
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
      }
    }
  }
  
  /// 手动关闭连接
  Future<void> closeConnection() async {
    await _closeConnection();
  }
  
  Map<String, dynamic> _buildRequestData(String modelName, AudioData audio) {
    if (modelName == 'Aliyun') {
      // 根据阿里云文档构建请求数据，使用fun-asr-realtime模型
      // 注意：实际使用时需要将音频数据转换为Base64格式
      // 确保音频数据是正确的类型后再进行Base64编码
      String audioBase64 = '';
      try {
        // 详细检查音频数据类型并安全转换
        if (audio.data is Uint8List) {
          audioBase64 = base64Encode(audio.data as Uint8List);
        } else if (audio.data is List<int>) {
          audioBase64 = base64Encode(audio.data as List<int>);
        } else {
          // 最后尝试转换为List<int>
          final dataList = List<int>.from(audio.data);
          audioBase64 = base64Encode(dataList);
        }
      } catch (e, stackTrace) {
        print('Error encoding audio data to Base64: $e');
        print('Audio data type: ${audio.data.runtimeType}');
        print('Stack trace: $stackTrace');
        rethrow;
      }
      
      return {
        'model': 'fun-asr-realtime',
        'input': {
          'audio': audioBase64,
        },
        'parameters': {
          'language': 'zh-CN',
          'stream': true,
        }
      };
    } else if (modelName == 'Local') {
      return {
        'audio_data': audio.data,
      };
    }
    
    return {
      'audio_data': audio.data,
    };
  }
  
  Map<String, String> _buildHeaders(String modelName, String apiKey) {
    if (modelName == 'Aliyun') {
      return {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'X-DashScope-Async': 'enable',
        'X-DashScope-SSE': 'enable',
      };
    } else if (modelName == 'Local') {
      return {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };
    }
    
    return {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
  }
}

class AudioData {
  final List<int> data;
  
  AudioData(this.data);
}

class ASRModelConfig {
  final String name;
  final String url;
  final String key;
  final String? modelName;
  
  ASRModelConfig({
    required this.name,
    required this.url,
    required this.key,
    this.modelName,
  });
  
  factory ASRModelConfig.fromJson(Map<String, dynamic> json) {
    return ASRModelConfig(
      name: json['name'],
      url: json['url'],
      key: json['key'] ?? '',
      modelName: json['model_name'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'key': key,
      'model_name': modelName,
    };
  }
}
