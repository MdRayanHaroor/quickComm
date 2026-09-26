from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, EmailStr, Field
from database import supabase, admin_supabase
from auth import get_current_admin

router = APIRouter(prefix="/admin/riders", tags=["riders"])


class CreateRiderRequest(BaseModel):
    full_name: str = Field(..., min_length=1, description="Full name cannot be empty")
    email: EmailStr
    password: str = Field(..., min_length=6, description="Password must be at least 6 characters")
    phone_number: str = ""


class UpdateRiderRequest(BaseModel):
    full_name: str = Field(..., min_length=1, description="Full name cannot be empty")
    phone_number: str = ""


@router.get("")
@router.get("/")
def get_riders(admin: dict = Depends(get_current_admin)):
    """Get all riders with their profiles."""
    try:
        response = supabase.from_("profiles").select("*").eq("role", "rider").execute()
        profiles = response.data

        # Merge email from auth.users if admin client is available
        if admin_supabase:
            users_response = admin_supabase.auth.admin.list_users()
            users = getattr(users_response, "users", users_response)
            email_map = {user.id: user.email for user in users}
            for profile in profiles:
                profile["email"] = email_map.get(profile["id"], "")

        return profiles
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("")
@router.post("/")
def create_rider(payload: CreateRiderRequest, admin: dict = Depends(get_current_admin)):
    """Create a new rider auth user and profile. Requires service role key and admin token."""
    if not admin_supabase:
        raise HTTPException(
            status_code=503,
            detail="Admin Supabase client not configured. Please set SUPABASE_SERVICE_KEY in backend/.env",
        )
    try:
        # 1. Create auth user via admin API
        auth_response = admin_supabase.auth.admin.create_user({
            "email": payload.email,
            "password": payload.password,
            "email_confirm": True,  # Skip email confirmation
        })
        user_id = auth_response.user.id

        # 2. Upsert profile row with rider role and must_change_password flag
        profile_data = {
            "id": user_id,
            "full_name": payload.full_name.strip(),
            "phone_number": payload.phone_number.strip(),
            "role": "rider",
            "must_change_password": True,
        }
        admin_supabase.from_("profiles").upsert(profile_data).execute()

        return {"id": user_id, **profile_data}

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/{rider_id}")
def delete_rider(rider_id: str, admin: dict = Depends(get_current_admin)):
    """Delete a rider's auth user and profile. Requires service role key and admin token."""
    if not admin_supabase:
        raise HTTPException(
            status_code=503,
            detail="Admin Supabase client not configured. Please set SUPABASE_SERVICE_KEY in backend/.env",
        )
    try:
        admin_supabase.auth.admin.delete_user(rider_id)
        return {"success": True, "deleted_rider_id": rider_id}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.put("/{rider_id}")
def update_rider(rider_id: str, payload: UpdateRiderRequest, admin: dict = Depends(get_current_admin)):
    """Update a rider's profile."""
    if not admin_supabase:
        raise HTTPException(
            status_code=503,
            detail="Admin Supabase client not configured.",
        )
    try:
        update_data = {
            "full_name": payload.full_name.strip(),
            "phone_number": payload.phone_number.strip(),
        }
        response = admin_supabase.from_("profiles").update(update_data).eq("id", rider_id).execute()
        return response.data
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
