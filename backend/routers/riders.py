from fastapi import APIRouter
from database import supabase

router = APIRouter(prefix="/riders", tags=["riders"])

@router.get("/")
def get_riders():
    try:
        response = supabase.from_("rider_locations").select("*").execute()
        return response.data
    except Exception as e:
        print(f"Error fetching riders: {str(e)}")
        raise e
