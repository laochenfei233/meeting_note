import 'dart:async';
import 'package:flutter/material.dart';
import 'package:meeting_note/services/asr_service.dart' as asr;
import 'package:meeting_note/services/asr_service_v2.dart' as asr_v2;
import 'package:meeting_note/services/summary_service.dart';
import 'package:meeting_note/services/audio_service.dart';
import 'package:meeting_note/services/audio_capturer_factory.dart';
import 'package:meeting_note/services/audio_capturer_interface.dart';
import 'package:meeting_note/services/realtime_audio_handler.dart';
import 'package:meeting_note/services/audio_test_service.dart';
import 'package:meeting_note/utils/config_loader.dart';
import 'package:meeting_note/models/meeting.dart';
import 'package:meeting_note/services/storage_service.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  bool _isRecording = false;
  String _transcript = '';
  String _summary = '';
  String _meetingTitle = '';
  String? _selectedASRModel;
  String? _selectedSummaryModel;
  final asr.ASRService _asrService = asr.ASRService();
  final asr_v2.ASRServiceV2 _asrServiceV2 = asr_v2.ASRServiceV2();
  final SummaryService _summaryService = SummaryService();
  final AudioService _audioService = AudioService();
  late final AudioCapturer _audioCapturer;
  // AudioTestService is not used in this screen anymore
  final StorageService _storageService = StorageService();
  late Future<AppConfig> _configFuture;
  StreamSubscription<String>? _transcriptionSubscription;
  StreamSubscription<String>? _participantDetectionSubscription;
  final List<Participant> _participants = [
    Participant(id: '发言人1', name: '发言人1'),
    Participant(id: '发言人2', name: '发言人2'),
  ];
  String _currentSpeaker = '发言人1';
  int _wordCount = 0;
  bool _showSettings = true; // 控制是否显示设置部分
  
  // 用于防抖和减少界面更新频率的变量
  Timer? _debounceTimer;
  String _pendingTranscript = '';
  bool _isTranscriptUpdateScheduled = false;
  
  // 连接状态相关变量
  dynamic _connectionStatus;
  
  @override
  void initState() {
    super.initState();
    _configFuture = ConfigLoader.loadConfig();
    // 初始化音频捕获器
    _audioCapturer = AudioCapturerFactory.createAudioCapturer();
    // 监听ASR服务的连接状态变更
    _asrService.onConnectionStatusChanged = (status) {
      if (mounted) {
        setState(() {
          _connectionStatus = status;
        });
      }
    };
    
    // 监听ASR服务V2的连接状态变更
    _asrServiceV2.onConnectionStatusChanged = (status) {
      if (mounted) {
        setState(() {
          _connectionStatus = status;
        });
      }
    };
  }

  @override
  void dispose() {
    _transcriptionSubscription?.cancel();
    _participantDetectionSubscription?.cancel();
    // 确保关闭ASR连接
    _asrService.closeConnection();
    _asrService.onConnectionStatusChanged = null; // 清除回调引用
    _debounceTimer?.cancel();
    super.dispose();
  }

  // 切换录音状态（开始/停止）
  void _toggleRecording() {
    // 避免重复点击
    if (_isTranscriptUpdateScheduled) return;
    
    setState(() {
      _isRecording = !_isRecording;
      
      // 切换设置和录音视图
      if (_isRecording) {
        _showSettings = false;
      }
      
      if (_isRecording) {
        // Start recording logic
        _startRecording();
      } else {
        // Stop recording logic
        _stopRecording();
      }
    });
  }

  void _startRecording() async {
    try {
      // Start audio recording with the selected capturer
      await _audioCapturer.startRecording();
      
      // Clear previous transcript
      setState(() {
        _transcript = '';
        _pendingTranscript = '';
        _wordCount = 0;
      });
      
      // Get config for ASR
      final config = await _configFuture;
      final asrModel = _selectedASRModel ?? config.asrModels.first.name;
      final asrConfig = config.asrModels.firstWhere(
        (model) => model.name == asrModel,
        orElse: () => config.asrModels.first,
      );
      
      print('Starting recording with model: $asrModel');
      
      // Real-time transcription
      _transcriptionSubscription?.cancel();
      
      if (asrModel == 'Aliyun') {
        // For Aliyun model, use the new V2 service
        _transcriptionSubscription = _asrServiceV2.realTimeTranscriptionV2(
          asrConfig.key,
          asrConfig.modelName ?? 'fun-asr-realtime',
          language: 'zh-CN',
          sampleRate: 16000,
          audioFormat: 'pcm',
        ).listen(
          (sentence) {
            if (mounted) {
              final speaker = _participants.firstWhere(
                (p) => p.id == _currentSpeaker,
                orElse: () => _participants[0],
              );
              
              // 使用防抖机制减少界面更新频率
              _pendingTranscript = '[${speaker.name}] $sentence\n';
              _scheduleTranscriptUpdate();
            }
          },
          onDone: () {
            if (mounted) {
              setState(() {
                _isRecording = false;
              });
            }
          },
          onError: (error) {
            print('Transcription subscription error: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Transcription error: $error')),
              );
              // 出错时更新连接状态
              setState(() {
                _isRecording = false;
              });
            }
          },
        );
        
        // Listen to audio data stream and send to ASR service
        _audioCapturer.getAudioDataStream().listen(
          (audioData) {
            // Send audio data to ASR service
            _asrServiceV2.sendAudioData(audioData);
          },
          onError: (error) {
            print('Audio stream error: $error');
          },
          onDone: () {
            // Send finish task when audio stream is done
            _asrServiceV2.sendFinishTask();
          },
        );
      } else {
        // For non-Aliyun models, use the existing approach
        // Use real ASR service with streaming
        final audio = asr.AudioData([]); // Empty data since we'll stream
        
        // Start the real-time transcription stream
        _transcriptionSubscription = _asrService.realTimeTranscription(
          audio, 
          asrModel, 
          asrConfig,
          language: 'zh-CN',
          sampleRate: 16000,
          audioFormat: 'pcm',
        ).listen(
          (sentence) {
            if (mounted) {
              final speaker = _participants.firstWhere(
                (p) => p.id == _currentSpeaker,
                orElse: () => _participants[0],
              );
              
              // 使用防抖机制减少界面更新频率
              _pendingTranscript = '[${speaker.name}] $sentence\n';
              _scheduleTranscriptUpdate();
            }
          },
          onDone: () {
            if (mounted) {
              setState(() {
                _isRecording = false;
              });
            }
          },
          onError: (error) {
            print('Transcription subscription error: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Transcription error: $error')),
              );
              // 出错时更新连接状态
              setState(() {
                _isRecording = false;
              });
            }
          },
        );
        
        // Listen to audio data stream and send to ASR service
        _audioCapturer.getAudioDataStream().listen(
          (audioData) {
            // Send audio data to ASR service for non-Aliyun models
            _asrService.sendAudioData(audioData);
          },
          onError: (error) {
            print('Audio stream error: $error');
          },
        );
      }
      
      // Auto-detect participants using voice recognition
      _participantDetectionSubscription?.cancel();
      _participantDetectionSubscription = _audioService.detectParticipantVoice().listen(
        (participantName) {
          if (mounted) {
            // Check if participant already exists, if not create new one
            bool participantExists = _participants.any((p) => p.name == participantName);
            if (!participantExists) {
              setState(() {
                _participants.add(Participant(id: participantName, name: participantName));
              });
            }
            
            setState(() {
              _currentSpeaker = participantName;
            });
          }
        },
        onError: (error) {
          // Handle participant detection error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Participant detection error: $error')),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording failed to start: $e')),
        );
        setState(() {
          _isRecording = false;
        });
      }
    }
  }

  void _stopRecording() async {
    try {
      // Stop audio recording with the selected capturer
      await _audioCapturer.stopRecording();
      
      // Stop audio recording
      await _audioService.stopRecording();
      
      // Stop the transcription stream
      _transcriptionSubscription?.cancel();
      _participantDetectionSubscription?.cancel();
      
      // 关闭ASR连接
      await _asrService.closeConnection();
      await _asrServiceV2.closeConnection();
      
      // Hide settings when recording stops
      setState(() {
        _showSettings = false;
      });
      
      // Generate summary
      _generateSummary();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording failed to stop: $e')),
        );
      }
    }
  }

  // 防抖机制，减少界面更新频率
  void _scheduleTranscriptUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _transcript += _pendingTranscript;
          _wordCount = _transcript.split(RegExp(r'\s+')).length;
        });
      }
      _isTranscriptUpdateScheduled = false;
    });
    _isTranscriptUpdateScheduled = true;
  }

  // 添加测试录音功能的方法
  Future<void> _testRecording() async {
    try {
      // Create a temporary AudioTestService for testing
      final audioTestService = AudioTestService();
      await audioTestService.startRecordingTest();
      // 3秒后停止测试
      await Future.delayed(const Duration(seconds: 3));
      await audioTestService.stopRecordingTest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('录音测试完成，检查控制台输出')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音测试失败: $e')),
        );
      }
    }
  }

  Future<void> _generateSummary() async {
    if (_transcript.isEmpty) return;
    
    setState(() {
      _summary = '正在生成会议摘要...';
    });
    
    try {
      // Get config for summary
      final config = await _configFuture;
      final summaryModel = _selectedSummaryModel ?? config.summaryModels.first.name;
      final summaryConfig = config.summaryModels.firstWhere(
        (model) => model.name == summaryModel,
        orElse: () => config.summaryModels.first,
      );
      
      // Use real summary service
      final summary = await _summaryService.realSummaryGeneration(_transcript, summaryModel, summaryConfig as asr.ASRModelConfig);
      
      if (mounted) {
        setState(() {
          _summary = summary;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _summary = '摘要生成失败: $e';
        });
      }
    }
  }

  Future<void> _saveMeeting() async {
    if (_meetingTitle.isEmpty || _transcript.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入会议标题和内容')),
        );
      }
      return;
    }
    
    try {
      final meeting = Meeting(
        title: _meetingTitle,
        date: DateTime.now(),
        transcript: _transcript,
        summary: _summary,
        participants: _participants,
      );
      
      await _storageService.saveMeeting(meeting);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('会议记录已保存')),
        );
        
        // 返回到会议列表页面
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  // 切换回设置视图
  void _showSettingsView() {
    setState(() {
      _showSettings = true;
      _summary = '';
      _transcript = '';
      _wordCount = 0;
    });
  }

  // 开始会议的方法
  void _startMeeting() {
    setState(() {
      _showSettings = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('会议记录'),
        actions: [
          // 显示连接状态
          IconButton(
            icon: Icon(
              _connectionStatus is asr.WebSocketConnectionStatus && _connectionStatus == asr.WebSocketConnectionStatus.connected 
                ? Icons.wifi 
                : _connectionStatus is asr.WebSocketConnectionStatus && _connectionStatus == asr.WebSocketConnectionStatus.connecting 
                  ? Icons.wifi_protected_setup
                  : _connectionStatus is asr_v2.WebSocketConnectionStatus && _connectionStatus == asr_v2.WebSocketConnectionStatus.error
                    ? Icons.wifi_off
                    : Icons.wifi_off,
              color: _connectionStatus is asr.WebSocketConnectionStatus && _connectionStatus == asr.WebSocketConnectionStatus.connected 
                ? Colors.green 
                : _connectionStatus is asr.WebSocketConnectionStatus && _connectionStatus == asr.WebSocketConnectionStatus.connecting 
                  ? Colors.orange
                  : _connectionStatus is asr_v2.WebSocketConnectionStatus && _connectionStatus == asr_v2.WebSocketConnectionStatus.error
                    ? Colors.red
                    : Colors.grey,
            ),
            onPressed: () {
              // 显示连接状态信息
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'WebSocket连接状态: ${_connectionStatus.toString().split('.').last}'
                  ),
                ),
              );
            },
          ),
          // 模型快速切换下拉菜单
          PopupMenuButton<String>(
            icon: const Icon(Icons.swap_horiz),
            onSelected: (String modelName) {
              setState(() {
                _selectedASRModel = modelName;
              });
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'Aliyun',
                  child: Text('阿里云ASR'),
                ),
                const PopupMenuItem<String>(
                  value: 'Local',
                  child: Text('本地ASR'),
                ),
              ];
            },
          ),
          IconButton(
            icon: Icon(_isRecording ? Icons.stop : Icons.mic),
            onPressed: _toggleRecording,
            color: _isRecording ? Colors.red : null,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_showSettings) ...[
                  TextField(
                    decoration: InputDecoration(
                      labelText: '会议标题',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _meetingTitle = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<AppConfig>(
                    future: _configFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Text('Error loading config: ${snapshot.error}');
                      } else if (!snapshot.hasData) {
                        return const Text('No configuration data');
                      } else {
                        final config = snapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '模型设置',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Text('ASR 模型: '),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _selectedASRModel,
                                              isExpanded: true,
                                              items: config.asrModels
                                                  .map((model) => DropdownMenuItem(
                                                        value: model.name,
                                                        child: Text(model.name),
                                                      ))
                                                  .toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedASRModel = value;
                                                });
                                              },
                                              hint: const Text('选择 ASR 模型'),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Text('摘要模型: '),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _selectedSummaryModel,
                                              isExpanded: true,
                                              items: config.summaryModels
                                                  .map((model) => DropdownMenuItem(
                                                        value: model.name,
                                                        child: Text(model.name),
                                                      ))
                                                  .toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedSummaryModel = value;
                                                });
                                              },
                                              hint: const Text('选择摘要模型'),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '会议信息',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Text(
                                          '当前发言人:',
                                          style: TextStyle(
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _currentSpeaker,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Text(
                                          '字数统计:',
                                          style: TextStyle(
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$_wordCount 字',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      '录音状态:',
                                      style: TextStyle(
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: _isRecording ? Colors.red : Colors.grey,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _isRecording ? '录音中...' : '已停止',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: _isRecording ? Colors.red : null,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // 添加测试录音按钮
                  ElevatedButton(
                    onPressed: _testRecording,
                    child: const Text('测试录音功能'),
                  ),
                ] else ...[
                  // 录音和实时转录视图
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        '实时转录',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: _isRecording ? Colors.red : Colors.grey,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _isRecording ? '录音中...' : '已停止',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: _isRecording ? Colors.red : null,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_isRecording)
                                        const Row(
                                          children: [
                                            Icon(
                                              Icons.fiber_manual_record,
                                              color: Colors.red,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              '流式识别中',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 200, // 固定高度避免溢出
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                      ),
                                    ),
                                    child: SingleChildScrollView(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Text(
                                          _transcript.isEmpty
                                              ? '点击顶部麦克风按钮开始录音'
                                              : _transcript,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '会议摘要',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 150, // 固定高度避免溢出
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                      ),
                                    ),
                                    child: SingleChildScrollView(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Text(
                                          _summary.isEmpty
                                              ? '停止录音后将自动生成会议摘要'
                                              : _summary,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _showSettings ? _startMeeting : _showSettingsView,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _showSettings ? '开始会议并自动生成摘要' : '返回设置',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (!_showSettings) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveMeeting,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '保存会议记录',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }
      ),
    );
  }
}