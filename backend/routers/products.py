import re
from fastapi import APIRouter, HTTPException, Query, Depends
from database import admin_supabase as supabase
from models import Product, ProductCreate, ProductUpdate, ProductListItem, ProductVariant
from auth import get_current_admin
from typing import List, Optional

router = APIRouter(prefix="/products", tags=["products"])


def _enrich_products_with_variant_summary(products: list) -> list:
    """Add min_price, max_price, variant_count, total_stock to each product dict."""
    if not products:
        return products

    product_ids = [p["id"] for p in products]
    # Fetch all variants for these products in one query
    variants_resp = (
        supabase.from_("product_variants")
        .select("product_id, selling_price, mrp, stock_quantity, is_available")
        .in_("product_id", product_ids)
        .execute()
    )
    variants = variants_resp.data or []

    # Build lookup map
    from collections import defaultdict
    variant_map = defaultdict(list)
    for v in variants:
        variant_map[v["product_id"]].append(v)

    enriched = []
    for p in products:
        pvs = variant_map.get(p["id"], [])
        prices = [v["selling_price"] for v in pvs if v.get("is_available")]
        total_stock = sum(v.get("stock_quantity", 0) for v in pvs)

        enriched.append({
            **p,
            "min_price": min(prices) if prices else None,
            "max_price": max(prices) if prices else None,
            "variant_count": len(pvs),
            "total_stock": total_stock,
        })

    return enriched


@router.get("", response_model=List[ProductListItem])
@router.get("/", response_model=List[ProductListItem])
def get_products(
    store_id: int = Query(1),
    category_id: Optional[int] = Query(None),
    brand_id: Optional[int] = Query(None),
    search: Optional[str] = Query(None, description="Search by product name"),
    is_available: Optional[bool] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    sort: str = Query("newest", description="newest | price_asc | price_desc | name_asc"),
):
    try:
        offset = (page - 1) * limit

        # Base query builder
        query = supabase.from_("products").select("*").eq("store_id", store_id)
        if category_id is not None:
            query = query.eq("category_id", category_id)
        if brand_id is not None:
            query = query.eq("brand_id", brand_id)
        if is_available is not None:
            query = query.eq("is_available", is_available)

        # Apply sorting
        if sort == "name_asc":
            query = query.order("name")
        else:
            query = query.order("created_at", desc=True)

        # Apply pagination range
        query = query.range(offset, offset + limit - 1)

        # Handle Search (Task 8.7: tsvector Full-Text Search with safe fallback)
        if search and search.strip():
            clean_search = search.strip()
            products = []

            # 1. First attempt: Prefix full-text search with sanitized alphanumeric tokens
            cleaned_terms = [re.sub(r'[^\w]', '', w) for w in clean_search.split()]
            cleaned_terms = [t for t in cleaned_terms if t]
            if cleaned_terms:
                try:
                    prefix_query = " & ".join(f"{t}:*" for t in cleaned_terms)
                    ft_q = supabase.from_("products").select("*").eq("store_id", store_id)
                    if category_id is not None:
                        ft_q = ft_q.eq("category_id", category_id)
                    if brand_id is not None:
                        ft_q = ft_q.eq("brand_id", brand_id)
                    if is_available is not None:
                        ft_q = ft_q.eq("is_available", is_available)
                    if sort == "name_asc":
                        ft_q = ft_q.order("name")
                    else:
                        ft_q = ft_q.order("created_at", desc=True)
                    ft_q = ft_q.range(offset, offset + limit - 1)
                    ft_resp = ft_q.text_search("search_vector", prefix_query).execute()
                    products = ft_resp.data or []
                except Exception as err:
                    print(f"Full-text prefix search fallback: {err}")

            # 2. Second attempt: web_search mode for natural language / phrases
            if not products:
                try:
                    ws_q = supabase.from_("products").select("*").eq("store_id", store_id)
                    if category_id is not None:
                        ws_q = ws_q.eq("category_id", category_id)
                    if brand_id is not None:
                        ws_q = ws_q.eq("brand_id", brand_id)
                    if is_available is not None:
                        ws_q = ws_q.eq("is_available", is_available)
                    if sort == "name_asc":
                        ws_q = ws_q.order("name")
                    else:
                        ws_q = ws_q.order("created_at", desc=True)
                    ws_q = ws_q.range(offset, offset + limit - 1)
                    ws_resp = ws_q.text_search("search_vector", clean_search, options={"type": "web_search"}).execute()
                    products = ws_resp.data or []
                except Exception as err:
                    print(f"Full-text web_search fallback: {err}")

            # 3. Third attempt: Safe ilike wildcard search
            if not products:
                try:
                    fallback_q = supabase.from_("products").select("*").eq("store_id", store_id)
                    if category_id is not None:
                        fallback_q = fallback_q.eq("category_id", category_id)
                    if brand_id is not None:
                        fallback_q = fallback_q.eq("brand_id", brand_id)
                    if is_available is not None:
                        fallback_q = fallback_q.eq("is_available", is_available)
                    if sort == "name_asc":
                        fallback_q = fallback_q.order("name")
                    else:
                        fallback_q = fallback_q.order("created_at", desc=True)
                    fallback_q = fallback_q.range(offset, offset + limit - 1)
                    safe_ilike = re.sub(r'[*%]', '', clean_search)
                    fallback_q = fallback_q.ilike("name", f"*{safe_ilike}*")
                    res = fallback_q.execute()
                    products = res.data or []
                except Exception as err:
                    print(f"Ilike fallback error: {err}")
                    products = []
        else:
            response = query.execute()
            products = response.data or []

        enriched = _enrich_products_with_variant_summary(products)

        # Apply price sorting post-enrichment
        if sort == "price_asc":
            enriched.sort(key=lambda p: p.get("min_price") or float("inf"))
        elif sort == "price_desc":
            enriched.sort(key=lambda p: p.get("max_price") or 0, reverse=True)

        return enriched

    except Exception as e:
        print(f"Error fetching products: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{product_id}", response_model=Product)
