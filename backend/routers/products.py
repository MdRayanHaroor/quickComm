from fastapi import APIRouter, HTTPException
from database import supabase
from models import Product
from pydantic import BaseModel
from typing import Optional, List

router = APIRouter(prefix="/products", tags=["products"])

class ProductCreate(BaseModel):
    name: str
    description: Optional[str] = None
    size: Optional[str] = None
    price: float
    category: str = "Main Course"
    image_url: Optional[str] = None
    is_available: bool = True

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    size: Optional[str] = None
    price: Optional[float] = None
    category: Optional[str] = None
    image_url: Optional[str] = None
    is_available: Optional[bool] = None

@router.get("/", response_model=List[Product])
def get_products():
    try:
        response = supabase.from_("products").select("*").execute()
        return response.data
    except Exception as e:
        print(f"Error fetching products: {str(e)}")
        # If it's a validation error, printing response.data might help (if available)
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/", response_model=Product)
def create_product(product: ProductCreate):
    try:
        # Use model_dump() for Pydantic v2 compat, fallback to dict()
        data = product.model_dump() if hasattr(product, 'model_dump') else product.dict()
        response = supabase.table("products").insert(data).execute()
        
        # Check if response has data
        if not response.data:
            print("Supabase returned no data:", response)
            raise HTTPException(status_code=400, detail="Could not create product")
            
        return response.data[0]
    except Exception as e:
        print(f"Error creating product: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/{product_id}", response_model=Product)
def update_product(product_id: int, product: ProductUpdate):
    data = product.dict(exclude_unset=True)
    response = supabase.from_("products").update(data).eq("id", product_id).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Product not found")
    return response.data[0]

@router.delete("/{product_id}")
def delete_product(product_id: int):
    response = supabase.from_("products").delete().eq("id", product_id).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Product not found")
    return {"message": "Product deleted"}
