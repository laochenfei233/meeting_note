# Meeting Note

A multi-model real-time meeting recording system

## Features

- Real-time audio recording and transcription
- Multi-participant meeting support
- AI-powered meeting summaries
- Data statistics and analysis
- Cross-platform support (Web, Desktop, Mobile)

## Supported Platforms

- Web
- Linux
- Windows
- macOS
- Android
- iOS

## Getting Started

### Prerequisites

- Flutter 3.10 or higher
- Dart 3.0 or higher

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/laochenfei233/meeting_note.git
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

### Building

#### Web
```bash
flutter build web
```

#### Desktop (Linux, Windows, macOS)
```bash
# Linux
flutter config --enable-linux-desktop
flutter build linux

# Windows
flutter config --enable-windows-desktop
flutter build windows

# macOS
flutter config --enable-macos-desktop
flutter build macos
```

#### Mobile (Android, iOS)
```bash
# Android
flutter build apk

# iOS
flutter build ios
```

## GitHub Actions

This repository includes GitHub Actions workflows for automated building and releasing:
- Build for all supported platforms
- Create GitHub releases with artifacts

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.