import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

url: str = os.environ.get("SUPABASE_URL")
key: str = os.environ.get("SUPABASE_KEY")

supabase: Client = None

if url and key and "YOUR_SUPABASE" not in url:
    try:
        supabase = create_client(url, key)
    except Exception as e:
        print(f"Error initializing Supabase: {e}")
else:
    print("Warning: Supabase credentials not found or are placeholders. Database features will not work.")
