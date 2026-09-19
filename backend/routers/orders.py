from fastapi import APIRouter, HTTPException, Query
from database import admin_supabase as supabase
from models import Order, OrderCreate, OrderUpdate, OrderAssign
from typing import Optional

router = APIRouter(prefix="/orders", tags=["orders"])


@router.get("")
@router.get("/")
def get_orders(
    status: Optional[str] = Query(None),
    limit: int = Query(50, le=200),
    page: int = Query(1, ge=1),
):
    try:
        query = supabase.from_("orders").select("*")
        if status:
            query = query.eq("status", status)
        offset = (page - 1) * limit
        response = query.order("created_at", desc=True).range(offset, offset + limit - 1).execute()
        return response.data
    except Exception as e:
        print(f"Error fetching orders: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{order_id}")
def get_order(order_id: int):
    """Single order with its items (including variant snapshots)."""
    try:
        order_resp = supabase.from_("orders").select("*").eq("id", order_id).single().execute()
        if not order_resp.data:
            raise HTTPException(status_code=404, detail="Order not found")

        items_resp = (
            supabase.from_("order_items")
            .select("*, product_variants(variant_name, sku, unit_type)")
            .eq("order_id", order_id)
            .execute()
        )

        order = order_resp.data
        order["items"] = items_resp.data or []
        return order

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


import math

def haversine_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate the great circle distance between two points on the earth in kilometers."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


