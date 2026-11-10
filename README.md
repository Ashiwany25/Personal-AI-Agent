# Personal AI Agent — Website + Android + Telegram

**Website:** https://ashiwany-personal-ai-agent.streamlit.app

This bundle includes a Streamlit website, a Flutter Android source app, a Gemini-backed API, a Telegram bot, a Colab GitHub uploader, a GitHub Actions APK build, and a Render backend blueprint. **This is a deployment-ready starter, not a production-ready public multi-user service.** Live deployments, Gemini model access, and Android builds are not verified.

## Minimal handoff

1. Open `UPLOAD_TO_GITHUB_IN_COLAB.ipynb` in Google Colab and run the single code cell. Upload the **entire ZIP**, enter your `owner/repo` and a GitHub fine-grained token authorized for that repository (Contents read/write). The script uploads project files into the repository. **It overwrites matching paths** but does not delete unrelated files. If you want to preserve existing work, use a new empty repository.
2. In Streamlit Community Cloud, choose the repository's `main` branch and entry point `streamlit_app.py`. Add these private **Secrets** (never commit them):

```toml
APP_PASSWORD = "a-long-unique-password"
GEMINI_API_KEY = "your-key-from-Google-AI-Studio"
GEMINI_MODEL = "gemini-3.1-flash-lite"
```

3. The GitHub **Actions** tab runs `Build Android APK` on changes to `flutter_app/` (or manually via **Run workflow**). Download the generated **debug APK** from its build artifacts. This is for testing and not a signed release for public app-store distribution. It requires Android SDK setup provided by GitHub-hosted runners and a successful Flutter build.
4. To enable Android AI chat, create a Render web service from `render.yaml` using **Blueprints**, enter `GEMINI_API_KEY`, and retrieve the generated `APP_ACCESS_TOKEN` from the Render environment. In the Android app Settings, enter the HTTPS API URL and access token. The token is a shared secret: **do not distribute it to strangers**. Hosting availability and fees may change.
5. Telegram is separate: run `python -m agent.main` on a continuously running Python host with `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USER_IDS`, `GEMINI_API_KEY` and optional `GEMINI_MODEL`. Streamlit cannot host a continuously polling Telegram bot.

## Limitations you should know before sharing publicly

- The web app uses a **shared password**, not individual accounts; chat, notes and tasks are session-only and may disappear.
- The Android app stores notes/tasks locally and needs a separately hosted API for chat. Web, Android and Telegram data do **not** synchronize.
- The Android API uses a **shared bearer token**, which is not safe for unrestricted public distribution. A real public service needs individual authentication, persistent database, abuse/rate limiting, privacy/security controls and a plan for Gemini API quota/cost.
- `gemini-3.1-flash-lite` is the requested model string, **not a verified available model** for your API key. API errors such as 404/503 can still occur.
- We cannot activate your GitHub, Google, Render or Streamlit accounts or enter their private credentials for you.

## Project layout

- `streamlit_app.py` — website
- `agent/` — Telegram bot
- `api/` — FastAPI backend
- `flutter_app/` — Android app source
- `.github/workflows/android-apk.yml` — Android build automation
- `render.yaml` — optional API hosting blueprint
- `UPLOAD_TO_GITHUB_IN_COLAB.ipynb` — Colab uploader

## Tests

```bash
python -m compileall -q agent api streamlit_app.py
python -m unittest discover -s tests -v
```
