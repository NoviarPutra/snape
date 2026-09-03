from fastapi import APIRouter

from app.api.v1 import (
    chat_ws,
    health,
    materials,
    memories,
    sessions,
    spaces,
    trending,
    tts,
    user,
)

api_v1_router = APIRouter()

api_v1_router.include_router(health.router)
api_v1_router.include_router(user.router)
api_v1_router.include_router(sessions.router)
api_v1_router.include_router(memories.router)
api_v1_router.include_router(chat_ws.router)
api_v1_router.include_router(tts.router)
api_v1_router.include_router(spaces.router)
api_v1_router.include_router(materials.router)
api_v1_router.include_router(trending.router)
