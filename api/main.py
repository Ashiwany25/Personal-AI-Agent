"""Optional Gemini backend; deploy with HTTPS. Keep GEMINI_API_KEY server-side."""
import os
import secrets
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field
from google import genai
from google.genai import types

app = FastAPI(title='Personal AI Agent API')

class Message(BaseModel):
    role: str
    content: str = Field(min_length=1, max_length=6000)

class ChatRequest(BaseModel):
    messages: list[Message] = Field(min_length=1, max_length=12)

@app.get('/health')
def health():
    return {'status': 'ok'}

@app.post('/chat')
async def chat(body: ChatRequest, authorization: str | None = Header(default=None)):
    token = os.environ.get('APP_ACCESS_TOKEN', '')
    key = os.environ.get('GEMINI_API_KEY', '')
    if not token or not key:
        raise HTTPException(503, 'Backend not configured')
    if not authorization or not authorization.startswith('Bearer ') or not secrets.compare_digest(authorization[7:], token):
        raise HTTPException(401, 'Unauthorized')
    if any(m.role not in ('user', 'assistant') for m in body.messages):
        raise HTTPException(400, 'Invalid message role')
    contents = [types.Content(role='user' if m.role == 'user' else 'model', parts=[types.Part.from_text(text=m.content)]) for m in body.messages]
    try:
        async with genai.Client(api_key=key).aio as client:
            response = await client.models.generate_content(
                model=os.environ.get('GEMINI_MODEL', 'gemini-3.1-flash-lite'), contents=contents,
                config=types.GenerateContentConfig(system_instruction='You are a helpful personal assistant.', max_output_tokens=800),
            )
        return {'reply': response.text or 'No response generated.'}
    except Exception:
        raise HTTPException(503, 'Gemini temporarily unavailable')
