import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:meeting_note/services/asr_service.dart';
import 'package:meeting_note/models/template.dart';

class SummaryService {
  final Dio _dio = Dio();
  
  /// Generate meeting summary using template
  Future<String> generateSummaryWithTemplate(
    String transcript, 
    Template template, 
    ASRModelConfig config
  ) async {
    try {
      // Replace placeholder in template prompt with actual transcript
      final prompt = template.prompt.replaceFirst('{{content}}', transcript);
      
      final response = await _dio.post(
        config.url,
        data: _buildTemplateRequestData(prompt, config),
        options: Options(
          headers: _buildHeaders(config.key),
        ),
      );
      
      if (response.statusCode == 200) {
        final result = response.data;
        // Parse the response based on the model
        if (config.name.contains('Aliyun') || config.name.contains('Qwen')) {
          // Handle Aliyun/Qwen response
          try {
            // Try to parse as JSON first
            if (result is Map<String, dynamic>) {
              // Direct JSON response
              return result['output']['text'] ?? result.toString();
            } else if (result is String) {
              // Might be a JSON string
              final jsonResult = jsonDecode(result);
              return jsonResult['output']['text'] ?? result;
            }
            return result.toString();
          } catch (e) {
            // If parsing fails, return as string
            return result.toString();
          }
        } else if (config.name.contains('Local')) {
          return result['text'] ?? result.toString();
        }
        return result.toString();
      } else {
        throw Exception('Summary generation failed with status: ${response.statusCode}');
      }
    } catch (error, stackTrace) {
      print('Summary generation error: $error');
      print('Stack trace: $stackTrace');
      throw Exception('Summary generation failed: $error');
    }
  }

  /// Real-time summary generation using template
  Future<String> realSummaryGenerationWithTemplate(
    String transcript, 
    Template template, 
    ASRModelConfig config
  ) async {
    // For now, we'll use the same implementation as generateSummaryWithTemplate
    // In a real implementation, this might use streaming or other real-time techniques
    return await generateSummaryWithTemplate(transcript, template, config);
  }
  
  /// Generate meeting summary (existing method, updated to support templates)
  Future<String> generateSummary(String transcript, String modelName, ASRModelConfig config) async {
    try {
      final response = await _dio.post(
        config.url,
        data: _buildRequestData(transcript, modelName, config),
        options: Options(
          headers: _buildHeaders(config.key),
        ),
      );
      
      if (response.statusCode == 200) {
        final result = response.data;
        // Parse the response based on the model
        if (modelName.contains('Aliyun') || modelName.contains('Qwen')) {
          // Handle Aliyun/Qwen response
          try {
            // Try to parse as JSON first
            if (result is Map<String, dynamic>) {
              // Direct JSON response
              return result['output']['text'] ?? result.toString();
            } else if (result is String) {
              // Might be a JSON string
              final jsonResult = jsonDecode(result);
              return jsonResult['output']['text'] ?? result;
            }
            return result.toString();
          } catch (e) {
            // If parsing fails, return as string
            return result.toString();
          }
        } else if (modelName.contains('Local')) {
          return result['text'] ?? result.toString();
        }
        return result.toString();
      } else {
        throw Exception('Summary generation failed with status: ${response.statusCode}');
      }
    } catch (error, stackTrace) {
      print('Summary generation error: $error');
      print('Stack trace: $stackTrace');
      throw Exception('Summary generation failed: $error');
    }
  }
  
  /// Real-time summary generation (existing method)
  Future<String> realSummaryGeneration(String transcript, String modelName, ASRModelConfig config) async {
    return await generateSummary(transcript, modelName, config);
  }
  
  Map<String, dynamic> _buildTemplateRequestData(String prompt, ASRModelConfig config) {
    // Check if this is an Aliyun/Qwen model
    if (config.name.contains('Aliyun') || config.name.contains('Qwen')) {
      return {
        'model': config.modelName ?? 'qwen-plus', // Default to qwen-plus if not specified
        'input': {
          'prompt': prompt,
        },
        'parameters': {
          'enable_search': false, // Disable web search for meeting summaries
        }
      };
    } else if (config.name.contains('Local')) {
      return {
        'prompt': prompt,
      };
    }
    
    // Default structure
    return {
      'prompt': prompt,
    };
  }
  
  Map<String, dynamic> _buildRequestData(String transcript, String modelName, ASRModelConfig config) {
    // Check if this is an Aliyun/Qwen model
    if (modelName.contains('Aliyun') || modelName.contains('Qwen')) {
      return {
        'model': config.modelName ?? 'qwen-plus',
        'input': {
          'prompt': '请为以下会议内容生成摘要:\n\n$transcript',
        },
        'parameters': {
          'enable_search': false,
        }
      };
    } else if (modelName.contains('Local')) {
      return {
        'prompt': '请为以下会议内容生成摘要:\n\n$transcript',
      };
    }
    
    // Default structure
    return {
      'prompt': '请为以下会议内容生成摘要:\n\n$transcript',
    };
  }
  
  Map<String, String> _buildHeaders(String apiKey) {
    return {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
  }
}

class SummaryModelConfig {
  final String name;
  final String url;
  final String key;
  
  SummaryModelConfig({
    required this.name,
    required this.url,
    required this.key,
  });
  
  factory SummaryModelConfig.fromJson(Map<String, dynamic> json) {
    return SummaryModelConfig(
      name: json['name'],
      url: json['url'],
      key: json['key'] ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'key': key,
    };
  }
}