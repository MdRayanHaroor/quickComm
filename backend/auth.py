from fastapi import HTTPException, Security, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from database import admin_supabase
from typing import Optional, Dict, Any

security = HTTPBearer(auto_error=False)


async def get_current_admin(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security),
) -> Dict[str, Any]:
    """
    Validates Supabase JWT access token and ensures caller has 'admin' role in profiles.
    Raises 401 if token is missing or invalid.
    Raises 403 if user is authenticated but not an admin.
    """
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required. Please provide a valid Bearer token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials

    if not admin_supabase:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin auth service not configured.",
        )

    try:
        # 1. Verify token with Supabase Auth
        user_response = admin_supabase.auth.get_user(token)
        user = getattr(user_response, "user", None)
        if not user or not hasattr(user, "id"):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired authentication token.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # 2. Check profile role
        profile_resp = (
            admin_supabase.from_("profiles")
            .select("id, role, full_name, phone_number")
            .eq("id", user.id)
            .maybe_single()
            .execute()
        )

        profile = profile_resp.data
        if not profile or profile.get("role") != "admin":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied: Admin privileges required.",
            )

        return profile

    except HTTPException:
        raise
    except Exception as e:
        print(f"Auth verification error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication verification failed.",
            headers={"WWW-Authenticate": "Bearer"},
        )
