# Personal AI Agent — Flutter Android Source

This ZIP contains the **Flutter source code**, not a compiled APK. Includes AI chat, local notes and tasks, and an optional FastAPI backend using `gemini-3.1-flash-lite`. It does not change the existing GitHub, Streamlit, or Telegram projects.

## Build on Windows

1. Install Git, Flutter SDK, Android Studio (with Android SDK), and VS Code with Flutter/Dart extensions.
2. Open PowerShell, run `flutter doctor`, and complete the Android setup.
3. Extract this ZIP and open the `personal_ai_agent_flutter` folder in VS Code.
4. Run `flutter create --platforms=android --project-name personal_ai_agent .` to generate the platform-specific Android/Gradle files (not included in this source bundle).
5. Run `flutter pub get` and `flutter run` with a connected Android phone/emulator.
6. To build an APK: `flutter build apk --release`. The APK will be under `build/app/outputs/flutter-apk/`.

## Enable Gemini chat

The Streamlit website is not a REST API. The Flutter app needs a separate backend. The included `backend/main.py` is a starter FastAPI endpoint. Run it locally for development or deploy behind HTTPS. Set the following **server-side environment variables**, never in Flutter source:

- `GEMINI_API_KEY`: your private Gemini key
- `GEMINI_MODEL`: `gemini-3.1-flash-lite`
- `APP_ACCESS_TOKEN`: a long, random shared secret

Install `backend/requirements.txt` and run `uvicorn main:app --host 127.0.0.1 --port 8000` from the `backend` directory. For use on a real phone, deploy the backend behind HTTPS and enter its base URL and the app access token in the Flutter app's Settings. The access token is kept in memory, not saved to disk. Do **not** enter the Gemini API key in the mobile app.

The backend is a starter, not a production multi-user authentication service. Add per-user authentication, rate limits, monitoring, and abuse prevention before distributing broadly. A Gemini 503 may still occur during overload.

## Data and testing

Notes, tasks, and chat are saved locally using SharedPreferences (not encrypted). They are not synchronized with Streamlit or Telegram. Avoid sensitive content. Flutter was not available in the file-generation environment, so run `flutter analyze`, `flutter test`, and device testing on Windows before sharing an APK.
