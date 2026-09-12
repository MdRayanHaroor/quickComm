from fastapi import APIRouter, HTTPException, Query
from database import admin_supabase as supabase
from models import ProductVariant, ProductVariantCreate, ProductVariantUpdate, StockAdjust
from typing import List

router = APIRouter(prefix="/products", tags=["variants"])


@router.get("/{product_id}/variants", response_model=List[ProductVariant])
def get_variants(product_id: int):
    response = (
        supabase.from_("product_variants")
        .select("*")
        .eq("product_id", product_id)
        .order("sort_order")
        .execute()
    )
    return response.data


@router.post("/{product_id}/variants", response_model=ProductVariant, status_code=201)
def create_variant(product_id: int, variant: ProductVariantCreate):
    # Ensure product exists
    product = supabase.from_("products").select("id").eq("id", product_id).single().execute()
    if not product.data:
        raise HTTPException(status_code=404, detail="Product not found")

    data = variant.model_dump()
    data["product_id"] = product_id

    try:
        response = supabase.table("product_variants").insert(data).execute()
        if not response.data:
            raise HTTPException(status_code=400, detail="Could not create variant")
        return response.data[0]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/{product_id}/variants/{variant_id}", response_model=ProductVariant)
def update_variant(product_id: int, variant_id: int, variant: ProductVariantUpdate):
    data = {k: v for k, v in variant.model_dump().items() if v is not None}
    if not data:
        raise HTTPException(status_code=400, detail="No fields to update")

    response = (
        supabase.from_("product_variants")
        .update(data)
        .eq("id", variant_id)
        .eq("product_id", product_id)
        .execute()
    )
    if not response.data:
        raise HTTPException(status_code=404, detail="Variant not found")
    return response.data[0]


@router.delete("/{product_id}/variants/{variant_id}")
def delete_variant(product_id: int, variant_id: int):
    # Don't allow deleting the last variant
    remaining = (
        supabase.from_("product_variants")
        .select("id")
        .eq("product_id", product_id)
        .execute()
    )
    if len(remaining.data) <= 1:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete the last variant. A product must have at least one variant."
        )

    response = (
        supabase.from_("product_variants")
        .delete()
        .eq("id", variant_id)
        .eq("product_id", product_id)
        .execute()
    )
    if not response.data:
        raise HTTPException(status_code=404, detail="Variant not found")
    return {"message": "Variant deleted"}


@router.patch("/{product_id}/variants/{variant_id}/stock")
def update_stock(product_id: int, variant_id: int, adjustment: StockAdjust):
    """
    Adjust stock for a variant.
    positive quantity = add stock, negative = remove stock.
    """
    # Get current stock
    current = (
        supabase.from_("product_variants")
        .select("stock_quantity")
        .eq("id", variant_id)
        .eq("product_id", product_id)
        .single()
        .execute()
    )
    if not current.data:
        raise HTTPException(status_code=404, detail="Variant not found")

    new_stock = max(0, current.data["stock_quantity"] + adjustment.quantity)
    response = (
        supabase.from_("product_variants")
        .update({"stock_quantity": new_stock})
        .eq("id", variant_id)
        .execute()
    )
    return {"variant_id": variant_id, "new_stock_quantity": new_stock}
