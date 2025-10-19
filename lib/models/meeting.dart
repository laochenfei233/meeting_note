class Meeting {
  final int? id;
  final String title;
  final DateTime date;
  final String transcript;
  final String summary;
  final List<Participant> participants;
  
  Meeting({
    this.id,
    required this.title,
    required this.date,
    required this.transcript,
    required this.summary,
    this.participants = const [],
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'transcript': transcript,
      'summary': summary,
    };
  }
  
  factory Meeting.fromMap(Map<String, dynamic> map) {
    return Meeting(
      id: map['id'],
      title: map['title'],
      date: DateTime.parse(map['date']),
      transcript: map['transcript'],
      summary: map['summary'],
      participants: [],
    );
  }
}

class Participant {
  final String id;
  final String name;
  final String? voiceProfile; // For voice recognition
  
  Participant({required this.id, required this.name, this.voiceProfile});
}

class TranscriptSegment {
  final String speakerId;
  final String text;
  final DateTime timestamp;
  
  TranscriptSegment({
    required this.speakerId,
    required this.text,
    required this.timestamp,
  });
}