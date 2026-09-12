import os
from typing import Optional
from fastapi import HTTPException
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

_supabase_client: Optional[Client] = None
_admin_supabase_client: Optional[Client] = None


def get_supabase(raise_error: bool = True) -> Optional[Client]:
    """Get or initialize the regular Supabase client."""
    global _supabase_client
    if _supabase_client is not None:
        return _supabase_client

    url = os.environ.get("SUPABASE_URL") or os.environ.get("VITE_SUPABASE_URL")
    key = (
        os.environ.get("SUPABASE_KEY")
        or os.environ.get("SUPABASE_ANON_KEY")
        or os.environ.get("VITE_SUPABASE_ANON_KEY")
        or os.environ.get("SUPABASE_SERVICE_KEY")
    )

    if url and key and "YOUR_SUPABASE" not in url:
        try:
            _supabase_client = create_client(url, key)
            return _supabase_client
        except Exception as e:
            print(f"Error initializing Supabase client: {e}")

    if raise_error:
        raise HTTPException(
            status_code=503,
            detail=(
                "Supabase is not configured on this deployment. Missing environment variables SUPABASE_URL and/or SUPABASE_KEY. "
                "Please add them in Vercel Project Settings -> Environment Variables, and click REDEPLOY on your latest deployment."
            ),
        )
    return None


def get_admin_supabase(raise_error: bool = False) -> Optional[Client]:
    """Get or initialize the admin (service role) Supabase client."""
    global _admin_supabase_client
    if _admin_supabase_client is not None:
        return _admin_supabase_client

    url = os.environ.get("SUPABASE_URL") or os.environ.get("VITE_SUPABASE_URL")
    service_key = os.environ.get("SUPABASE_SERVICE_KEY")

    if url and service_key and "YOUR_SERVICE_ROLE_KEY_HERE" not in service_key:
        try:
            _admin_supabase_client = create_client(url, service_key)
            return _admin_supabase_client
        except Exception as e:
            print(f"Error initializing admin Supabase client: {e}")

    if raise_error:
        raise HTTPException(
            status_code=503,
            detail=(
                "Admin Supabase client not configured. Missing SUPABASE_SERVICE_KEY. "
                "Please add SUPABASE_SERVICE_KEY in Vercel Project Settings -> Environment Variables and REDEPLOY."
            ),
        )
    return None


class SupabaseProxy:
    def __getattr__(self, name):
        client = get_supabase(raise_error=True)
        return getattr(client, name)

    def __bool__(self):
        return get_supabase(raise_error=False) is not None


class AdminSupabaseProxy:
    def __getattr__(self, name):
        client = get_admin_supabase(raise_error=True)
        return getattr(client, name)

    def __bool__(self):
        return get_admin_supabase(raise_error=False) is not None


supabase: Client = SupabaseProxy()
admin_supabase: Client = AdminSupabaseProxy()

