import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:meeting_note/screens/home_screen.dart';
import 'package:meeting_note/providers/meeting_provider.dart';
import 'package:provider/provider.dart';
import 'package:meeting_note/utils/theme_utils.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  // Initialize WebRTC for desktop platforms (not on web)
  if (!kIsWeb) {
    WidgetsFlutterBinding.ensureInitialized();
  }
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => MeetingProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meeting Note',
      theme: ThemeUtils.lightTheme,
      darkTheme: ThemeUtils.darkTheme,
      home: const HomeScreen(),
    );
  }
}