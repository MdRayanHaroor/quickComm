from fastapi import APIRouter, HTTPException, UploadFile, File, Path, Depends
from database import admin_supabase
from auth import get_current_admin
from rate_limiter import upload_rate_limiter
from typing import Optional
import uuid
import os

router = APIRouter(prefix="/upload", tags=["uploads"])

PRODUCT_BUCKET = "product-images"
CATEGORY_BUCKET = "category-images"
BRAND_BUCKET = "brand-logos"

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB


def _validate_image(file: UploadFile):
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type '{file.content_type}'. Allowed: JPG, PNG, WebP, GIF",
        )


def _get_ext(filename: str) -> str:
    parts = filename.rsplit(".", 1)
    return parts[1].lower() if len(parts) == 2 else "jpg"


async def _upload_to_storage(bucket: str, path: str, file: UploadFile) -> str:
    """Upload a file to Supabase Storage with CDN caching headers and return its public URL."""
    content = await file.read()

    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail="File too large. Maximum size is 5MB.")

    try:
        client = admin_supabase
        client.storage.from_(bucket).upload(
            path=path,
            file=content,
            file_options={
                "content-type": file.content_type,
                "cache-control": "31536000",  # 1 year CDN edge & client disk cache (Task 8.1)
                "upsert": "true",
            },
        )
        public_url = client.storage.from_(bucket).get_public_url(path)
        return public_url
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Storage upload failed: {str(e)}")


# ============================================================
# Product Image Upload
# ============================================================

@router.post("/product/{product_id}/image")
async def upload_product_image(
    product_id: int = Path(...),
    file: UploadFile = File(...),
    admin: dict = Depends(get_current_admin),
    _rate: None = Depends(upload_rate_limiter),
):
    """Upload an image for a product. Appends to the product's images array."""
    _validate_image(file)

    ext = _get_ext(file.filename or "image.jpg")
    filename = f"products/{product_id}/{uuid.uuid4()}.{ext}"

    url = await _upload_to_storage(PRODUCT_BUCKET, filename, file)

    # Append to product images array
    product = admin_supabase.from_("products").select("images, image_url").eq("id", product_id).single().execute()
    if not product.data:
        raise HTTPException(status_code=404, detail="Product not found")

    current_images: list = product.data.get("images") or []
    current_images.append(url)

    update_data = {"images": current_images}
    # Also set image_url if this is the first image (backward compat)
    if not product.data.get("image_url"):
        update_data["image_url"] = url

    admin_supabase.from_("products").update(update_data).eq("id", product_id).execute()

    return {"url": url, "filename": filename, "all_images": current_images}


@router.delete("/product/{product_id}/image")
async def delete_product_image(
    product_id: int,
    image_url: str,
    admin: dict = Depends(get_current_admin),
):
    """Remove an image URL from the product's images array."""
    product = admin_supabase.from_("products").select("images, image_url").eq("id", product_id).single().execute()
    if not product.data:
        raise HTTPException(status_code=404, detail="Product not found")

    current_images: list = product.data.get("images") or []
    if image_url not in current_images:
        raise HTTPException(status_code=404, detail="Image not found in product")

    current_images.remove(image_url)
    update_data = {"images": current_images}

    # Update image_url to first remaining image if it was the deleted one
    if product.data.get("image_url") == image_url:
        update_data["image_url"] = current_images[0] if current_images else None

    admin_supabase.from_("products").update(update_data).eq("id", product_id).execute()

    # Try to delete from storage if it is an uploaded blob (best-effort, don't fail if external URL)
    try:
        if f"/{PRODUCT_BUCKET}/" in image_url:
            path_part = image_url.split(f"/{PRODUCT_BUCKET}/")[1]
            # Strip query params or hash
            storage_path = path_part.split("?")[0].split("#")[0]
            if storage_path:
                res = admin_supabase.storage.from_(PRODUCT_BUCKET).remove([storage_path])
                print(f"Deleted from storage bucket '{PRODUCT_BUCKET}': {storage_path}, res: {res}")
    except Exception as err:
        print(f"Storage delete warning: {err}")

    return {"message": "Image removed", "remaining_images": current_images}


# ============================================================
# Category Image Upload
# ============================================================

@router.post("/category/{category_id}/image")
async def upload_category_image(
    category_id: int = Path(...),
    file: UploadFile = File(...),
    admin: dict = Depends(get_current_admin),
    _rate: None = Depends(upload_rate_limiter),
):
    _validate_image(file)
    ext = _get_ext(file.filename or "image.jpg")
    filename = f"categories/{category_id}/{uuid.uuid4()}.{ext}"

    url = await _upload_to_storage(CATEGORY_BUCKET, filename, file)

    admin_supabase.from_("categories").update({"image_url": url}).eq("id", category_id).execute()
    return {"url": url}


# ============================================================
# Brand Logo Upload
# ============================================================

@router.post("/brand/{brand_id}/logo")
async def upload_brand_logo(
    brand_id: int = Path(...),
    file: UploadFile = File(...),
    admin: dict = Depends(get_current_admin),
    _rate: None = Depends(upload_rate_limiter),
):
    _validate_image(file)
    ext = _get_ext(file.filename or "image.jpg")
    filename = f"brands/{brand_id}/{uuid.uuid4()}.{ext}"

    url = await _upload_to_storage(BRAND_BUCKET, filename, file)

    admin_supabase.from_("brands").update({"logo_url": url}).eq("id", brand_id).execute()
    return {"url": url}