def get_product(product_id: int):
    """Single product with full nested variants, brand, and category."""
    try:
        response = (
            supabase.from_("products")
            .select("*, brands(*), categories(*)")
            .eq("id", product_id)
            .single()
            .execute()
        )
        if not response.data:
            raise HTTPException(status_code=404, detail="Product not found")

        product = response.data

        # Fetch variants separately (cleaner than nested select)
        variants_resp = (
            supabase.from_("product_variants")
            .select("*")
            .eq("product_id", product_id)
            .order("sort_order")
            .execute()
        )
        product["variants"] = variants_resp.data or []
        product["brand"] = product.pop("brands", None)
        product["category"] = product.pop("categories", None)

        return product

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("", response_model=Product, status_code=201)
@router.post("/", response_model=Product, status_code=201)
def create_product(product: ProductCreate, admin: dict = Depends(get_current_admin)):
    try:
        data = product.model_dump()

        # Auto-generate slug from name if not provided
        if not data.get("slug"):
            import re
            data["slug"] = re.sub(r"[^a-z0-9]+", "-", data["name"].lower()).strip("-")

        # Ensure legacy NOT NULL price column is populated
        if data.get("price") is None:
            data["price"] = 0.0

        response = supabase.table("products").insert(data).execute()
        if not response.data:
            raise HTTPException(status_code=400, detail="Could not create product")

        created = response.data[0]
        if created.get("tags") is None:
            created["tags"] = []
        if created.get("images") is None:
            created["images"] = []
        created["variants"] = []
        return created

    except HTTPException:
        raise
    except Exception as e:
        print(f"Error creating product: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/{product_id}", response_model=Product)
def update_product(
    product_id: int,
    product: ProductUpdate,
    admin: dict = Depends(get_current_admin),
):
    data = {k: v for k, v in product.model_dump().items() if v is not None}
    if not data:
        raise HTTPException(status_code=400, detail="No fields to update")

    try:
        response = supabase.from_("products").update(data).eq("id", product_id).execute()
        if not response.data:
            raise HTTPException(status_code=404, detail="Product not found")

        updated = response.data[0]
        if updated.get("tags") is None:
            updated["tags"] = []
        if updated.get("images") is None:
            updated["images"] = []

        # Resolve category if category_id exists
        if updated.get("category_id"):
            cat_resp = supabase.from_("categories").select("*").eq("id", updated["category_id"]).execute()
            if cat_resp.data:
                updated["category"] = cat_resp.data[0]
        elif isinstance(updated.get("category"), str):
            # Keep legacy text or None
            pass

        # Resolve brand if brand_id exists
        if updated.get("brand_id"):
            brand_resp = supabase.from_("brands").select("*").eq("id", updated["brand_id"]).execute()
            if brand_resp.data:
                updated["brand"] = brand_resp.data[0]

        variants_resp = (
            supabase.from_("product_variants")
            .select("*")
            .eq("product_id", product_id)
            .order("sort_order")
            .execute()
        )
        updated["variants"] = variants_resp.data or []
        return updated

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/{product_id}")
def delete_product(product_id: int, admin: dict = Depends(get_current_admin)):
    # Cascade to variants is handled by DB ON DELETE CASCADE
    response = supabase.from_("products").delete().eq("id", product_id).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Product not found")
    return {"message": "Product deleted"}


