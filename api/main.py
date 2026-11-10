
"""Personal AI Agent - Secure FastAPI Backend with Rate Limiting."""

import asyncio
import logging
import os
import time
import uuid

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

SUPABASE_SECRET_KEY = os.environ.get(
    "SUPABASE_SECRET_KEY", ""
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

        logger.info(
            "Personal AI Agent backend started"
        )

        yield

        logger.info(
            "Personal AI Agent backend stopped"
        )


app = FastAPI(
    title="Personal AI Agent API",
    version="1.4.0",
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
        "version": "1.4.0",
    }


# --------------------------------------------------
# Supabase Authentication
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

    if (
        not SUPABASE_URL
        or not SUPABASE_PUBLISHABLE_KEY
    ):

        raise HTTPException(
            status_code=503,
            detail="Supabase authentication unavailable",
        )

    try:

        response = await app.state.http_client.get(
            f"{SUPABASE_URL}/auth/v1/user",
            headers={
                "apikey": SUPABASE_PUBLISHABLE_KEY,
                "Authorization": (
                    f"Bearer {access_token}"
                ),
            },
        )

    except httpx.TimeoutException:

        logger.warning(
            "Supabase authentication timed out"
        )

        raise HTTPException(
            status_code=503,
            detail="Authentication service timed out",
        ) from None

    except httpx.RequestError:

        logger.warning(
            "Supabase authentication unavailable"
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
            "Authentication returned HTTP %d",
            response.status_code,
        )

        raise HTTPException(
            status_code=503,
            detail="Authentication verification failed",
        )

    try:

        user = response.json()
        user_id = user.get("id")

        if not isinstance(user_id, str):
            raise ValueError("Invalid user ID")

        user_id = str(uuid.UUID(user_id))

    except (ValueError, TypeError, AttributeError):

        raise HTTPException(
            status_code=503,
            detail="Invalid authentication response",
        ) from None

    return user_id


# --------------------------------------------------
# Persistent Supabase Rate Limiting
# --------------------------------------------------

async def consume_ai_quota(
    user_id: str,
) -> None:

    # Never allow requests to bypass rate limiting
    # if the backend secret is missing.

    if (
        not SUPABASE_URL
        or not SUPABASE_SECRET_KEY
    ):

        logger.error(
            "Rate limiting is not configured"
        )

        raise HTTPException(
            status_code=503,
            detail="AI quota service unavailable",
        )

    try:

        response = await app.state.http_client.post(
            (
                f"{SUPABASE_URL}/rest/v1/rpc/"
                "consume_ai_quota"
            ),
            headers={
                "apikey": SUPABASE_SECRET_KEY,
                "Authorization": (
                    f"Bearer {SUPABASE_SECRET_KEY}"
                ),
                "Content-Type": "application/json",
            },
            json={
                "p_user_id": user_id,
            },
        )

    except httpx.TimeoutException:

        logger.warning(
            "Rate limit verification timed out"
        )

        raise HTTPException(
            status_code=503,
            detail="AI quota verification timed out",
        ) from None

    except httpx.RequestError:

        logger.warning(
            "Rate limit database unavailable"
        )

        raise HTTPException(
            status_code=503,
            detail="AI quota service unavailable",
        ) from None

    if response.status_code != 200:

        logger.error(
            "Rate limit RPC returned HTTP %d",
            response.status_code,
        )

        raise HTTPException(
            status_code=503,
            detail="AI quota verification failed",
        )

    try:

        result = response.json()

        if not isinstance(result, dict):
            raise ValueError("Invalid quota response")

        allowed = result.get("allowed")

        if not isinstance(allowed, bool):
            raise ValueError("Missing allowed flag")

    except (ValueError, TypeError):

        logger.error(
            "Invalid rate limit RPC response"
        )

        raise HTTPException(
            status_code=503,
            detail="Invalid AI quota response",
        ) from None

    if not allowed:

        try:

            retry_after = max(
                1,
                int(result.get("retry_after", 60)),
            )

        except (ValueError, TypeError):

            retry_after = 60

        logger.info(
            "AI request rejected by rate limiter"
        )

        raise HTTPException(
            status_code=429,
            detail=(
                "AI usage limit reached. "
                "Please try again later."
            ),
            headers={
                "Retry-After": str(retry_after),
            },
        )

    logger.info(
        "AI request allowed by rate limiter"
    )


# --------------------------------------------------
# Gemini Chat
# --------------------------------------------------

@app.post("/chat")
async def chat(
    body: ChatRequest,
    authorization: str | None = Header(default=None),
):

    request_started = time.perf_counter()

    # 1. Authenticate the user.

    user_id = await authenticate(
        authorization
    )

    auth_seconds = (
        time.perf_counter() - request_started
    )

    logger.info(
        "AI timing: authentication=%.2fs",
        auth_seconds,
    )

    # 2. Validate the request.

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

    # 3. Enforce the persistent rate limit.
    # The user ID comes from Supabase verification,
    # never from the Android request body.

    await consume_ai_quota(
        user_id
    )

    quota_seconds = (
        time.perf_counter() - request_started
    )

    logger.info(
        "AI timing: auth_and_quota=%.2fs",
        quota_seconds,
    )

    # 4. Prepare Gemini conversation.

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

    # 5. Generate the AI response.

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

                return (
                    response.text
                    or "No response generated."
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
