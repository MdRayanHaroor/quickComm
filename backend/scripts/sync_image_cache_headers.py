"""
Utility script to update existing Supabase storage images to have 1-year CDN caching headers (max-age=31536000).
Run this whenever existing images need their cache headers synchronized without manual re-upload.
"""
import mimetypes
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database import admin_supabase

BUCKET_NAME = "product-images"

def sync_bucket_caching(bucket: str = BUCKET_NAME):
    print(f"Checking images in bucket '{bucket}'...")
    products_folders = admin_supabase.storage.from_(bucket).list("products")
    
    updated_count = 0
    already_cached_count = 0

    for folder_item in products_folders:
        folder_name = folder_item["name"]
        prefix = f"products/{folder_name}"
        files = admin_supabase.storage.from_(bucket).list(prefix)

        for f in files:
            file_name = f["name"]
            file_path = f"{prefix}/{file_name}"
            metadata = f.get("metadata") or {}
            current_cache = metadata.get("cacheControl")

            if current_cache == "max-age=31536000":
                print(f"  [OK] Already cached: {file_path}")
                already_cached_count += 1
                continue

            content_type, _ = mimetypes.guess_type(file_name)
            content_type = content_type or metadata.get("mimetype") or "image/jpeg"

            print(f"  [UPDATING] {file_path} (current: {current_cache}) -> max-age=31536000...")
            try:
                data = admin_supabase.storage.from_(bucket).download(file_path)
                admin_supabase.storage.from_(bucket).update(
                    file_path,
                    data,
                    file_options={
                        "content-type": content_type,
                        "cache-control": "31536000",
                    },
                )
                updated_count += 1
                print(f"  [DONE] Updated {file_path}")
            except Exception as e:
                print(f"  [ERROR] Failed to update {file_path}: {e}")

    # Also clean up test file if it exists
    try:
        admin_supabase.storage.from_(bucket).remove(["test_cdn.jpg"])
    except Exception:
        pass

    print(f"\nSummary: {updated_count} updated, {already_cached_count} already cached.")

if __name__ == "__main__":
    sync_bucket_caching()
