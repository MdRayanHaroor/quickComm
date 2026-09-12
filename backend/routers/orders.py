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


@router.post("", status_code=201)
@router.post("/", status_code=201)
def create_order(order: OrderCreate, user_id: str = Query(..., description="Supabase user UUID")):
    """
    Create an order. Fetches variant data, captures snapshots, decrements stock.
    user_id is passed as query param (authenticated from client-side token in production).
    """
    try:
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

        # ---- 2. Insert order ----
        order_data = {
            "user_id": user_id,
            "status": "pending",
            "total_amount": order.total_amount or computed_total,
            "delivery_fee": order.delivery_fee,
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