@router.get("/search/autocomplete")
def autocomplete_products(
    q: str = Query(..., min_length=2),
    store_id: int = Query(1),
    limit: int = Query(8, le=20),
):
    """Quick autocomplete for search bar — returns just id + name."""
    response = (
        supabase.from_("products")
        .select("id, name, images, image_url")
        .eq("store_id", store_id)
        .eq("is_available", True)
        .ilike("name", f"*{q}*")
        .limit(limit)
        .execute()
    )
    return response.data or []


from pydantic import BaseModel
import re
from uuid import uuid4

class ProductBulkItem(BaseModel):
    name: str
    category: Optional[str] = None
    brand: Optional[str] = None
    description: Optional[str] = ""
    unit: Optional[str] = "1 unit"
    mrp: Optional[float] = 0.0
    selling_price: Optional[float] = 0.0
    stock: Optional[int] = 0
    barcode: Optional[str] = None
    image_url: Optional[str] = None

class BulkImportPayload(BaseModel):
    products: List[ProductBulkItem]
    store_id: Optional[int] = 1


@router.post("/bulk-import")
def bulk_import_products(payload: BulkImportPayload, admin: dict = Depends(get_current_admin)):
    """Bulk import products and their variants from Excel/CSV parsed data."""
    if not payload.products:
        raise HTTPException(status_code=400, detail="No products provided for import")

    store_id = payload.store_id or 1

    # Pre-fetch existing categories and brands for quick lookup
    cat_resp = supabase.table("categories").select("id, name").execute()
    existing_cats = {c["name"].strip().lower(): c["id"] for c in (cat_resp.data or []) if c.get("name")}

    brand_resp = supabase.table("brands").select("id, name").execute()
    existing_brands = {b["name"].strip().lower(): b["id"] for b in (brand_resp.data or []) if b.get("name")}

    imported_count = 0
    errors = []

    for idx, item in enumerate(payload.products):
        name = (item.name or "").strip()
        if not name:
            errors.append({"row": idx + 1, "error": "Product name is required"})
            continue

        try:
            # 1. Resolve or create category
            cat_id = None
            cat_name = (item.category or "").strip()
            if cat_name:
                key = cat_name.lower()
                if key in existing_cats:
                    cat_id = existing_cats[key]
                else:
                    slug = re.sub(r"[^a-z0-9]+", "-", key).strip("-") + "-" + uuid4().hex[:4]
                    new_cat = supabase.table("categories").insert({
                        "name": cat_name,
                        "slug": slug,
                        "is_active": True
                    }).execute()
                    if new_cat.data:
                        cat_id = new_cat.data[0]["id"]
                        existing_cats[key] = cat_id

            # 2. Resolve or create brand
            brand_id = None
            brand_name = (item.brand or "").strip()
            if brand_name:
                b_key = brand_name.lower()
                if b_key in existing_brands:
                    brand_id = existing_brands[b_key]
                else:
                    b_slug = re.sub(r"[^a-z0-9]+", "-", b_key).strip("-") + "-" + uuid4().hex[:4]
                    new_brand = supabase.table("brands").insert({
                        "name": brand_name,
                        "slug": b_slug,
                        "is_active": True
                    }).execute()
                    if new_brand.data:
                        brand_id = new_brand.data[0]["id"]
                        existing_brands[b_key] = brand_id

            # 3. Create Product
            mrp = float(item.mrp or 0.0)
            selling_price = float(item.selling_price or (mrp if mrp > 0 else 0.0))
            if mrp == 0.0 and selling_price > 0:
                mrp = selling_price

            slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") + "-" + uuid4().hex[:6]
            image_url = (item.image_url or "").strip()

            prod_data = {
                "name": name,
                "slug": slug,
                "description": (item.description or "").strip(),
                "category_id": cat_id,
                "brand_id": brand_id,
                "store_id": store_id,
                "price": selling_price,
                "image_url": image_url or None,
                "images": [image_url] if image_url else [],
                "is_available": True
            }

            prod_res = supabase.table("products").insert(prod_data).execute()
            if not prod_res.data:
                errors.append({"row": idx + 1, "product": name, "error": "Failed to insert product"})
                continue

            product_id = prod_res.data[0]["id"]

            # 4. Create default Variant
            stock_qty = int(item.stock or 0)
            barcode = (item.barcode or "").strip() if item.barcode else None

            var_data = {
                "product_id": product_id,
                "unit": (item.unit or "1 unit").strip(),
                "mrp": mrp,
                "selling_price": selling_price,
                "stock_quantity": stock_qty,
                "barcode": barcode,
                "is_available": True,
                "is_default": True,
                "sort_order": 0
            }

            supabase.table("product_variants").insert(var_data).execute()
            imported_count += 1

        except Exception as e:
            errors.append({"row": idx + 1, "product": name, "error": str(e)})

    return {
        "success": True,
        "imported_count": imported_count,
        "failed_count": len(errors),
        "errors": errors
    }
