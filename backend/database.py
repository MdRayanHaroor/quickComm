import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

url: str = os.environ.get("SUPABASE_URL")
key: str = os.environ.get("SUPABASE_KEY")
service_key: str = os.environ.get("SUPABASE_SERVICE_KEY")

supabase: Client = None
admin_supabase: Client = None  # Uses service role key — for admin auth operations only

if url and key and "YOUR_SUPABASE" not in url:
    try:
        supabase = create_client(url, key)
    except Exception as e:
        print(f"Error initializing Supabase: {e}")
else:
    print("Warning: Supabase credentials not found or are placeholders. Database features will not work.")

if url and service_key and "YOUR_SERVICE_ROLE_KEY_HERE" not in service_key:
    try:
        admin_supabase = create_client(url, service_key)
    except Exception as e:
        print(f"Error initializing admin Supabase client: {e}")
else:
    print("Warning: SUPABASE_SERVICE_KEY not set. Rider creation/deletion will not work.")
