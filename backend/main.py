import sys
import os
import logging
from http import HTTPStatus

# Ensure current directory is in sys.path for serverless environments (e.g., Vercel Functions)
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
if CURRENT_DIR not in sys.path:
    sys.path.insert(0, CURRENT_DIR)

from fastapi import FastAPI, Request, HTTPException, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from database import supabase
from routers import orders, riders, products, categories, brands, variants, inventory, uploads

logger = logging.getLogger("quickcomm")
logging.basicConfig(level=logging.INFO)

app = FastAPI(
    title="QuickComm Delivery System API",
    description="Quick-commerce backend for supermarkets and kirana stores",
    version="2.0.0",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all for now
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# Standardized Error Handlers (Task 8.5)
# ============================================================

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Consistent HTTP error response format across all endpoints."""
    try:
        status_phrase = HTTPStatus(exc.status_code).name
    except ValueError:
        status_phrase = "HTTP_ERROR"

    message = exc.detail if isinstance(exc.detail, str) else str(exc.detail)
    headers = getattr(exc, "headers", None)

    return JSONResponse(
        status_code=exc.status_code,
        headers=headers,
        content={
            "success": False,
            "detail": message,  # Preserved for backward-compatible frontend checks
            "error": {
                "code": status_phrase,
                "message": message,
                "status_code": exc.status_code,
            },
        },
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Consistent validation error response for malformed or missing payload fields."""
    formatted_errors = []
    error_messages = []

    for err in exc.errors():
        field_path = " -> ".join(str(loc) for loc in err.get("loc", []) if loc != "body")
        msg = err.get("msg", "Invalid value")
        formatted_errors.append({
            "field": field_path or "payload",
            "message": msg,
            "type": err.get("type", "value_error"),
        })
        error_messages.append(f"{field_path}: {msg}" if field_path else msg)

    summary_message = "; ".join(error_messages) if error_messages else "Request validation failed"

    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "success": False,
            "detail": summary_message,
            "error": {
                "code": "VALIDATION_ERROR",
                "message": summary_message,
                "status_code": 422,
                "details": formatted_errors,
            },
        },
    )


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    """Catch-all error handler preventing internal traceback leaks."""
    logger.error(f"Unhandled server error on {request.method} {request.url.path}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "detail": "An internal server error occurred.",
            "error": {
                "code": "INTERNAL_SERVER_ERROR",
                "message": "An internal server error occurred.",
                "status_code": 500,
            },
        },
    )


# Routers
app.include_router(orders.router)
app.include_router(riders.router)
app.include_router(products.router)
app.include_router(categories.router)
app.include_router(brands.router)
app.include_router(variants.router)
app.include_router(inventory.router)
app.include_router(uploads.router)


@app.get("/")
def read_root():
    return {"message": "QuickComm Delivery System API v2.0", "docs": "/docs"}


@app.get("/health")
def health_check():
    url = os.environ.get("SUPABASE_URL") or os.environ.get("VITE_SUPABASE_URL")
    key = (
        os.environ.get("SUPABASE_KEY")
        or os.environ.get("SUPABASE_ANON_KEY")
        or os.environ.get("VITE_SUPABASE_ANON_KEY")
        or os.environ.get("SUPABASE_SERVICE_KEY")
    )
    service_key = os.environ.get("SUPABASE_SERVICE_KEY")

    return {
        "status": "ok",
        "version": "2.0.0",
        "configured": {
            "SUPABASE_URL": bool(url),
            "SUPABASE_KEY": bool(key),
            "SUPABASE_SERVICE_KEY": bool(service_key),
        },
    }
