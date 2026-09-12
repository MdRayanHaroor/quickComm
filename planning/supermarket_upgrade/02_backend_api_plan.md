# Backend API Plan — Supermarket Upgrade

---

## Pydantic Models (New & Updated)

### New: `CategoryBase`, `Category`
```python
class CategoryBase(BaseModel):
    name: str
    slug: str
    parent_id: Optional[int] = None
    image_url: Optional[str] = None
    sort_order: int = 0
    is_active: bool = True

class CategoryCreate(CategoryBase): pass

class Category(CategoryBase):
    id: int
    created_at: datetime
    children: Optional[List['Category']] = []  # Nested tree support
```

### New: `BrandBase`, `Brand`
```python
class BrandBase(BaseModel):
    name: str
    logo_url: Optional[str] = None
    is_active: bool = True

class Brand(BrandBase):
    id: int
```

### New: `ProductVariantBase`, `ProductVariant`
```python
class ProductVariantBase(BaseModel):
    product_id: int
    sku: Optional[str] = None
    barcode: Optional[str] = None
    variant_name: str           # "500 ml", "1 kg"
    unit_value: Optional[float] = None
    unit_type: Optional[str] = None  # 'ml'|'l'|'g'|'kg'|'pcs'|'pack'
    mrp: float
    selling_price: float
    stock_quantity: int = 0
    low_stock_alert: int = 10
    is_available: bool = True
    image_url: Optional[str] = None
    sort_order: int = 0

class ProductVariantCreate(ProductVariantBase): pass
class ProductVariantUpdate(BaseModel):
    # All Optional for PATCH-style updates
    variant_name: Optional[str] = None
    mrp: Optional[float] = None
    selling_price: Optional[float] = None
    stock_quantity: Optional[int] = None
    is_available: Optional[bool] = None
    ...

class ProductVariant(ProductVariantBase):
    id: int
    created_at: datetime
    updated_at: datetime
```

### Updated: `ProductBase`, `Product`
```python
class ProductBase(BaseModel):
    name: str
    slug: Optional[str] = None
    description: Optional[str] = None
    brand_id: Optional[int] = None
    category_id: Optional[int] = None
    tags: List[str] = []
    images: List[str] = []       # Supabase Storage URLs
    image_url: Optional[str] = None  # deprecated, keep for compat
    gst_rate: float = 0
    is_available: bool = True    # Master product switch

class ProductCreate(ProductBase): pass

class Product(ProductBase):
    id: int
    created_at: datetime
    updated_at: datetime
    variants: Optional[List[ProductVariant]] = []  # Nested variants
    brand: Optional[Brand] = None
    category: Optional[Category] = None
```

---

## New API Endpoints

### Categories Router (`/categories`)

| Method | Path | Description |
|---|---|---|
| `GET` | `/categories/` | List all categories (flat list) |
| `GET` | `/categories/tree` | Nested tree structure for frontend nav |
| `GET` | `/categories/{id}` | Single category with children |
| `POST` | `/categories/` | Create category (admin only) |
| `PUT` | `/categories/{id}` | Update category (admin only) |
| `DELETE` | `/categories/{id}` | Delete category (admin only) |
| `POST` | `/categories/{id}/image` | Upload category image to Supabase Storage |

**Example Tree Response:**
```json
[
  {
    "id": 1,
    "name": "Dairy, Bread & Eggs",
    "slug": "dairy-bread-eggs",
    "image_url": "...",
    "children": [
      {"id": 4, "name": "Milk", "slug": "milk", "children": []},
      {"id": 5, "name": "Curd & Yoghurt", "slug": "curd-yoghurt", "children": []}
    ]
  }
]
```

---

### Brands Router (`/brands`)

| Method | Path | Description |
|---|---|---|
| `GET` | `/brands/` | List all brands |
| `POST` | `/brands/` | Create brand (admin) |
| `PUT` | `/brands/{id}` | Update brand (admin) |
| `DELETE` | `/brands/{id}` | Delete brand (admin) |

---

### Products Router (`/products`) — Enhanced

| Method | Path | Description |
|---|---|---|
| `GET` | `/products/` | List products with filters + pagination |
| `GET` | `/products/{id}` | Single product with full variants |
| `POST` | `/products/` | Create product (admin) |
| `PUT` | `/products/{id}` | Update product (admin) |
| `DELETE` | `/products/{id}` | Delete product (admin) |
| `POST` | `/products/{id}/images` | Upload product images to Storage |
| `DELETE` | `/products/{id}/images/{filename}` | Delete a specific product image |
| `POST` | `/products/bulk-import` | CSV bulk import (admin) |

