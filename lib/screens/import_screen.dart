import 'dart:io';
import 'package:flutter/material.dart';
import 'package:meeting_note/models/meeting.dart';
import 'package:meeting_note/services/storage_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final StorageService _storageService = StorageService();
  List<FileSystemEntity> _files = [];
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    try {
      final directory = await _storageService.getDocumentsDirectory();
      final files = directory.listSync();
      setState(() {
        _files = files.where((file) => file is File).toList();
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load files: $e';
      });
    }
  }

  Future<void> _pickAndImportFile() async {
    try {
      // Simplified file picking for demo purposes
      setState(() {
        _status = 'File import functionality needs to be implemented';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File import functionality needs to be implemented')),
        );
      }
    } catch (e) {
      setState(() {
        _status = 'Import failed: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Meeting'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _pickAndImportFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Select File to Import'),
            ),
            const SizedBox(height: 20),
            Text(_status),
            const SizedBox(height: 20),
            const Text(
              'Recently Imported Files',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _files.isEmpty
                  ? const Center(child: Text('No files found'))
                  : ListView.builder(
                      itemCount: _files.length,
                      itemBuilder: (context, index) {
                        final file = _files[index] as File;
                        return ListTile(
                          title: Text(file.path.split('/').last),
                          subtitle: Text('${(file.lengthSync() / 1024).toStringAsFixed(2)} KB'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
