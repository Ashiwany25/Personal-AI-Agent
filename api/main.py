
"""Personal AI Agent - Secure FastAPI Backend."""

import asyncio
import logging
import os
import time

from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Header, HTTPException
from google import genai
from google.genai import types
from pydantic import BaseModel, Field


# --------------------------------------------------
# Configuration
# --------------------------------------------------

SUPABASE_URL = os.environ.get(
    "SUPABASE_URL", ""
).rstrip("/")

SUPABASE_PUBLISHABLE_KEY = os.environ.get(
    "SUPABASE_PUBLISHABLE_KEY", ""
)

GEMINI_API_KEY = os.environ.get(
    "GEMINI_API_KEY", ""
)

GEMINI_MODEL = os.environ.get(
    "GEMINI_MODEL",
    "gemini-3.1-flash-lite",
)

GEMINI_TIMEOUT_SECONDS = 35

logger = logging.getLogger("uvicorn.error")


# --------------------------------------------------
# Application Lifecycle
# --------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):

    async with httpx.AsyncClient(
        timeout=httpx.Timeout(
            connect=5.0,
            read=10.0,
            write=5.0,
            pool=5.0,
        )
    ) as client:

        app.state.http_client = client

        logger.info("Personal AI Agent backend started")

        yield

        logger.info("Personal AI Agent backend stopped")


app = FastAPI(
    title="Personal AI Agent API",
    version="1.3.0",
    lifespan=lifespan,
)


# --------------------------------------------------
# Request Models
# --------------------------------------------------

class Message(BaseModel):
    role: str
    content: str = Field(
        min_length=1,
        max_length=6000,
    )


class ChatRequest(BaseModel):
    messages: list[Message] = Field(
        min_length=1,
        max_length=12,
    )


# --------------------------------------------------
# Health Endpoint
# --------------------------------------------------

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "service": "Personal AI Agent",
    }


# --------------------------------------------------
# Authentication
# --------------------------------------------------

async def authenticate(
    authorization: str | None,
) -> str:

    if not authorization:
        raise HTTPException(
            status_code=401,
            detail="Authentication required",
        )

    scheme, separator, access_token = (
        authorization.partition(" ")
    )

    if (
        not separator
        or scheme.lower() != "bearer"
        or not access_token.strip()
    ):
        raise HTTPException(
            status_code=401,
            detail="Invalid authorization header",
        )

    access_token = access_token.strip()

    # Only Supabase-authenticated users are accepted.
    # Legacy APP_ACCESS_TOKEN authentication is removed.

    if not SUPABASE_URL or not SUPABASE_PUBLISHABLE_KEY:
        raise HTTPException(
            status_code=503,
            detail="Supabase authentication unavailable",
        )

    try:
        response = await app.state.http_client.get(
            f"{SUPABASE_URL}/auth/v1/user",
            headers={
                "apikey": SUPABASE_PUBLISHABLE_KEY,
                "Authorization": f"Bearer {access_token}",
            },
        )

    except httpx.TimeoutException:

        logger.warning(
            "Supabase verification timed out"
        )

        raise HTTPException(
            status_code=503,
            detail="Authentication service timed out",
        ) from None

    except httpx.RequestError:

        logger.warning(
            "Supabase verification unavailable"
        )

        raise HTTPException(
            status_code=503,
            detail="Authentication service unavailable",
        ) from None

    if response.status_code in (401, 403):

        raise HTTPException(
            status_code=401,
            detail="Invalid or expired login session",
        )

    if response.status_code != 200:

        logger.warning(
            "Supabase verification returned HTTP %d",
            response.status_code,
        )

        raise HTTPException(
            status_code=503,
            detail="Authentication verification failed",
        )

    try:
        user = response.json()
        user_id = user.get("id")

    except (ValueError, AttributeError):

        raise HTTPException(
            status_code=503,
            detail="Invalid authentication response",
        ) from None

    if not isinstance(user_id, str) or not user_id:

        raise HTTPException(
            status_code=401,
            detail="Invalid user identity",
        )

    return user_id


# --------------------------------------------------
# Gemini Chat
# --------------------------------------------------

@app.post("/chat")
async def chat(
    body: ChatRequest,
    authorization: str | None = Header(default=None),
):

    request_started = time.perf_counter()

    # Verify the user's Supabase session.
    await authenticate(authorization)

    auth_seconds = (
        time.perf_counter() - request_started
    )

    logger.info(
        "AI timing: authentication=%.2fs",
        auth_seconds,
    )

    if not GEMINI_API_KEY:

        raise HTTPException(
            status_code=503,
            detail="Gemini backend not configured",
        )

    if any(
        message.role not in ("user", "assistant")
        for message in body.messages
    ):

        raise HTTPException(
            status_code=400,
            detail="Invalid message role",
        )

    contents = [
        types.Content(
            role=(
                "user"
                if message.role == "user"
                else "model"
            ),
            parts=[
                types.Part.from_text(
                    text=message.content
                )
            ],
        )
        for message in body.messages
    ]

    gemini_started = time.perf_counter()

    try:

        async def generate_reply():

            async with genai.Client(
                api_key=GEMINI_API_KEY,
            ).aio as client:

                response = (
                    await client.models.generate_content(
                        model=GEMINI_MODEL,
                        contents=contents,
                        config=types.GenerateContentConfig(
                            system_instruction=(
                                "You are a helpful personal "
                                "AI assistant. Give clear, "
                                "accurate and concise answers. "
                                "For simple questions, respond "
                                "briefly. For complex questions, "
                                "provide enough detail."
                            ),
                            max_output_tokens=400,
                            temperature=0.4,
                        ),
                    )
                )

                return response.text or (
                    "No response generated."
                )

        reply = await asyncio.wait_for(
            generate_reply(),
            timeout=GEMINI_TIMEOUT_SECONDS,
        )

        gemini_seconds = (
            time.perf_counter() - gemini_started
        )

        total_seconds = (
            time.perf_counter() - request_started
        )

        logger.info(
            "AI timing: gemini=%.2fs total=%.2fs",
            gemini_seconds,
            total_seconds,
        )

        return {
            "reply": reply,
        }

    except asyncio.TimeoutError:

        logger.warning(
            "Gemini timeout after %.2fs",
            time.perf_counter() - gemini_started,
        )

        raise HTTPException(
            status_code=504,
            detail="AI response timed out. Try again.",
        ) from None

    except Exception as exc:

        logger.error(
            "Gemini request failed: %s after %.2fs",
            type(exc).__name__,
            time.perf_counter() - gemini_started,
        )

        raise HTTPException(
            status_code=503,
            detail="Gemini temporarily unavailable",
        ) from None
