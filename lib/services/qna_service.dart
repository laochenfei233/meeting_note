import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:meeting_note/services/asr_service.dart';

class QnAService {
  final Dio _dio = Dio();

  /// 根据会议内容回答问题
  Future<String> answerQuestion(
    String transcript,
    String question,
    ASRModelConfig config,
  ) async {
    try {
      // 构造prompt，包含会议内容和用户问题
      final prompt = '''
请根据以下会议内容回答问题。

会议内容：
$transcript

问题：
$question

请基于会议内容回答问题，如果会议内容中没有相关信息，请说明"在会议内容中未找到相关信息"。
''';

      final response = await _dio.post(
        config.url,
        data: _buildRequestData(prompt, config),
        options: Options(
          headers: _buildHeaders(config.key),
        ),
      );

      if (response.statusCode == 200) {
        final result = response.data;
        // 根据模型解析响应
        if (config.name.contains('Aliyun') || config.name.contains('Qwen')) {
          try {
            if (result is Map<String, dynamic>) {
              return result['output']['text'] ?? result.toString();
            } else if (result is String) {
              final jsonResult = jsonDecode(result);
              return jsonResult['output']['text'] ?? result;
            }
            return result.toString();
          } catch (e) {
            return result.toString();
          }
        } else if (config.name.contains('Local')) {
          return result['text'] ?? result.toString();
        }
        return result.toString();
      } else {
        throw Exception('Q&A failed with status: ${response.statusCode}');
      }
    } catch (error, stackTrace) {
      print('Q&A error: $error');
      print('Stack trace: $stackTrace');
      throw Exception('Q&A failed: $error');
    }
  }

  /// 实时问答
  Stream<String> realTimeQnA(
    String transcript,
    String question,
    ASRModelConfig config,
  ) async* {
    try {
      // 构造prompt
      final prompt = '''
请根据以下会议内容回答问题。

会议内容：
$transcript

问题：
$question

请基于会议内容回答问题，如果会议内容中没有相关信息，请说明"在会议内容中未找到相关信息"。
''';

      // 对于流式输出，我们直接返回完整答案
      final answer = await answerQuestion(transcript, question, config);
      yield answer;
    } catch (error) {
      yield '问答过程中出现错误: $error';
    }
  }

  Map<String, dynamic> _buildRequestData(String prompt, ASRModelConfig config) {
    // 检查是否为阿里云/通义模型
    if (config.name.contains('Aliyun') || config.name.contains('Qwen')) {
      return {
        'model': config.modelName ?? 'qwen-plus', // 默认使用qwen-plus
        'input': {
          'prompt': prompt,
        },
        'parameters': {
          'enable_search': false, // 关闭网络搜索，仅基于提供的会议内容回答
          'temperature': 0.7, // 适当的创造性
          'max_tokens': 1000, // 限制回答长度
        }
      };
    } else if (config.name.contains('Local')) {
      return {
        'prompt': prompt,
        'max_tokens': 1000,
        'temperature': 0.7,
      };
    }

    // 默认结构
    return {
      'prompt': prompt,
      'max_tokens': 1000,
      'temperature': 0.7,
    };
  }

  Map<String, String> _buildHeaders(String apiKey) {
    return {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
  }
}