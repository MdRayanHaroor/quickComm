from fastapi import APIRouter, HTTPException
from database import supabase
from models import Order, OrderUpdate, OrderAssign

router = APIRouter(prefix="/orders", tags=["orders"])

@router.get("/")
def get_orders():
    try:
        response = supabase.from_("orders").select("*").order("created_at", desc=True).execute()
        return response.data
    except Exception as e:
        print(f"Error fetching orders: {str(e)}")
        raise e

@router.put("/{order_id}/assign")
def assign_order(order_id: int, assign_data: OrderAssign):
    try:
        # Update rider_id and set status to 'confirmed' or 'preparing'
        response = supabase.from_("orders").update({
            "rider_id": str(assign_data.rider_id),
            "status": "confirmed" 
        }).eq("id", order_id).execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail="Order not found")
        return response.data[0]
    except Exception as e:
        print(f"Error assigning order: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/{order_id}/status")
def update_status(order_id: int, status_data: OrderUpdate):
    try:
        response = supabase.from_("orders").update({
            "status": status_data.status
        }).eq("id", order_id).execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail="Order not found")
        return response.data[0]
    except Exception as e:
        print(f"Error updating order status: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
