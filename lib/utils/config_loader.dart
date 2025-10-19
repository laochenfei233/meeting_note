import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:meeting_note/services/asr_service.dart';
import 'package:meeting_note/services/summary_service.dart';
import 'package:meeting_note/services/config_service.dart';

class ConfigLoader {
  static Future<AppConfig> loadConfig() async {
    try {
      // Load default config from assets
      final jsonString = await rootBundle.loadString('assets/config.json');
      final jsonData = json.decode(jsonString);
      
      // Load user saved configurations
      final userASRModels = await ConfigService.loadASRModels();
      final userSummaryModels = await ConfigService.loadSummaryModels();
      final userS3Config = await ConfigService.loadS3Config();
      final userWebDAVConfig = await ConfigService.loadWebDAVConfig();
      
      final List<ASRModelConfig> asrModels = [];
      if (userASRModels.isNotEmpty) {
        // Use user configured models if available
        asrModels.addAll(userASRModels);
      } else if (jsonData['asr_models'] != null) {
        // Fallback to default models
        for (var model in jsonData['asr_models']) {
          asrModels.add(ASRModelConfig.fromJson(model));
        }
      }
      
      final List<SummaryModelConfig> summaryModels = [];
      if (userSummaryModels.isNotEmpty) {
        // Use user configured models if available
        summaryModels.addAll(userSummaryModels);
      } else if (jsonData['summary_models'] != null) {
        // Fallback to default models
        for (var model in jsonData['summary_models']) {
          summaryModels.add(SummaryModelConfig.fromJson(model));
        }
      }
      
      final StorageConfig storage = StorageConfig(
        s3: userS3Config.bucket.isNotEmpty ? userS3Config : 
             jsonData['storage'] != null && jsonData['storage']['s3'] != null 
             ? S3Config.fromJson(jsonData['storage']['s3']) 
             : S3Config(bucket: '', region: ''),
        webdav: userWebDAVConfig.url.isNotEmpty ? userWebDAVConfig : 
                jsonData['storage'] != null && jsonData['storage']['webdav'] != null 
                ? WebDAVConfig.fromJson(jsonData['storage']['webdav']) 
                : WebDAVConfig(url: '', username: ''),
      );
      
      return AppConfig(
        asrModels: asrModels,
        summaryModels: summaryModels,
        storage: storage,
      );
    } catch (e) {
      // Return default config if loading fails
      return AppConfig(
        asrModels: [],
        summaryModels: [],
        storage: StorageConfig(s3: S3Config(bucket: '', region: ''), webdav: WebDAVConfig(url: '', username: '')),
      );
    }
  }
}

class AppConfig {
  final List<ASRModelConfig> asrModels;
  final List<SummaryModelConfig> summaryModels;
  final StorageConfig storage;
  
  AppConfig({
    required this.asrModels,
    required this.summaryModels,
    required this.storage,
  });
}

class StorageConfig {
  final S3Config s3;
  final WebDAVConfig webdav;
  
  StorageConfig({
    required this.s3,
    required this.webdav,
  });
  
  factory StorageConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return StorageConfig(
        s3: S3Config(bucket: '', region: ''),
        webdav: WebDAVConfig(url: '', username: ''),
      );
    }
    
    return StorageConfig(
      s3: S3Config.fromJson(json['s3']),
      webdav: WebDAVConfig.fromJson(json['webdav']),
    );
  }
}

class S3Config {
  final String bucket;
  final String region;
  
  S3Config({
    required this.bucket,
    required this.region,
  });
  
  factory S3Config.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return S3Config(bucket: '', region: '');
    }
    
    return S3Config(
      bucket: json['bucket'] ?? '',
      region: json['region'] ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'bucket': bucket,
      'region': region,
    };
  }
}

class WebDAVConfig {
  final String url;
  final String username;
  
  WebDAVConfig({
    required this.url,
    required this.username,
  });
  
  factory WebDAVConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return WebDAVConfig(url: '', username: '');
    }
    
    return WebDAVConfig(
      url: json['url'] ?? '',
      username: json['username'] ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'username': username,
    };
  }
}