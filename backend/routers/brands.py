from fastapi import APIRouter, HTTPException, Query, Depends
from database import admin_supabase as supabase
from models import Brand, BrandCreate, BrandUpdate
from auth import get_current_admin
from typing import List

router = APIRouter(prefix="/brands", tags=["brands"])


@router.get("", response_model=List[Brand])
@router.get("/", response_model=List[Brand])
def get_brands(store_id: int = Query(1), active_only: bool = Query(False)):
    query = supabase.from_("brands").select("*").eq("store_id", store_id)
    if active_only:
        query = query.eq("is_active", True)
    response = query.order("name").execute()
    return response.data


@router.get("/{brand_id}", response_model=Brand)
def get_brand(brand_id: int):
    response = supabase.from_("brands").select("*").eq("id", brand_id).single().execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Brand not found")
    return response.data


@router.post("", response_model=Brand, status_code=201)
@router.post("/", response_model=Brand, status_code=201)
def create_brand(brand: BrandCreate, admin: dict = Depends(get_current_admin)):
    try:
        data = brand.model_dump()
        response = supabase.table("brands").insert(data).execute()
        if not response.data:
            raise HTTPException(status_code=400, detail="Could not create brand")
        return response.data[0]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/{brand_id}", response_model=Brand)
def update_brand(
    brand_id: int,
    brand: BrandUpdate,
    admin: dict = Depends(get_current_admin),
):
    data = {k: v for k, v in brand.model_dump().items() if v is not None}
    if not data:
        raise HTTPException(status_code=400, detail="No fields to update")
    response = supabase.from_("brands").update(data).eq("id", brand_id).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Brand not found")
    return response.data[0]


@router.delete("/{brand_id}")
def delete_brand(brand_id: int, admin: dict = Depends(get_current_admin)):
    response = supabase.from_("brands").delete().eq("id", brand_id).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Brand not found")
    return {"message": "Brand deleted"}
