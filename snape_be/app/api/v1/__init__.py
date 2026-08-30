from fastapi import APIRouter

from app.api.v1 import chat_ws, health, memories, sessions, user

api_v1_router = APIRouter()

api_v1_router.include_router(health.router)
api_v1_router.include_router(user.router)
api_v1_router.include_router(sessions.router)
api_v1_router.include_router(memories.router)
api_v1_router.include_router(chat_ws.router)


