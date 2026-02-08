from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import supabase
from routers import orders, riders, products

app = FastAPI(title="Biryani Delivery System API")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Allow all for now
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(orders.router)
app.include_router(riders.router)
app.include_router(products.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to Biryani Delivery System API"}

@app.get("/health")
def health_check():
    return {"status": "ok"}
