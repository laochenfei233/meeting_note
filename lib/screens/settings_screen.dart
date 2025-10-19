import 'package:flutter/material.dart';
import 'package:meeting_note/utils/config_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meeting_note/services/config_service.dart';
import 'package:meeting_note/services/asr_service.dart';
import 'package:meeting_note/services/summary_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<AppConfig> _configFuture;
  bool _darkMode = false;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _configFuture = ConfigLoader.loadConfig();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
  }

  // Function to show dialog for editing ASR model
  void _editASRModel(BuildContext context, ASRModelConfig model, int index) async {
    final nameController = TextEditingController(text: model.name);
    final urlController = TextEditingController(text: model.url);
    final keyController = TextEditingController(text: model.key);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('编辑 ASR 模型 - ${model.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: 'URL'),
                ),
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(labelText: 'API Key'),
                ),
                if (model.name == 'Aliyun')
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      '阿里云ASR参考文档:\n'
                      'https://help.aliyun.com/zh/model-studio/use-qwen-by-calling-api#69cac67a477k2\n'
                      'https://bailian.console.aliyun.com/?tab=doc#/doc/?type=model&url=2979031',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Update the model
                final config = await _configFuture;
                final updatedModels = List<ASRModelConfig>.from(config.asrModels);
                updatedModels[index] = ASRModelConfig(
                  name: nameController.text,
                  url: urlController.text,
                  key: keyController.text,
                );
                
                // Save to config service
                await ConfigService.saveASRModels(updatedModels);
                
                // Reload config
                setState(() {
                  _configFuture = ConfigLoader.loadConfig();
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ASR模型配置已更新')),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  // Function to show dialog for adding new ASR model
  void _addASRModel(BuildContext context) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final keyController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('添加 ASR 模型'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: 'URL'),
                ),
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(labelText: 'API Key'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Add new model
                final config = await _configFuture;
                final updatedModels = List<ASRModelConfig>.from(config.asrModels);
                updatedModels.add(ASRModelConfig(
                  name: nameController.text,
                  url: urlController.text,
                  key: keyController.text,
                ));
                
                // Save to config service
                await ConfigService.saveASRModels(updatedModels);
                
                // Reload config
                setState(() {
                  _configFuture = ConfigLoader.loadConfig();
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('新的ASR模型已添加')),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  // Function to show dialog for editing Summary model
  void _editSummaryModel(BuildContext context, SummaryModelConfig model, int index) async {
    final nameController = TextEditingController(text: model.name);
    final urlController = TextEditingController(text: model.url);
    final keyController = TextEditingController(text: model.key);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('编辑摘要模型 - ${model.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: 'URL'),
                ),
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(labelText: 'API Key'),
                ),
                if (model.name == 'Qwen')
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      '通义千问参考文档:\n'
                      'https://help.aliyun.com/zh/model-studio/use-qwen-by-calling-api',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Update the model
                final config = await _configFuture;
                final updatedModels = List<SummaryModelConfig>.from(config.summaryModels);
                updatedModels[index] = SummaryModelConfig(
                  name: nameController.text,
                  url: urlController.text,
                  key: keyController.text,
                );
                
                // Save to config service
                await ConfigService.saveSummaryModels(updatedModels);
                
                // Reload config
                setState(() {
                  _configFuture = ConfigLoader.loadConfig();
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('摘要模型配置已更新')),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  // Function to show dialog for adding new Summary model
  void _addSummaryModel(BuildContext context) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final keyController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('添加摘要模型'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: 'URL'),
                ),
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(labelText: 'API Key'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Add new model
                final config = await _configFuture;
                final updatedModels = List<SummaryModelConfig>.from(config.summaryModels);
                updatedModels.add(SummaryModelConfig(
                  name: nameController.text,
                  url: urlController.text,
                  key: keyController.text,
                ));
                
                // Save to config service
                await ConfigService.saveSummaryModels(updatedModels);
                
                // Reload config
                setState(() {
                  _configFuture = ConfigLoader.loadConfig();
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('新的摘要模型已添加')),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  // Function to show dialog for editing S3 configuration
  void _editS3Config(BuildContext context, S3Config config) async {
    final bucketController = TextEditingController(text: config.bucket);
    final regionController = TextEditingController(text: config.region);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('编辑 S3 配置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: bucketController,
                  decoration: const InputDecoration(labelText: 'Bucket'),
                ),
                TextField(
                  controller: regionController,
                  decoration: const InputDecoration(labelText: 'Region'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Update S3 config
                final updatedConfig = S3Config(
                  bucket: bucketController.text,
                  region: regionController.text,
                );
                
                // Save to config service
                await ConfigService.saveS3Config(updatedConfig);
                
                // Reload config
                setState(() {
                  _configFuture = ConfigLoader.loadConfig();
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('S3配置已更新')),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  // Function to show dialog for editing WebDAV configuration
  void _editWebDAVConfig(BuildContext context, WebDAVConfig config) async {
    final urlController = TextEditingController(text: config.url);
    final usernameController = TextEditingController(text: config.username);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('编辑 WebDAV 配置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: 'URL'),
                ),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: '用户名'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Update WebDAV config
                final updatedConfig = WebDAVConfig(
                  url: urlController.text,
                  username: usernameController.text,
                );
                
                // Save to config service
                await ConfigService.saveWebDAVConfig(updatedConfig);
                
                // Reload config
                setState(() {
                  _configFuture = ConfigLoader.loadConfig();
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('WebDAV配置已更新')),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: FutureBuilder<AppConfig>(
        future: _configFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading config: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No configuration data'));
          } else {
            final config = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '用户设置',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('暗色主题'),
                    value: _darkMode,
                    onChanged: (value) {
                      setState(() {
                        _darkMode = value;
                      });
                      _saveSettings();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('启用通知'),
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                      _saveSettings();
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ASR 模型',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          _addASRModel(context);
                        },
                        child: const Text('添加'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (config.asrModels.isNotEmpty)
                    for (var i = 0; i < config.asrModels.length; i++)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          title: Text(config.asrModels[i].name),
                          subtitle: Text(config.asrModels[i].url),
                          trailing: const Icon(Icons.edit),
                          onTap: () {
                            _editASRModel(context, config.asrModels[i], i);
                          },
                        ),
                      )
                  else
                    const Text('未配置 ASR 模型'),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '摘要模型',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          _addSummaryModel(context);
                        },
                        child: const Text('添加'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (config.summaryModels.isNotEmpty)
                    for (var i = 0; i < config.summaryModels.length; i++)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          title: Text(config.summaryModels[i].name),
                          subtitle: Text(config.summaryModels[i].url),
                          trailing: const Icon(Icons.edit),
                          onTap: () {
                            _editSummaryModel(context, config.summaryModels[i], i);
                          },
                        ),
                      )
                  else
                    const Text('未配置摘要模型'),
                  const SizedBox(height: 20),
                  const Text(
                    '存储配置',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      title: const Text('S3 配置'),
                      subtitle: Text('Bucket: ${config.storage.s3.bucket.isEmpty ? '未设置' : config.storage.s3.bucket}'),
                      trailing: const Icon(Icons.edit),
                      onTap: () {
                        _editS3Config(context, config.storage.s3);
                      },
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      title: const Text('WebDAV 配置'),
                      subtitle: Text('URL: ${config.storage.webdav.url.isEmpty ? '未设置' : config.storage.webdav.url}'),
                      trailing: const Icon(Icons.edit),
                      onTap: () {
                        _editWebDAVConfig(context, config.storage.webdav);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '关于',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Card(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      title: Text('Meeting Note'),
                      subtitle: Text('Version 1.0.0'),
                    ),
                  ),
                ],
              ),
            );
          }
        }
      ),
    );
  }
}