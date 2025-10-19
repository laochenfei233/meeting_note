import 'package:flutter/material.dart';
import 'package:meeting_note/screens/meeting_detail_screen.dart';
import 'package:meeting_note/screens/recording_screen.dart';
import 'package:meeting_note/models/meeting.dart';
import 'package:meeting_note/services/storage_service.dart';

class MeetingListScreen extends StatefulWidget {
  const MeetingListScreen({super.key});

  @override
  State<MeetingListScreen> createState() => _MeetingListScreenState();
}

class _MeetingListScreenState extends State<MeetingListScreen> {
  final StorageService _storageService = StorageService();
  final TextEditingController _searchController = TextEditingController();
  List<Meeting>? _filteredMeetings;
  bool _isSearching = false;
  String? _databaseError;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterMeetings);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterMeetings);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _filterMeetings() async {
    setState(() {
      _isSearching = _searchController.text.isNotEmpty;
    });
    
    if (_isSearching) {
      try {
        final meetings = await _storageService.searchMeetings(_searchController.text);
        setState(() {
          _filteredMeetings = meetings;
          _databaseError = null;
        });
      } catch (e) {
        setState(() {
          _databaseError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索会议...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _isSearching = false;
                            _filteredMeetings = null;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Meeting>>(
              future: _isSearching 
                  ? Future.value(_filteredMeetings) 
                  : _storageService.loadMeetings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '数据库错误',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '请确保系统已安装SQLite库。在Debian/Ubuntu系统上，可以运行:\n\nsudo apt-get install libsqlite3-0',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  // 确保在空状态时也能正确显示FloatingActionButton
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.meeting_room_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '暂无会议记录',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '点击右下角按钮开始新会议',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  final meetings = snapshot.data!;
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: meetings.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final meeting = meetings[index];
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16.0),
                          title: Text(
                            meeting.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                          ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${meeting.date.year}-${meeting.date.month.toString().padLeft(2, '0')}-${meeting.date.day.toString().padLeft(2, '0')} ${meeting.date.hour.toString().padLeft(2, '0')}:${meeting.date.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                              if (meeting.summary.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  meeting.summary.length > 100 
                                      ? '${meeting.summary.substring(0, 100)}...' 
                                      : meeting.summary,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MeetingDetailScreen(meetingId: meeting.id!),
                              ),
                            );
                          },
                        ),
                      );
                    }
                  );
                }
              }
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecordingScreen(),
                ),
              ).then((_) => setState(() {}));
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: () {
              setState(() {});
            },
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}