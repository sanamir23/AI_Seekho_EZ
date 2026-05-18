from contextlib import asynccontextmanager
import logging
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app.config import get_settings
from app.routers import auth, bookings, service_requests
from app.scheduler.runtime import start_scheduler, stop_scheduler

# ── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s │ %(name)-12s │ %(message)s",
    datefmt="%H:%M:%S",
)
# Quiet noisy libraries, keep our agent logs visible.
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)
logging.getLogger("urllib3").setLevel(logging.WARNING)
logging.getLogger("hpack").setLevel(logging.WARNING)
logging.getLogger("langgraph").setLevel(logging.WARNING)

# Absolute path to the frontend directory (sibling of backend/).
FRONTEND_DIR = Path(__file__).parent.parent.parent / "frontend"


@asynccontextmanager
async def lifespan(_app: FastAPI):
    start_scheduler()
    yield
    stop_scheduler()


def create_app() -> FastAPI:
    s = get_settings()
    app = FastAPI(
        title="Agentic Service Matching",
        version="0.1.0",
        lifespan=lifespan,
        docs_url="/api/docs",
        redoc_url="/api/redoc",
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ── API routers ──────────────────────────────────────────────────────────
    app.include_router(auth.router,             prefix="/api")
    app.include_router(service_requests.router, prefix="/api")
    app.include_router(bookings.router,         prefix="/api")

    @app.get("/api/health")
    def health():
        return {"ok": True}

    # ── Static assets & Frontend routes (only if frontend/ dir exists) ─────────
    if (FRONTEND_DIR / "static").exists():
        app.mount("/static", StaticFiles(directory=FRONTEND_DIR / "static"), name="static")

        # ── Frontend HTML routes (served last so API routes always win) ──────────
        def _page(name: str) -> FileResponse:
            return FileResponse(FRONTEND_DIR / name)

        @app.get("/")
        def page_home():           return _page("index.html")

        @app.get("/login")
        def page_login():          return _page("login.html")

        @app.get("/signup")
        def page_signup():         return _page("signup.html")

        @app.get("/bookings")
        def page_bookings():       return _page("bookings.html")

        @app.get("/bookings/{bid}")
        def page_booking(bid: str): return _page("booking.html")
    else:
        logging.getLogger("main").warning(
            "Frontend directory not found at %s — static file serving disabled.",
            FRONTEND_DIR,
        )

    return app


app = create_app()
