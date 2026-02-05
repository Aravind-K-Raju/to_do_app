# Autarkic Planner - Local-First Student Productivity App

A privacy-focused, offline-first productivity application built for Android using Flutter. Designed for students who want full control over their data without relying on cloud services.

## 🚀 Features

### 1. 🔒 Security & Offline-First
- **App-Level PIN Lock**: Secure entry with `flutter_secure_storage`.
- **Offline Database**: All data is stored locally using `SQFLite`. No internet connection required.
- **Privacy**: No tracking, no cloud sync, no data sharing.

### 2. 📚 Course Management
- Track courses with details (Platform, Progress, Dates).
- status tracking (Not Started, In Progress, Completed).
- Add Course Certificates.

### 3. 🗓️ Planner & Scheduler
- **Calendar View**: Visual monthly planner.
- **Task Management**: Create tasks linked to courses.
- **Daily View**: See tasks due specific dates.

### 4. ⏱️ Study Tracker
- **Focus Timer**: Track study sessions in real-time.
- **Logging**: Automatically saves session duration to the local database.

### 5. 💻 Hackathon Manager
- specialized tracker for Hackathon participations.
- Log themes, tech stacks, team sizes, and outcomes.

### 6. 🧠 Intelligence & Insights
- **On-Device Analytics**: Calculates a daily "Productivity Score" (0-100).
- **Data aggregation**: Combines task completion rates and study minutes to provide actionable feedback.

## 🛠️ Tech Stack & Architecture

- **Framework**: Flutter (Dart)
- **Architecture**: Clean Architecture (Layered)
    - **Presentation**: `Provider` for state management, `Screen` and `Widget` separation.
    - **Domain**: Pure Dart entities, abstract repositories, and use cases.
    - **Data**: Repository implementations, `SQFLite` database helper, `equatable`.
    - **Core**: Theme, Constants.
- **Key Packages**:
    - `sqflite`: Local Database.
    - `provider`: State Management.
    - `flutter_secure_storage`: Secure encryption for PIN.
    - `table_calendar`: Calendar UI.
    - `intl`: Date formatting.

## 📂 Project Structure

```
lib/
├── core/           # data/theme constants
├── data/           # DatabaseHelper, Repository Implementations
├── domain/         # Entities, Repository Interfaces, Use Cases
├── presentation/   # Screens, Providers, Widgets
└── main.dart       # App entry point, MultiProvider setup
```

## 🏁 Getting Started

1.  **Prerequisites**: Ensure you have the Flutter SDK installed.
2.  **Clone**: Clone this repository.
3.  **Dependencies**: Run `flutter pub get` to install packages.
4.  **Run**: Connect an Android device or emulator and run `flutter run`.

---
*Built with ❤️ by Antigravity (Google Deepmind)*
