import logging
import os
from dotenv import load_dotenv
from google import genai
from google.genai import types
from telegram import Update
from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, ContextTypes, filters
from agent.storage import Storage

load_dotenv()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def config():
    token = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
    key = os.getenv("GEMINI_API_KEY", "").strip()
    raw_ids = os.getenv("TELEGRAM_ALLOWED_USER_IDS", "").strip()
    if not token or not key or not raw_ids:
        raise RuntimeError("Set TELEGRAM_BOT_TOKEN, GEMINI_API_KEY, and TELEGRAM_ALLOWED_USER_IDS in .env")
    try:
        allowed = {int(item.strip()) for item in raw_ids.split(",") if item.strip()}
    except ValueError as exc:
        raise RuntimeError("TELEGRAM_ALLOWED_USER_IDS must be comma-separated numeric IDs") from exc
    if not allowed:
        raise RuntimeError("At least one Telegram user ID is required")
    return token, key, allowed


async def authorized(update: Update, context: ContextTypes.DEFAULT_TYPE) -> bool:
    user = update.effective_user
    if user is None or user.id not in context.application.bot_data["allowed"]:
        if update.effective_message:
            await update.effective_message.reply_text("Access denied. Ask the bot owner to add your Telegram numeric user ID.")
        return False
    return True


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await authorized(update, context):
        return
    await update.message.reply_text("Personal AI Agent ready! Send a message or use /help.")


async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await authorized(update, context):
        return
    await update.message.reply_text("Commands:\n/note text — save a note\n/notes — list notes\n/task text — add task\n/tasks — list tasks\n/done ID — complete task\n/clear — clear AI chat history\n/help — commands\nOr send any text to chat with AI.")


async def note(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await authorized(update, context):
        return
    body = " ".join(context.args).strip()
    if not body:
        await update.message.reply_text("Usage: /note your note")
        return
    context.application.bot_data["storage"].add_note(update.effective_user.id, body)
    await update.message.reply_text("Note saved.")


async def notes(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await authorized(update, context):
        return
    rows = context.application.bot_data["storage"].notes(update.effective_user.id)
    await update.message.reply_text("\n".join(f"{i}. {body}" for i, body in rows) or "No notes yet.")


async def task(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await authorized(update, context):
        return
    body = " ".join(context.args).strip()
    if not body:
        await update.message.reply_text("Usage: /task your task")
        return
    context.application.bot_data["storage"].add_task(update.effective_user.id, body)
    await update.message.reply_text("Task added.")


async def tasks(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await authorized(update, context):
        return
    rows = context.application.bot_data["storage"].tasks(update.effective_user.id)
    await update.message.reply_text("\n".join(f"{'✓' if done else '○'} {i}. {body}" for i, body, done in rows) or "No tasks yet.")


async def done(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await authorized(update, context):
        return
    try:
        task_id = int(context.args[0])
    except (IndexError, ValueError):
        await update.message.reply_text("Usage: /done TASK_ID")
        return
    ok = context.application.bot_data["storage"].complete_task(update.effective_user.id, task_id)
    await update.message.reply_text("Task completed." if ok else "Task not found.")


async def clear(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await authorized(update, context):
        return
    context.application.bot_data["storage"].clear_history(update.effective_user.id)
    await update.message.reply_text("Chat history cleared. Notes and tasks remain.")


async def chat(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await authorized(update, context):
        return
    text = update.message.text
    if len(text) > 6000:
        await update.message.reply_text("Message too long (max 6000 characters).")
        return
    storage = context.application.bot_data["storage"]
    user_id = update.effective_user.id
    messages = storage.history(user_id)
    messages.append({"role": "user", "content": text})
    try:
        response = await context.application.bot_data["client"].aio.models.generate_content(
            model=context.application.bot_data["model"],
            contents=[types.Content(role="user" if m["role"] == "user" else "model", parts=[types.Part.from_text(text=m["content"])]) for m in messages],
            config=types.GenerateContentConfig(system_instruction="You are a helpful personal assistant.", max_output_tokens=800),
        )
        answer = response.text or "No response generated."
    except Exception:
        logger.exception("AI request failed")
        await update.message.reply_text("AI service unavailable. Check API configuration and logs.")
        return
    storage.add_message(user_id, "user", text)
    storage.add_message(user_id, "assistant", answer)
    for i in range(0, len(answer), 3900):
        await update.message.reply_text(answer[i:i + 3900])


def main():
    token, key, allowed = config()
    app = ApplicationBuilder().token(token).build()
    app.bot_data.update({"allowed": allowed, "client": genai.Client(api_key=key), "model": os.getenv("GEMINI_MODEL", "gemini-3.1-flash-lite"), "storage": Storage(os.getenv("DATABASE_PATH", "./data/agent.db"))})
    for command, handler in [("start", start), ("help", help_cmd), ("note", note), ("notes", notes), ("task", task), ("tasks", tasks), ("done", done), ("clear", clear)]:
        app.add_handler(CommandHandler(command, handler))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND & filters.ChatType.PRIVATE, chat))
    logger.info("Agent starting with Telegram polling")
    app.run_polling(drop_pending_updates=True)


if __name__ == "__main__":
    main()
