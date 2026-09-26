from fastapi import APIRouter, HTTPException, Query, Depends
from database import admin_supabase as supabase
from models import LowStockItem, BulkStockAdjust
from auth import get_current_admin
from typing import List, Optional

router = APIRouter(prefix="/inventory", tags=["inventory"])


@router.get("/all")
def get_all_inventory(
    store_id: int = Query(1),
    search: Optional[str] = Query(None),
    admin: dict = Depends(get_current_admin),
):
    """Returns all variants with product name, category name, stock, and thresholds."""
    all_variants = (
        supabase.from_("product_variants")
        .select("id, product_id, variant_name, stock_quantity, low_stock_alert, mrp, selling_price, is_available, sku, products(id, name, store_id, category_id, categories(name))")
        .order("id")
        .execute()
    )

    items = []
    for v in (all_variants.data or []):
        p = v.get("products") or {}
        if p.get("store_id") != store_id:
            continue
        p_name = p.get("name", "Unknown")
        cat_name = (p.get("categories") or {}).get("name", "Uncategorized")
        if search:
            s = search.lower()
            if s not in p_name.lower() and s not in v["variant_name"].lower() and s not in (v.get("sku") or "").lower():
                continue
        items.append({
            "variant_id": v["id"],
            "product_id": v["product_id"],
            "product_name": p_name,
            "category_name": cat_name,
            "variant_name": v["variant_name"],
            "stock_quantity": v["stock_quantity"],
            "low_stock_alert": v["low_stock_alert"],
            "mrp": v.get("mrp", 0),
            "selling_price": v.get("selling_price", 0),
            "is_available": v.get("is_available", True),
            "sku": v.get("sku"),
        })

    return items


@router.get("/low-stock")
def get_low_stock(store_id: int = Query(1), admin: dict = Depends(get_current_admin)):
    """
    Returns all variants where stock_quantity <= low_stock_alert.
    Joins with products to include product name.
    """
    all_variants = (
        supabase.from_("product_variants")
        .select("id, product_id, variant_name, stock_quantity, low_stock_alert, products(id, name, store_id)")
        .execute()
    )

    low_stock = [
        {
            "variant_id": v["id"],
            "product_id": v["product_id"],
            "product_name": v["products"]["name"] if v.get("products") else "Unknown",
            "variant_name": v["variant_name"],
            "stock_quantity": v["stock_quantity"],
            "low_stock_alert": v["low_stock_alert"],
        }
        for v in all_variants.data
        if v["stock_quantity"] <= v["low_stock_alert"]
        and (v.get("products") and v["products"].get("store_id") == store_id)
    ]

    return low_stock


@router.get("/out-of-stock")
def get_out_of_stock(store_id: int = Query(1), admin: dict = Depends(get_current_admin)):
    """Returns all variants with 0 stock."""
    all_variants = (
        supabase.from_("product_variants")
        .select("id, product_id, variant_name, stock_quantity, low_stock_alert, products(id, name, store_id)")
        .eq("stock_quantity", 0)
        .execute()
    )

    out_of_stock = [
        {
            "variant_id": v["id"],
            "product_id": v["product_id"],
            "product_name": v["products"]["name"] if v.get("products") else "Unknown",
            "variant_name": v["variant_name"],
            "stock_quantity": 0,
            "low_stock_alert": v["low_stock_alert"],
        }
        for v in all_variants.data
        if v.get("products") and v["products"].get("store_id") == store_id
    ]

    return out_of_stock


@router.post("/adjust")
def bulk_adjust_stock(payload: BulkStockAdjust, admin: dict = Depends(get_current_admin)):
    """
    Bulk stock adjustment. Each entry:
    - positive quantity = restock
    - negative quantity = reduce stock
    """
    results = []
    errors = []

    for adj in payload.adjustments:
        try:
            current = (
                supabase.from_("product_variants")
                .select("stock_quantity, variant_name")
                .eq("id", adj.variant_id)
                .single()
                .execute()
            )
            if not current.data:
                errors.append({"variant_id": adj.variant_id, "error": "Not found"})
                continue

            new_stock = max(0, current.data["stock_quantity"] + adj.quantity)
            supabase.from_("product_variants").update({"stock_quantity": new_stock}).eq("id", adj.variant_id).execute()

            results.append({
                "variant_id": adj.variant_id,
                "variant_name": current.data["variant_name"],
                "previous_stock": current.data["stock_quantity"],
                "adjustment": adj.quantity,
                "new_stock": new_stock,
            })
        except Exception as e:
            errors.append({"variant_id": adj.variant_id, "error": str(e)})

    return {"updated": results, "errors": errors}


@router.get("/summary")
def get_inventory_summary(store_id: int = Query(1), admin: dict = Depends(get_current_admin)):
    """High-level inventory health stats."""
    all_variants = (
        supabase.from_("product_variants")
        .select("stock_quantity, low_stock_alert, is_available, products(store_id)")
        .execute()
    )

    variants = [
        v for v in all_variants.data
        if v.get("products") and v["products"].get("store_id") == store_id
    ]

    total = len(variants)
    out_of_stock = sum(1 for v in variants if v["stock_quantity"] == 0)
    low_stock = sum(1 for v in variants if 0 < v["stock_quantity"] <= v["low_stock_alert"])
    healthy = total - out_of_stock - low_stock

    return {
        "total_variants": total,
        "out_of_stock": out_of_stock,
        "low_stock": low_stock,
        "healthy_stock": healthy,
    }