@router.post("", status_code=201)
@router.post("/", status_code=201)
def create_order(order: OrderCreate, user_id: str = Query(..., description="Supabase user UUID")):
    """
    Create an order. Validates store status, delivery radius, min order amount,
    captures snapshots, and decrements variant inventory stock.
    """
    try:
        # ---- 0. Fetch store settings and validate operational status ----
        settings_resp = supabase.from_("store_settings").select("*").eq("id", 1).maybe_single().execute()
        settings = settings_resp.data if settings_resp else None

        if settings:
            # A. Check if store is open
            if settings.get("is_open") is False:
                reason = settings.get("closed_reason") or "Closed for Now"
                raise HTTPException(
                    status_code=400,
                    detail=f"Store is currently unavailable ({reason}). Orders cannot be placed at this time."
                )

            # B. Check delivery radius (if enabled)
            raw_radius = settings.get("delivery_radius_km")
            delivery_radius_km = float(raw_radius) if raw_radius is not None else 0.0

            if delivery_radius_km > 0:
                store_lat = settings.get("lat") or settings.get("latitude")
                store_lng = settings.get("lng") or settings.get("longitude")
                if (store_lat is None or store_lng is None) and settings.get("location"):
                    loc_str = str(settings.get("location"))
                    import re
                    m = re.search(r"POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)", loc_str)
                    if m:
                        store_lng = float(m.group(1))
                        store_lat = float(m.group(2))

                cust_lat = order.delivery_lat
                cust_lng = order.delivery_lng

                # If user didn't share GPS coords but entered text address, attempt auto-geocoding
                if (cust_lat is None or cust_lng is None) and order.delivery_address:
                    try:
                        import urllib.request
                        import json
                        import urllib.parse
                        url = f"https://nominatim.openstreetmap.org/search?q={urllib.parse.quote(order.delivery_address)}&format=json&limit=1&countrycodes=in"
                        req = urllib.request.Request(url, headers={"User-Agent": "QuickComm-Backend/1.0"})
                        with urllib.request.urlopen(req, timeout=2.5) as resp:
                            geo_data = json.loads(resp.read().decode())
                            if geo_data and len(geo_data) > 0:
                                cust_lat = float(geo_data[0]["lat"])
                                cust_lng = float(geo_data[0]["lon"])
                    except Exception as geo_err:
                        print(f"Address geocoding fallback failed: {geo_err}")

                # Enforce radius check if coordinates are resolved
                if store_lat is not None and store_lng is not None and cust_lat is not None and cust_lng is not None:
                    dist_km = haversine_distance_km(store_lat, store_lng, cust_lat, cust_lng)
                    if dist_km > delivery_radius_km:
                        raise HTTPException(
                            status_code=400,
                            detail=f"Delivery address is {dist_km:.1f} km away, which exceeds our maximum delivery radius of {delivery_radius_km:.1f} km."
                        )

        # ---- 1. Validate variants & compute totals ----
        order_items_data = []
        computed_total = 0.0

        for item in order.items:
            variant_resp = (
                supabase.from_("product_variants")
                .select("*, products(name)")
                .eq("id", item.variant_id)
                .single()
                .execute()
            )
            if not variant_resp.data:
                raise HTTPException(status_code=404, detail=f"Variant {item.variant_id} not found")

            variant = variant_resp.data
            if not variant.get("is_available"):
                raise HTTPException(status_code=400, detail=f"Variant '{variant['variant_name']}' is not available")
            if variant.get("stock_quantity", 0) < item.quantity:
                raise HTTPException(
                    status_code=400,
                    detail=f"Insufficient stock for '{variant['variant_name']}'. Available: {variant['stock_quantity']}"
                )

            line_total = variant["selling_price"] * item.quantity
            computed_total += line_total

            order_items_data.append({
                "product_id": variant["product_id"],
                "variant_id": item.variant_id,
                "quantity": item.quantity,
                "price_at_time": variant["selling_price"],
                "mrp_at_time": variant["mrp"],
                "discount_at_time": variant["mrp"] - variant["selling_price"],
                "product_name_snapshot": variant["products"]["name"] if variant.get("products") else "Unknown",
                "variant_name_snapshot": variant["variant_name"],
            })

        # ---- 1b. Enforce Minimum Order Amount ----
        if settings:
            min_order = float(settings.get("min_order_amount") or 0.0)
            if min_order > 0 and computed_total < min_order:
                raise HTTPException(
                    status_code=400,
                    detail=f"Minimum order amount is ₹{min_order:.0f}. Current item subtotal is ₹{computed_total:.0f}."
                )

        # ---- 1c. Determine Delivery Fee ----
        delivery_fee = order.delivery_fee
        if delivery_fee is None and settings:
            free_above = float(settings.get("free_delivery_above") or 0.0)
            fixed_fee = float(settings.get("delivery_fee_fixed") or 0.0)
            if free_above > 0 and computed_total >= free_above:
                delivery_fee = 0.0
            else:
                delivery_fee = fixed_fee

        final_total = order.total_amount or (computed_total + (delivery_fee or 0.0))

        # ---- 2. Insert order ----
        order_data = {
            "user_id": user_id,
            "status": "pending",
            "total_amount": final_total,
            "delivery_fee": delivery_fee,
            "discount_amount": order.discount_amount,
            "coupon_code": order.coupon_code,
            "payment_method": order.payment_method,
            "payment_status": "pending",
            "delivery_address": order.delivery_address,
            "delivery_lat": order.delivery_lat,
            "delivery_lng": order.delivery_lng,
            "delivery_notes": order.delivery_notes,
        }

        order_resp = supabase.table("orders").insert(order_data).execute()
        if not order_resp.data:
            raise HTTPException(status_code=400, detail="Could not create order")

        new_order_id = order_resp.data[0]["id"]

        # ---- 3. Insert order items ----
        for item_data in order_items_data:
            item_data["order_id"] = new_order_id

        supabase.table("order_items").insert(order_items_data).execute()

        # ---- 4. Decrement stock (RPC with direct fallback) ----
        for item in order.items:
            try:
                supabase.rpc("decrement_variant_stock", {
                    "p_variant_id": item.variant_id,
                    "p_quantity": item.quantity,
                }).execute()
            except Exception:
                try:
                    var_resp = supabase.from_("product_variants").select("stock_quantity").eq("id", item.variant_id).single().execute()
                    if var_resp.data:
                        new_stk = max(0, var_resp.data["stock_quantity"] - item.quantity)
                        supabase.from_("product_variants").update({"stock_quantity": new_stk}).eq("id", item.variant_id).execute()
                except Exception as fallback_err:
                    print(f"Stock decrement fallback error: {fallback_err}")

        return {**order_resp.data[0], "items": order_items_data}

    except HTTPException:
        raise
    except Exception as e:
        print(f"Error creating order: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/{order_id}/assign")
def assign_order(order_id: int, assign_data: OrderAssign):
    try:
        response = supabase.from_("orders").update({
            "rider_id": str(assign_data.rider_id),
            "status": "confirmed"
        }).eq("id", order_id).execute()

        if not response.data:
            raise HTTPException(status_code=404, detail="Order not found")
        return response.data[0]
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error assigning order: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/{order_id}/status")
def update_status(order_id: int, status_data: OrderUpdate):
    try:
        update_data = {"status": status_data.status}

        # If delivered, restore stock is NOT needed (item already consumed)
        # If cancelled, restore stock
        if status_data.status == "cancelled":
            # Fetch items and restore stock
            items_resp = supabase.from_("order_items").select("variant_id, quantity").eq("order_id", order_id).execute()
            for item in (items_resp.data or []):
                if item.get("variant_id"):
                    supabase.rpc("increment_variant_stock", {
                        "p_variant_id": item["variant_id"],
                        "p_quantity": item["quantity"],
                    }).execute()

        response = supabase.from_("orders").update(update_data).eq("id", order_id).execute()
        if not response.data:
            raise HTTPException(status_code=404, detail="Order not found")
        return response.data[0]
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error updating order status: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
