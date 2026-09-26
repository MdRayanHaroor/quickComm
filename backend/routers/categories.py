from fastapi import APIRouter, HTTPException, Query, Depends
from database import admin_supabase as supabase
from models import Category, CategoryCreate, CategoryUpdate, CategoryTree
from auth import get_current_admin
from typing import List, Optional

router = APIRouter(prefix="/categories", tags=["categories"])


def build_category_tree(categories: list, parent_id=None) -> list:
    """Recursively build a nested category tree from a flat list."""
    return [
        {**cat, "children": build_category_tree(categories, cat["id"])}
        for cat in categories
        if cat.get("parent_id") == parent_id
    ]


@router.get("", response_model=List[Category])
@router.get("/", response_model=List[Category])
def get_categories(
    store_id: int = Query(1),
    active_only: bool = Query(True),
    parent_id: Optional[int] = Query(None, description="Filter by parent; use 0 for top-level only"),
):
    query = supabase.from_("categories").select("*").eq("store_id", store_id)
    if active_only:
        query = query.eq("is_active", True)
    if parent_id == 0:
        query = query.is_("parent_id", "null")
    elif parent_id is not None:
        query = query.eq("parent_id", parent_id)
    response = query.order("sort_order").execute()
    return response.data


@router.get("/tree")
def get_category_tree(store_id: int = Query(1)):
    """Returns full nested category tree."""
    response = supabase.from_("categories").select("*").eq("store_id", store_id).eq("is_active", True).order("sort_order").execute()
    tree = build_category_tree(response.data)
    return tree


@router.get("/{category_id}", response_model=Category)
def get_category(category_id: int):
    response = supabase.from_("categories").select("*").eq("id", category_id).single().execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Category not found")
    return response.data


@router.post("", response_model=Category, status_code=201)
@router.post("/", response_model=Category, status_code=201)
def create_category(category: CategoryCreate, admin: dict = Depends(get_current_admin)):
    try:
        data = category.model_dump()
        response = supabase.table("categories").insert(data).execute()
        if not response.data:
            raise HTTPException(status_code=400, detail="Could not create category")
        return response.data[0]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/{category_id}", response_model=Category)
def update_category(
    category_id: int,
    category: CategoryUpdate,
    admin: dict = Depends(get_current_admin),
):
    data = {k: v for k, v in category.model_dump().items() if v is not None}
    if not data:
        raise HTTPException(status_code=400, detail="No fields to update")
    response = supabase.from_("categories").update(data).eq("id", category_id).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Category not found")
    return response.data[0]


@router.delete("/{category_id}")
def delete_category(category_id: int, admin: dict = Depends(get_current_admin)):
    # Check if category has products
    products = supabase.from_("products").select("id").eq("category_id", category_id).limit(1).execute()
    if products.data:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete category with products. Re-assign products first.",
        )
    response = supabase.from_("categories").delete().eq("id", category_id).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Category not found")
    return {"message": "Category deleted"}
