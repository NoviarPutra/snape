from fastapi import APIRouter

from app.api.v1 import health, sessions, user

api_v1_router = APIRouter()

api_v1_router.include_router(health.router)
api_v1_router.include_router(user.router)
api_v1_router.include_router(sessions.router)
