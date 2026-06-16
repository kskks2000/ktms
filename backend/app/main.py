from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.carrier import router as carrier_router
from app.api.health import router as health_router
from app.api.masters import router as masters_router
from app.api.orders import router as orders_router
from app.api.tracking import router as tracking_router
from app.core.config import settings


def create_app() -> FastAPI:
    app = FastAPI(
        title="KTMS API",
        version="0.1.0",
        docs_url="/docs",
        redoc_url="/redoc",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(health_router, prefix="/api")
    app.include_router(masters_router, prefix="/api")
    app.include_router(orders_router, prefix="/api")
    app.include_router(tracking_router, prefix="/api")
    app.include_router(carrier_router, prefix="/api")
    return app


app = create_app()
