import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:meeting_note/services/audio_capturer_interface.dart';
import 'package:meeting_note/services/webrtc_audio_capturer.dart';
import 'package:meeting_note/services/raw_audio_capturer.dart';
import 'package:meeting_note/services/platform_audio_capturer.dart';
import 'dart:io' show Platform;

// 仅在非Web平台上定义这些getter
bool get kIsAndroid => !kIsWeb && Platform.isAndroid;
bool get kIsIOS => !kIsWeb && Platform.isIOS;
bool get kIsWindows => !kIsWeb && Platform.isWindows;
bool get kIsMacOS => !kIsWeb && Platform.isMacOS;
bool get kIsLinux => !kIsWeb && Platform.isLinux;

class AudioCapturerFactory {
  /// Create an appropriate audio capturer based on the platform
  static AudioCapturer createAudioCapturer() {
    // 根据平台选择不同的音频捕获器
    if (kIsWeb) {
      // On web, use WebRTC capturer
      return WebRTCAudioCapturer();
    } else if (kIsAndroid || kIsIOS) {
      // On mobile platforms, use platform-specific audio capturer
      return PlatformAudioCapturer();
    } else {
      // On desktop platforms (Windows, macOS, Linux), use WebRTC capturer as fallback
      return WebRTCAudioCapturer();
    }
  }
}