"""Personal AI Agent website. Session-only chat, notes and tasks."""
import hmac
import os
import time
import logging
import streamlit as st
from google import genai
from google.genai import types
from google.genai.errors import ServerError

st.set_page_config(page_title="Personal AI Agent", page_icon="🤖", layout="centered")
log = logging.getLogger(__name__)

def setting(key, default=""):
    try:
        value = st.secrets.get(key)
        if value is not None:
            return str(value)
    except (FileNotFoundError, KeyError):
        pass
    return os.getenv(key, default)

password = setting("APP_PASSWORD")
if not password:
    st.error("APP_PASSWORD is missing. Configure it in Streamlit Secrets.")
    st.stop()
if not st.session_state.get("authenticated", False):
    st.title("🔐 Personal AI Agent")
    with st.form("login"):
        attempt = st.text_input("Password", type="password")
        submit = st.form_submit_button("Unlock")
    if submit:
        if hmac.compare_digest(attempt, password):
            st.session_state.authenticated = True
            st.rerun()
        st.error("Incorrect password")
    st.stop()

for key in ("messages", "notes", "tasks"):
    if key not in st.session_state:
        st.session_state[key] = []

st.title("🤖 Personal AI Agent")
st.caption("AI chat · Notes · Tasks")
with st.sidebar:
    tab = st.radio("Workspace", ["AI Chat", "Notes", "Tasks"])
    st.caption("Web notes, tasks, and chat are session-only; they are not shared with the Telegram bot or Flutter app.")
    if st.button("Log out"):
        st.session_state.authenticated = False
        st.rerun()
    if st.button("Clear chat"):
        st.session_state.messages = []
        st.rerun()

def reply(messages):
    key = setting("GEMINI_API_KEY")
    if not key:
        raise ValueError("GEMINI_API_KEY missing from Streamlit Secrets")
    client = genai.Client(api_key=key)
    contents = [types.Content(role="user" if m["role"] == "user" else "model", parts=[types.Part.from_text(text=m["content"])]) for m in messages[-12:]]
    for attempt in range(3):
        try:
            result = client.models.generate_content(
                model=setting("GEMINI_MODEL", "gemini-3.1-flash-lite"),
                contents=contents,
                config=types.GenerateContentConfig(system_instruction="You are a helpful personal assistant. Never claim to perform actions you did not perform.", max_output_tokens=800),
            )
            return result.text or "No answer returned."
        except ServerError as exc:
            if getattr(exc, "code", None) != 503 or attempt == 2:
                raise
            time.sleep(2 ** attempt)
    raise RuntimeError("Gemini did not respond")

if tab == "AI Chat":
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.write(message["content"])
    prompt = st.chat_input("Ask anything...")
    if prompt:
        if len(prompt) > 6000:
            st.error("Message too long (max 6000 characters)")
        else:
            st.session_state.messages.append({"role": "user", "content": prompt})
            with st.chat_message("user"):
                st.write(prompt)
            with st.chat_message("assistant"):
                with st.spinner("Thinking..."):
                    try:
                        answer = reply(st.session_state.messages)
                        st.write(answer)
                        st.session_state.messages.append({"role": "assistant", "content": answer})
                    except Exception as exc:
                        log.warning("Gemini request failed: %s", type(exc).__name__)
                        st.error("Gemini is unavailable or this model is not enabled for your key. Check API quotas and app logs.")
elif tab == "Notes":
    with st.form("note_form", clear_on_submit=True):
        note = st.text_area("New note")
        if st.form_submit_button("Save note") and note.strip():
            st.session_state.notes.append(note.strip())
            st.rerun()
    for i, note in enumerate(st.session_state.notes):
        a, b = st.columns([5, 1])
        a.write(note)
        if b.button("Delete", key=f"note_{i}"):
            st.session_state.notes.pop(i)
            st.rerun()
else:
    with st.form("task_form", clear_on_submit=True):
        task = st.text_input("New task")
        if st.form_submit_button("Add task") and task.strip():
            st.session_state.tasks.append({"title": task.strip(), "done": False})
            st.rerun()
    for i, task in enumerate(st.session_state.tasks):
        a, b = st.columns([5, 1])
        task["done"] = a.checkbox(task["title"], value=task["done"], key=f"task_{i}")
        if b.button("Delete", key=f"del_task_{i}"):
            st.session_state.tasks.pop(i)
            st.rerun()
