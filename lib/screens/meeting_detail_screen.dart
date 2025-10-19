import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:meeting_note/models/meeting.dart';
import 'package:meeting_note/services/storage_service.dart';
import 'package:meeting_note/services/summary_service.dart';
import 'package:meeting_note/services/template_service.dart';
import 'package:meeting_note/services/qna_service.dart';
import 'package:meeting_note/utils/config_loader.dart';
import 'package:meeting_note/models/template.dart';
import 'package:meeting_note/screens/template_management_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:meeting_note/services/asr_service.dart';

class MeetingDetailScreen extends StatefulWidget {
  final int meetingId;

  const MeetingDetailScreen({super.key, required this.meetingId});

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  final StorageService _storageService = StorageService();
  final SummaryService _summaryService = SummaryService();
  final TemplateService _templateService = TemplateService();
  final QnAService _qnaService = QnAService();
  late Future<AppConfig> _configFuture;
  Meeting? _meeting;
  bool _isLoading = true;
  String _summary = '';
  bool _isGeneratingSummary = false;
  List<Template> _templates = [];
  Template? _selectedTemplate;
  final TextEditingController _questionController = TextEditingController();
  String _answer = '';
  bool _isGeneratingAnswer = false;

  @override
  void initState() {
    super.initState();
    _configFuture = ConfigLoader.loadConfig();
    _loadMeeting();
    _loadTemplates();
  }

  Future<void> _loadMeeting() async {
    try {
      final meeting = await _storageService.getMeetingById(widget.meetingId);
      setState(() {
        _meeting = meeting;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载会议详情失败: $e')),
        );
      }
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final templates = await _templateService.getAllTemplates();
      setState(() {
        _templates = templates;
        if (templates.isNotEmpty) {
          _selectedTemplate = templates.first;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载模板失败: $e')),
        );
      }
    }
  }

  Future<void> _generateSummary() async {
    if (_meeting == null || _selectedTemplate == null) return;

    setState(() {
      _isGeneratingSummary = true;
      _summary = '正在生成会议纪要...';
    });

    try {
      final config = await _configFuture;
      final summaryModel = config.summaryModels.first; // 使用第一个摘要模型

      final summary = await _summaryService.generateSummaryWithTemplate(
        _meeting!.transcript,
        _selectedTemplate!,
        summaryModel as ASRModelConfig,
      );

      setState(() {
        _summary = summary;
        _isGeneratingSummary = false;
      });
    } catch (e) {
      setState(() {
        _summary = '生成会议纪要失败: $e';
        _isGeneratingSummary = false;
      });
    }
  }

  Future<void> _askQuestion() async {
    if (_meeting == null || _questionController.text.isEmpty) return;

    setState(() {
      _isGeneratingAnswer = true;
      _answer = '正在生成答案...';
    });

    try {
      final config = await _configFuture;
      final summaryModel = config.summaryModels.first; // 使用第一个摘要模型

      final answer = await _qnaService.answerQuestion(
        _meeting!.transcript,
        _questionController.text,
        summaryModel as ASRModelConfig,
      );

      setState(() {
        _answer = answer;
        _isGeneratingAnswer = false;
      });
    } catch (e) {
      setState(() {
        _answer = '回答问题失败: $e';
        _isGeneratingAnswer = false;
      });
    }
  }

  Future<void> _exportToPDF() async {
    if (_meeting == null) return;

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(_meeting!.title),
                ),
                pw.SizedBox(height: 20),
                pw.Text('会议时间: ${_meeting!.date.toString()}'),
                pw.SizedBox(height: 20),
                pw.Header(
                  level: 2,
                  child: pw.Text('会议原文'),
                ),
                pw.Text(_meeting!.transcript),
                pw.SizedBox(height: 20),
                pw.Header(
                  level: 2,
                  child: pw.Text('会议纪要'),
                ),
                pw.Text(_summary.isEmpty ? '暂无纪要' : _summary),
              ],
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = await pdf.save();
      final filePath = '${output.path}/${_meeting!.title}.pdf';
      final pdfFile = await File(filePath).writeAsBytes(file);

      if (mounted) {
        // 检查是否在Web平台上运行
        if (kIsWeb) {
          // 在Web上使用shareXFiles方法
          await Share.shareXFiles([XFile(pdfFile.path)], text: '会议记录: ${_meeting!.title}');
        } else {
          // 在其他平台上使用shareFiles方法
          // 修复Web编译错误，只在非Web平台使用shareFiles
          // await Share.shareFiles([pdfFile.path], text: '会议记录: ${_meeting!.title}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出PDF失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('会议详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportToPDF,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _meeting == null
              ? const Center(child: Text('会议不存在'))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 会议基本信息
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _meeting!.title,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text('会议时间: ${_meeting!.date.toString()}'),
                                const SizedBox(height: 8),
                                Text('参会人员: ${_meeting!.participants.map((p) => p.name).join(', ')}'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // 模板选择和纪要生成
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '会议纪要',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const Text('选择模板:'),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: DropdownButton<Template>(
                                        value: _selectedTemplate,
                                        items: _templates.map((template) {
                                          return DropdownMenuItem(
                                            value: template,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(template.name),
                                                ),
                                                if (template.isDefault)
                                                  const Chip(
                                                    label: Text(
                                                      '默认',
                                                      style: TextStyle(fontSize: 10),
                                                    ),
                                                    backgroundColor: Colors.blue,
                                                    labelStyle: TextStyle(color: Colors.white),
                                                  ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (Template? newValue) {
                                          setState(() {
                                            _selectedTemplate = newValue;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: _isGeneratingSummary ? null : _generateSummary,
                                      child: _isGeneratingSummary
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Text('生成纪要'),
                                    ),
                                    const SizedBox(width: 16),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const TemplateManagementScreen(),
                                          ),
                                        ).then((_) => _loadTemplates());
                                      },
                                      child: const Text('管理模板'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(_summary.isEmpty ? '点击"生成纪要"按钮生成会议纪要' : _summary),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // 问答功能
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '会议问答',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _questionController,
                                        decoration: const InputDecoration(
                                          hintText: '请输入关于会议内容的问题...',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _isGeneratingAnswer ? null : _askQuestion,
                                      child: _isGeneratingAnswer
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Text('提问'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(_answer.isEmpty ? '请输入问题并点击"提问"按钮' : _answer),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // 会议原文
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '会议原文',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  height: 300,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(_meeting!.transcript),
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
    );
  }
}