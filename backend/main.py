import sys
import os

# Ensure current directory is in sys.path for serverless environments (e.g., Vercel Functions)
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
if CURRENT_DIR not in sys.path:
    sys.path.insert(0, CURRENT_DIR)

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import supabase
from routers import orders, riders, products, categories, brands, variants, inventory, uploads


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
