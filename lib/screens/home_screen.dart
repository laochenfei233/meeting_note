import 'package:flutter/material.dart';
import 'package:meeting_note/widgets/sidebar.dart';
import 'package:meeting_note/screens/meeting_list_screen.dart';
import 'package:meeting_note/screens/recording_screen.dart';
import 'package:meeting_note/screens/audio_test_screen.dart';
import 'package:meeting_note/screens/settings_screen.dart';
import 'package:meeting_note/screens/import_screen.dart';
import 'package:meeting_note/screens/statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = <Widget>[
    MeetingListScreen(),
    StatisticsScreen(),
    AudioTestScreen(), // 添加这一行
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meeting Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          Expanded(
            flex: 1,
            child: Sidebar(
              currentIndex: _selectedIndex,
              onItemTapped: _onItemTapped,
            ),
          ),
          // Main content
          Expanded(
            flex: 3,
            child: _screens[_selectedIndex],
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RecordingScreen()),
                );
              },
              child: const Icon(Icons.mic),
            )
          : _selectedIndex == 1
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AudioTestScreen()), // 添加这一行
                    );
                  },
                  child: const Icon(Icons.hearing),
                )
              : null,
    );
  }
}
