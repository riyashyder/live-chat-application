# Live Chat Application

A real-time messaging application built with Flutter and Firebase.

## Features

- **Real-Time Messaging**: Instant message delivery using Firebase Firestore.
- **User Authentication**: Secure sign-in with email/password and Google.
- **Media Sharing**: Send and receive images, videos, and voice notes.
- **Cloud Storage**: All media files are securely stored on Cloudinary.
- **Profile Management**: Users can update their profile picture and username.
- **Status Indicators**: Real-time online/offline status and last seen timestamps.
- **Message Status**: Track message delivery and read receipts.
- **UI/UX**:
  - Modern, glassmorphism-based design.
  - Dark and light theme support.
  - Smooth animations and transitions.
  - Message reactions (likes).
  - Media viewer with zoom support.

## Tech Stack

- **Framework**: Flutter
- **Language**: Dart
- **State Management**: Riverpod
- **Backend**: Firebase (Authentication, Firestore, Storage)
- **Cloud Storage**: Cloudinary
- **Networking**: Dio
- **Media Handling**: `image_picker`, `record`, `audioplayers`
- **Utilities**: `intl`, `uuid`, `path_provider`, `permission_handler`

## Getting Started

### Prerequisites

- Flutter SDK (version 3.0.0 or higher)
- Firebase CLI
- Cloudinary Account

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd chat-application-firebase
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Follow the official FlutterFire documentation to add Firebase to your Flutter project.
   - Ensure `firebase_options.dart` is correctly configured for your project.

4. Configure Cloudinary:
   - Update `lib/core/constants/cloudinary_constants.dart` with your Cloudinary credentials:
     ```dart
     const String cloudinaryCloudName = 'your_cloud_name';
     const String cloudinaryApiKey = 'your_api_key';
     const String cloudinaryApiSecret = 'your_api_secret';
     ```

### Running the App

```bash
flutter run
```

## Project Structure

```
lib/
├── app.dart                 # Main application widget and navigation
├── core/
│   ├── constants/           # Constants and configuration
│   ├── providers/           # Riverpod providers
│   ├── services/            # Services (Firebase, Cloudinary, etc.)
│   └── utils/               # Utility functions
├── features/
│   ├── auth/                # Authentication flows
│   ├── chat/                # Chat features
│   └── profile/             # Profile management
└── main.dart                # Application entry point
```

## Firebase Setup

To run this application, you need to set up a Firebase project with the following enabled:

1. **Authentication**: Email/Password and Google Sign-In
2. **Firestore Database**: For storing chat messages and user data
3. **Cloud Storage**: For storing media files

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
