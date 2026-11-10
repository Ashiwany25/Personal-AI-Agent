
# 🤖 Personal AI Agent

### Your AI-Powered Personal Assistant for Android

[![Android](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://www.android.com/)
[![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Python](https://img.shields.io/badge/Backend-FastAPI-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Supabase](https://img.shields.io/badge/Database-Supabase-3FCF8E?logo=supabase&logoColor=white)](https://supabase.com/)
[![Gemini](https://img.shields.io/badge/AI-Google%20Gemini-4285F4?logo=google&logoColor=white)](https://ai.google.dev/)
[![GitHub Release](https://img.shields.io/github/v/release/Ashiwany25/Personal-AI-Agent)](https://github.com/Ashiwany25/Personal-AI-Agent/releases)

**Personal AI Agent** is a cloud-connected Android application built using Flutter, FastAPI, Google Gemini, and Supabase.

It combines an AI-powered chatbot, personal notes, and task management in one mobile application, with secure authentication and cloud synchronization.

---

## 📱 Download Android App

### [⬇️ Download Personal AI Agent v1.0.0](https://github.com/Ashiwany25/Personal-AI-Agent/releases/tag/v1.0.0)

**Latest release:** v1.0.0

**Platform:** Android

**Distribution:** GitHub Releases

### Installation Instructions

1. Open the download link above.
2. Expand the **Assets** section.
3. Download the attached `.apk` file.
4. Open the APK on your Android phone.
5. Allow installation from your browser or file manager if prompted.
6. Tap **Install**.
7. Open **Personal AI Agent**.
8. Create an account or log in.

> An internet connection is required for authentication, AI chat, and cloud synchronization.

> This application is currently distributed through GitHub rather than the Google Play Store.

---

## ✨ Key Features

### 🧠 Gemini AI Chat

- Chat with Google's Gemini AI.
- Ask questions and receive AI-generated responses.
- Use a conversational interface within the Android app.
- Send requests through a FastAPI backend.
- Apply server-side AI usage limits.

### 🔐 Secure Authentication

- Email and password authentication.
- User registration and login.
- Supabase Auth integration.
- Authenticated access to personal information.
- Separate data access for different users.

### 📝 Personal Notes

- Create and save notes.
- View previously saved notes.
- Store notes in Supabase.
- Retrieve notes after restarting the application.
- Keep notes associated with the authenticated user.

### ✅ Task Management

- Create personal tasks.
- View saved tasks.
- Mark tasks as completed.
- Synchronize task data with Supabase.
- Maintain task records across app sessions.

### ☁️ Cloud Synchronization

- Cloud-based storage for notes and tasks.
- Data persistence after closing and reopening the app.
- Account-based access to stored information.
- Supabase PostgreSQL database integration.

### 🛡️ Backend Security

- Server-side Gemini API integration.
- Supabase authentication token validation.
- Row Level Security (RLS) for user data.
- Server-side AI rate limiting.
- Sensitive credentials stored in deployment environment variables.
- Android signing credentials stored in GitHub Actions secrets.

---

## 🏗️ System Architecture

```text
                  ┌───────────────────────┐
                  │     Android User      │
                  └───────────┬───────────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │      Flutter App      │
                  │                       │
                  │  • Login / Signup     │
                  │  • Gemini AI Chat     │
                  │  • Notes              │
                  │  • Tasks              │
                  └───────────┬───────────┘
                              │
                 ┌────────────┴────────────┐
                 │                         │
                 ▼                         ▼
     ┌───────────────────────┐  ┌──────────────────────┐
     │       Supabase        │  │   FastAPI Backend    │
     │                       │  │   Hosted on Render   │
     │ • Authentication      │  │                      │
     │ • PostgreSQL Database │  │ • Token Validation   │
     │ • Row Level Security  │  │ • AI Rate Limiting   │
     │ • Cloud Storage       │  │ • Gemini Requests    │
     └───────────────────────┘  └──────────┬───────────┘
                                          │
                                          ▼
                               ┌──────────────────────┐
                               │    Google Gemini     │
                               │       AI API         │
                               └──────────────────────┘
```

### How It Works

1. The user opens the Flutter Android application.
2. Supabase authenticates the user.
3. Notes and tasks are stored in Supabase PostgreSQL.
4. The user submits a message through AI Chat.
5. Flutter sends an authenticated request to the FastAPI backend.
6. The backend validates the user and checks AI usage limits.
7. The backend communicates with the Gemini API.
8. The AI response is returned to the Android application.

---

## 🛠️ Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| Mobile frontend | Flutter | Android application |
| Programming language | Dart | Mobile app development |
| Backend | Python | Server-side application logic |
| API framework | FastAPI | REST API |
| AI model | Google Gemini | AI-generated responses |
| Authentication | Supabase Auth | User login and registration |
| Database | Supabase PostgreSQL | Notes, tasks, and application data |
| Database security | Supabase RLS | User-level data access control |
| Backend hosting | Render | Cloud API deployment |
| Version control | Git and GitHub | Source code management |
| CI/CD | GitHub Actions | Android APK builds |
| Android signing | Java Keytool | Release signing key |

---

## 📁 Project Structure

```text
Personal-AI-Agent/
│
├── .github/
│   └── workflows/
│       ├── android-apk.yml
│       └── android-release.yml
│
├── api/
│   └── main.py
│
├── flutter_app/
│   ├── lib/
│   │   └── main.dart
│   │
│   ├── test/
│   │
│   ├── pubspec.yaml
│   └── README.md
│
├── .gitignore
└── README.md
```

> This structure shows the main application components. Additional configuration and dependency files may be present.

> Android platform files are generated during the GitHub Actions build process.

---

## 🔌 Backend API

The backend is built using FastAPI and deployed on Render.

**Base URL:**

https://ashiwany-personal-ai-api.onrender.com

**Interactive API documentation:**

https://ashiwany-personal-ai-api.onrender.com/docs

### API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/health` | Backend health check |
| POST | `/chat` | Authenticated Gemini AI chat |

### AI Chat Request Flow

```text
Flutter App
    |
    | Authenticated POST /chat
    |
    v
FastAPI Backend
    |
    | Validate Supabase access token
    |
    v
Check AI Usage Limits
    |
    | Request allowed
    |
    v
Google Gemini API
    |
    | AI response
    |
    v
Flutter Chat Interface
```

### Rate Limiting

The backend uses server-side rate limiting to help prevent excessive AI API usage.

When a configured usage limit is exceeded, the API can return:

```text
HTTP 429 Too Many Requests
```

Rate limiting helps control API usage but does not eliminate provider quotas or service limits.

---

## 🗄️ Database Design

The project uses Supabase PostgreSQL.

### Main Tables

| Table | Purpose |
|---|---|
| `notes` | Stores personal notes |
| `tasks` | Stores personal tasks |
| `conversations` | Stores conversation-related records |
| `ai_rate_limits` | Tracks AI request usage |

### Row Level Security

Supabase Row Level Security policies restrict access to user-owned records.

This helps ensure that:

- Users access their own notes.
- Users access their own tasks.
- Records are associated with authenticated accounts.
- One user cannot retrieve another user's private records through permitted database operations.

Multi-user privacy was tested using separate accounts.

---

## 💻 Running the Project Locally

### Prerequisites

Install the following:

- Git
- Python
- Flutter SDK
- Android SDK
- A compatible Android device or emulator

### 1. Clone the Repository

```bash
git clone https://github.com/Ashiwany25/Personal-AI-Agent.git

cd Personal-AI-Agent
```

### 2. Set Up the Backend

Create and activate a Python virtual environment:

```bash
python3 -m venv .venv

source .venv/bin/activate
```

Install the backend dependencies using the requirements file if provided by the repository:

```bash
pip install -r api/requirements.txt
```

Configure the required environment variables in your local environment.

Example variable names:

```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_PUBLISHABLE_KEY=your_publishable_key
SUPABASE_SECRET_KEY=your_server_side_secret
GEMINI_API_KEY=your_gemini_api_key
GEMINI_MODEL=your_gemini_model
```

Never commit real secret values to GitHub.

Start the API:

```bash
uvicorn api.main:app --reload
```

The development API normally runs at:

http://127.0.0.1:8000

### 3. Set Up Flutter

```bash
cd flutter_app

flutter pub get
```

Check your Flutter installation:

```bash
flutter doctor
```

Generate Android platform files if they are not already present:

```bash
flutter create \
  --platforms android \
  --project-name personal_ai_agent \
  --org com.ashiwany \
  .
```

Run the application:

```bash
flutter run
```

> The Flutter app must be configured to use an accessible backend and Supabase project. Local development may require configuration changes depending on the device or emulator.

---

## 📦 Android APK Build and Deployment

Android APKs are built using GitHub Actions.

### Debug Build

Workflow:

```text
.github/workflows/android-apk.yml
```

The debug workflow:

1. Checks out the source code.
2. Installs Flutter.
3. Generates Android platform files.
4. Installs dependencies.
5. Runs static analysis.
6. Runs Flutter tests.
7. Builds a debug APK.
8. Uploads the APK as a GitHub Actions artifact.

### Signed Release Build

Workflow:

```text
.github/workflows/android-release.yml
```

The release workflow:

1. Generates Android platform files.
2. Configures Android internet permission.
3. Runs analysis and tests.
4. Restores the signing key from GitHub Actions secrets.
5. Configures release signing.
6. Builds a release APK.
7. Uploads the signed APK as an artifact.

### Signing Secrets

The release workflow uses:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_PASSWORD
ANDROID_KEY_ALIAS
```

These values must be configured as GitHub Actions repository secrets.

**Never commit the signing keystore or passwords to the repository.**

### Application ID

```text
com.ashiwany.personal_ai_agent
```

The application ID and release signing key should remain consistent for future app updates.

---

## 🧪 Testing and Validation

The following functionality was tested during development and release preparation.

| Test | Result |
|---|---|
| Flutter static analysis | Passed during successful build |
| Flutter automated tests | Passed during successful build |
| Debug APK build | Passed |
| Signed release APK build | Passed |
| Release APK installation | Passed |
| Supabase user login | Passed |
| Gemini AI response | Passed |
| Note creation and saving | Passed |
| Task creation and completion | Passed |
| Cloud persistence after restart | Passed |
| Supabase record synchronization | Passed |
| Multi-user data isolation | Passed |
| AI request rate-limit rejection | Passed |
| Public APK download | Verified |

### Tested Platform

- Samsung Android smartphone
- Signed release APK
- Supabase cloud backend
- Render-hosted FastAPI service

> These results reflect the completed development tests. They do not guarantee compatibility with every Android device or uninterrupted cloud service availability.

---

## 🔒 Security Considerations

The project incorporates several security measures:

- Supabase-based user authentication.
- Access-token validation for protected AI requests.
- Database Row Level Security.
- Server-side Gemini API key storage.
- AI request rate limiting.
- GitHub Actions encrypted signing secrets.
- `.gitignore` rules for credentials and private files.

### Important Security Practices

- Do not embed private API keys in Flutter code.
- Do not commit `.env` files containing secrets.
- Do not publish Android signing keystores.
- Do not expose Supabase server-side secret keys.
- Rotate credentials if they are accidentally exposed.
- Review dependency and backend security before wider production use.

---

## ⚠️ Current Limitations

- An internet connection is required for cloud features.
- AI responses depend on Gemini API availability.
- Free-tier API usage quotas may limit requests.
- Render Free services may experience startup delays.
- Public distribution is through GitHub Releases, not the Play Store.
- Android compatibility has not been exhaustively tested across devices.
- AI responses may be inaccurate and should be verified for important decisions.

---

## 🚀 Future Improvements

Potential future enhancements include:

- Voice input and speech responses.
- AI-assisted task creation.
- Smart reminders and notifications.
- Search across personal notes.
- Improved conversation history management.
- Offline note and task support.
- Improved loading states and error handling.
- Automated release version management.
- Broader Android device testing.
- Google Play Store distribution.

These are planned possibilities, not features claimed to be implemented in v1.0.0.

---

## 📖 What I Learned

Building this project involved practical experience with:

- Flutter mobile application development.
- REST API integration.
- FastAPI backend development.
- AI API integration using Google Gemini.
- Supabase authentication and PostgreSQL.
- Row Level Security for multi-user applications.
- Cloud deployment on Render.
- Server-side rate limiting.
- GitHub Actions CI/CD pipelines.
- Android APK signing and release management.
- Real-device testing and debugging.

---

## 👨‍💻 Developer

**Ashiwany Kumar**

Computer Science and Engineering (AI & ML)

Haldia Institute of Technology

**GitHub:** [Ashiwany25](https://github.com/Ashiwany25)

---

## 📥 Releases

Download the latest available version:

[**Personal AI Agent — GitHub Releases**](https://github.com/Ashiwany25/Personal-AI-Agent/releases)

### Version History

| Version | Description |
|---|---|
| v1.0.0 | Initial Android release with AI Chat, authentication, Notes, Tasks, and cloud synchronization |

---

## ⭐ Support

If you find this project useful, consider giving the repository a star.

For bugs, suggestions, or feature requests, open an issue:

[**Report an Issue**](https://github.com/Ashiwany25/Personal-AI-Agent/issues)

---

**Built with Flutter, FastAPI, Supabase, and Google Gemini.**
