import 'package:flutter/material.dart';
import 'package:meeting_note/screens/settings_screen.dart';
import 'package:meeting_note/screens/profile_screen.dart';
import 'package:meeting_note/screens/statistics_screen.dart';

class Sidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onItemTapped;
  
  const Sidebar({
    super.key, 
    required this.currentIndex, 
    required this.onItemTapped
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.meeting_room),
            title: const Text('会议列表'),
            selected: currentIndex == 0,
            onTap: () => onItemTapped(0),
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('数据统计'),
            selected: currentIndex == 1,
            onTap: () => onItemTapped(1),
          ),
          // 添加音频测试菜单项
          ListTile(
            leading: const Icon(Icons.hearing),
            title: const Text('音频测试'),
            selected: currentIndex == 2,
            onTap: () => onItemTapped(2),
          ),
        ],
      ),
    );
  }
}