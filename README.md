# Tracking Tots

Tracking Tots is a comprehensive baby tracking application that helps parents and caregivers monitor their baby's daily activities and schedule.

## Overview

Tracking Tots provides an intuitive interface for recording and tracking essential baby care activities, helping parents maintain a consistent routine and monitor their baby's development.

## Features

- **Activity Tracking**:
  - Feeding (breast, bottle)
  - Sleep patterns with wake window calculations
  - Diaper changes
  - Tummy time

- **Task Management**:
  - To-do list with reminders
  - Push notifications for scheduled tasks

- **Communication**:
  - Built-in chatbot for questions and support

- **User Management**:
  - Secure login and registration
  - User-specific data storage

## Technical Details

### Frontend
- **Framework**: Flutter (cross-platform)
- **State Management**: Local state
- **Notifications**: Firebase Cloud Messaging (FCM)
- **Dependencies**:
  - firebase_core/firebase_messaging
  - flutter_local_notifications
  - http
  - intl

### Backend
- **Framework**: Flask (Python)
- **Database**: SQLite
- **Authentication**: BCrypt
- **Push Notifications**: Firebase Admin SDK
- **Additional Services**:
  - Scheduled reminders with APScheduler
  - AI integration with OpenAI API

## Getting Started

### Prerequisites
1. Flutter SDK (latest version)
2. Python 3.8+
3. Firebase project with Cloud Messaging enabled
4. OpenAI API key (optional, for chatbot functionality)

### Setup

#### Backend Setup
1. Clone the repository
2. Install dependencies:
   ```
   pip install flask flask_sqlalchemy flask_cors flask_bcrypt firebase-admin apscheduler openai python-dotenv
   ```
3. Add Firebase credentials:
   - Place `firebase_credentials.json` in the project root
4. Configure environment variables:
   - Create a `.env` file with `OPENAI_API_KEY=your_api_key`
5. Start the server:
   ```
   python baby_backend.py
   ```

#### Frontend Setup
1. Install Flutter dependencies:
   ```
   flutter pub get
   ```
2. Configure Firebase:
   ```
   flutterfire configure
   ```
3. Run the application:
   ```
   flutter run
   ```

## Usage

1. Register an account or log in
2. Navigate to different tracking activities via the home screen
3. Record activities as they occur
4. Set reminders for upcoming tasks
5. View history and patterns of recorded activities

## Contributors

Add your project contributors here.

## License

Specify your project license here.
