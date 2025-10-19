import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:meeting_note/models/meeting.dart';

class StorageService {
  static Database? _database;
  
  StorageService() {
    // Initialize database factory for desktop platforms
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      try {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      } catch (e) {
        print('Failed to initialize FFI database factory: $e');
        // Fallback to default factory if FFI initialization fails
      }
    }
  }
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }
  
  Future<Directory> getDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }
  
  Future<Database> _initDB() async {
    // 在Web平台上返回一个模拟的数据库实现
    if (kIsWeb) {
      // Web平台使用内存数据库
      return await openDatabase(inMemoryDatabasePath, version: 1,
          onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE meetings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            date TEXT,
            transcript TEXT,
            summary TEXT
          )
        ''');
      });
    }
    
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'meetings.db');
    
    try {
      return await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE meetings (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT,
              date TEXT,
              transcript TEXT,
              summary TEXT
            )
          ''');
        },
      );
    } catch (e) {
      print('Error opening database: $e');
      rethrow;
    }
  }
  
  /// Save meeting data to local storage
  Future<int> saveMeeting(Meeting meeting) async {
    final db = await database;
    return await db.insert('meetings', meeting.toMap());
  }
  
  /// Update meeting data in local storage
  Future<int> updateMeeting(Meeting meeting) async {
    final db = await database;
    return await db.update(
      'meetings', 
      meeting.toMap(),
      where: 'id = ?',
      whereArgs: [meeting.id],
    );
  }
  
  /// Delete meeting from local storage
  Future<int> deleteMeeting(int id) async {
    final db = await database;
    return await db.delete(
      'meetings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  /// Load all meetings from local storage
  Future<List<Meeting>> loadMeetings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('meetings', orderBy: 'date DESC');
    return List.generate(maps.length, (i) {
      return Meeting.fromMap(maps[i]);
    });
  }
  
  /// Load a specific meeting by ID
  Future<Meeting?> loadMeeting(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'meetings',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return Meeting.fromMap(maps.first);
    }
    return null;
  }
  
  /// Get meeting by ID (alias for loadMeeting)
  Future<Meeting> getMeetingById(int id) async {
    final meeting = await loadMeeting(id);
    if (meeting == null) {
      throw Exception('Meeting not found with id: $id');
    }
    return meeting;
  }
  
  /// Search meetings by keyword
  Future<List<Meeting>> searchMeetings(String keyword) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'meetings',
      where: 'title LIKE ? OR transcript LIKE ? OR summary LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%', '%$keyword%'],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) {
      return Meeting.fromMap(maps[i]);
    });
  }
  
  /// Export meeting to file
  Future<void> exportMeeting(Meeting meeting, String format, String filePath) async {
    switch (format) {
      case 'txt':
        await File(filePath).writeAsString(meeting.transcript);
        break;
      case 'json':
        await File(filePath).writeAsString(jsonEncode(meeting.toMap()));
        break;
      default:
        throw Exception('Unsupported export format: $format');
    }
  }
  
  /// Import meeting from file
  Future<Meeting> importMeeting(String format, String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }
    
    switch (format) {
      case 'txt':
        final content = await file.readAsString();
        return Meeting(
          title: 'Imported Meeting',
          date: DateTime.now(),
          transcript: content,
          summary: 'Imported from TXT file',
        );
      case 'json':
        final content = await file.readAsString();
        final map = jsonDecode(content);
        return Meeting.fromMap(map);
      default:
        throw Exception('Unsupported import format: $format');
    }
  }
}