
"""Personal AI Agent API with Supabase authentication."""

import os
import secrets
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Header, HTTPException
from google import genai
from google.genai import types
from pydantic import BaseModel, Field


SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_PUBLISHABLE_KEY = os.environ.get(
    "SUPABASE_PUBLISHABLE_KEY", ""
)

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
GEMINI_MODEL = os.environ.get(
    "GEMINI_MODEL", "gemini-3.1-flash-lite"
)

# Temporary compatibility for the existing Android app.
# Remove before public release.
APP_ACCESS_TOKEN = os.environ.get("APP_ACCESS_TOKEN", "")


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with httpx.AsyncClient(timeout=15.0) as client:
        app.state.http_client = client
        yield


app = FastAPI(
    title="Personal AI Agent API",
    lifespan=lifespan,
)


class Message(BaseModel):
    role: str
    content: str = Field(min_length=1, max_length=6000)


class ChatRequest(BaseModel):
    messages: list[Message] = Field(
        min_length=1, max_length=12
    )


@app.get("/health")
async def health():
    return {"status": "ok"}


async def authenticate(
    authorization: str | None,
) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Authentication required")

    access_token = authorization[7:].strip()

    if not access_token:
        raise HTTPException(401, "Authentication required")

    # Temporary support for the existing Android app.
    if APP_ACCESS_TOKEN and secrets.compare_digest(
        access_token, APP_ACCESS_TOKEN
    ):
        return "legacy-user"

    if not SUPABASE_URL or not SUPABASE_PUBLISHABLE_KEY:
        raise HTTPException(
            503, "Supabase authentication not configured"
        )

    try:
        response = await app.state.http_client.get(
            f"{SUPABASE_URL}/auth/v1/user",
            headers={
                "apikey": SUPABASE_PUBLISHABLE_KEY,
                "Authorization": f"Bearer {access_token}",
            },
        )
    except httpx.RequestError:
        raise HTTPException(
            503, "Authentication service unavailable"
        )

    if response.status_code != 200:
        if response.status_code in (401, 403):
            raise HTTPException(
                401, "Invalid or expired login session"
            )
        raise HTTPException(
            503, "Authentication verification failed"
        )

    try:
        user = response.json()
    except ValueError:
        raise HTTPException(
            503, "Invalid authentication response"
        )

    user_id = user.get("id")

    if not isinstance(user_id, str) or not user_id:
        raise HTTPException(
            401, "Invalid user identity"
        )

    return user_id


@app.post("/chat")
async def chat(
    body: ChatRequest,
    authorization: str | None = Header(default=None),
):
    user_id = await authenticate(authorization)

    if not GEMINI_API_KEY:
        raise HTTPException(
            503, "Gemini backend not configured"
        )

    if any(
        message.role not in ("user", "assistant")
        for message in body.messages
    ):
        raise HTTPException(400, "Invalid message role")

    contents = [
        types.Content(
            role="user" if message.role == "user" else "model",
            parts=[
                types.Part.from_text(text=message.content)
            ],
        )
        for message in body.messages
    ]

    try:
        async with genai.Client(
            api_key=GEMINI_API_KEY
        ).aio as client:
            response = await client.models.generate_content(
                model=GEMINI_MODEL,
                contents=contents,
                config=types.GenerateContentConfig(
                    system_instruction=(
                        "You are a helpful personal assistant."
                    ),
                    max_output_tokens=800,
                ),
            )

        return {
            "reply": response.text
            or "No response generated."
        }

    
    except Exception as exc:
        import logging

        logger = logging.getLogger("uvicorn.error")
        logger.error(
            "Gemini request failed: %s",
            type(exc).__name__,
        )

        raise HTTPException(
            status_code=503,
            detail="Gemini temporarily unavailable",
        ) from None