**Query Params for `GET /products/`:**
```
?category_id=5          Filter by category
?brand_id=2             Filter by brand
?search=milk            Full-text search on name/description
?is_available=true      Only available products
?page=1&limit=20        Pagination
?sort=price_asc         Sort: price_asc, price_desc, name_asc, newest
?tags=organic           Filter by tag
```

---

### Product Variants Router (`/products/{product_id}/variants`)

| Method | Path | Description |
|---|---|---|
| `GET` | `/products/{product_id}/variants` | List variants for a product |
| `POST` | `/products/{product_id}/variants` | Add a variant (admin) |
| `PUT` | `/products/{product_id}/variants/{variant_id}` | Update variant (admin) |
| `DELETE` | `/products/{product_id}/variants/{variant_id}` | Delete variant (admin) |
| `PATCH` | `/products/{product_id}/variants/{variant_id}/stock` | Update stock quantity |

---

### Inventory Router (`/inventory`)

| Method | Path | Description |
|---|---|---|
| `GET` | `/inventory/low-stock` | List variants where stock < low_stock_alert |
| `GET` | `/inventory/out-of-stock` | List variants where stock = 0 |
| `POST` | `/inventory/adjust` | Bulk stock adjustment (admin) |

---

### Image Upload — Supabase Storage Integration

**Implementation Plan:**
```python
# In backend/routers/uploads.py
from fastapi import UploadFile, File
import uuid

BUCKET_NAME = "product-images"

@router.post("/products/{product_id}/images")
async def upload_product_image(
    product_id: int,
    file: UploadFile = File(...),
    admin_client = Depends(get_admin_supabase)
):
    ext = file.filename.split(".")[-1]
    filename = f"products/{product_id}/{uuid.uuid4()}.{ext}"
    
    content = await file.read()
    response = admin_client.storage.from_(BUCKET_NAME).upload(
        path=filename,
        file=content,
        file_options={"content-type": file.content_type}
    )
    
    public_url = admin_client.storage.from_(BUCKET_NAME).get_public_url(filename)
    
    # Append to product's images array
    product = admin_client.from_("products").select("images").eq("id", product_id).single().execute()
    current_images = product.data.get("images", [])
    current_images.append(public_url)
    admin_client.from_("products").update({"images": current_images}).eq("id", product_id).execute()
    
    return {"url": public_url, "filename": filename}
```

**Supabase Storage Setup Required:**
- Create bucket: `product-images` (public)
- Create bucket: `category-images` (public)
- Create bucket: `brand-logos` (public)
- Set storage policies: public read, admin write only

---

## Updated `orders` Flow

When creating an order, `order_items` must now capture:
```python
# In routers/orders.py - create_order logic
for item in order.items:
    variant = supabase.from_("product_variants").select("*, products(name)").eq("id", item.variant_id).single().execute()
    
    order_items_data.append({
        "order_id": new_order_id,
        "product_id": variant.data["product_id"],
        "variant_id": item.variant_id,
        "quantity": item.quantity,
        "price_at_time": variant.data["selling_price"],
        "mrp_at_time": variant.data["mrp"],
        "discount_at_time": variant.data["mrp"] - variant.data["selling_price"],
        "product_name_snapshot": variant.data["products"]["name"],
        "variant_name_snapshot": variant.data["variant_name"],
    })
    
    # Decrement stock
    supabase.rpc("decrement_variant_stock", {
        "p_variant_id": item.variant_id,
        "p_quantity": item.quantity
    }).execute()
```

**Stock Decrement RPC (PostgreSQL function):**
```sql
CREATE OR REPLACE FUNCTION decrement_variant_stock(p_variant_id bigint, p_quantity int)
RETURNS void AS $$
BEGIN
  UPDATE product_variants
  SET stock_quantity = GREATEST(0, stock_quantity - p_quantity),
      updated_at = now()
  WHERE id = p_variant_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## File Structure Changes

```
backend/
  routers/
    products.py        ← Major rewrite
    categories.py      ← NEW
    brands.py          ← NEW
    variants.py        ← NEW
    inventory.py       ← NEW
    uploads.py         ← NEW (Supabase Storage integration)
    orders.py          ← Minor update (variant support)
    riders.py          ← No change
  models.py            ← Add new models
  main.py              ← Register new routers
```
