from pydantic import BaseModel, field_validator
from typing import Optional, List, Any, Union
from datetime import datetime, time
from uuid import UUID
from enum import Enum


# ============================================================
# Enums
# ============================================================

class Role(str, Enum):
    ADMIN = "admin"
    RIDER = "rider"
    USER = "user"

class OrderStatus(str, Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    PREPARING = "preparing"
    OUT_FOR_DELIVERY = "out_for_delivery"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"

class PaymentMethod(str, Enum):
    COD = "cod"
    UPI = "upi"
    CARD = "card"
    WALLET = "wallet"
    NETBANKING = "netbanking"

class PaymentStatus(str, Enum):
    PENDING = "pending"
    PAID = "paid"
    FAILED = "failed"
    REFUNDED = "refunded"

class UnitType(str, Enum):
    ML = "ml"
    L = "l"
    G = "g"
    KG = "kg"
    PCS = "pcs"
    PACK = "pack"
    DOZEN = "dozen"


# ============================================================
# Profile Models
# ============================================================

class ProfileBase(BaseModel):
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    role: Role = Role.USER

class ProfileCreate(ProfileBase):
    pass

class Profile(ProfileBase):
    id: UUID
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================================
# Store Models
# ============================================================

class StoreBase(BaseModel):
    name: str
    slug: Optional[str] = None
    is_active: bool = True

class Store(StoreBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================================
# Brand Models
# ============================================================

class BrandBase(BaseModel):
    name: str
    logo_url: Optional[str] = None
    is_active: bool = True

    @field_validator('name')
    @classmethod
    def name_not_empty(cls, v: str) -> str:
        s = v.strip()
        if not s:
            raise ValueError('Brand name cannot be empty')
        return s

class BrandCreate(BrandBase):
    store_id: int = 1

class BrandUpdate(BaseModel):
    name: Optional[str] = None
    logo_url: Optional[str] = None
    is_active: Optional[bool] = None

class Brand(BrandBase):
    id: int
    store_id: int
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================================
# Category Models
# ============================================================

class CategoryBase(BaseModel):
    name: str
    slug: str
    parent_id: Optional[int] = None
    image_url: Optional[str] = None
    sort_order: int = 0
    is_active: bool = True

    @field_validator('name')
    @classmethod
    def name_not_empty(cls, v: str) -> str:
        s = v.strip()
        if not s:
            raise ValueError('Category name cannot be empty')
        return s

class CategoryCreate(CategoryBase):
    store_id: int = 1

class CategoryUpdate(BaseModel):
    name: Optional[str] = None
    slug: Optional[str] = None
    parent_id: Optional[int] = None
    image_url: Optional[str] = None
    sort_order: Optional[int] = None
    is_active: Optional[bool] = None

class Category(CategoryBase):
    id: int
    store_id: int
    created_at: datetime

    class Config:
        from_attributes = True

class CategoryTree(Category):
    """Category with nested children for tree response"""
    children: List['CategoryTree'] = []

CategoryTree.model_rebuild()


# ============================================================
# Product Variant Models
# ============================================================

class ProductVariantBase(BaseModel):
    variant_name: str
    unit_value: Optional[float] = None
    unit_type: Optional[str] = None
    mrp: float
    selling_price: float
    stock_quantity: int = 0
    low_stock_alert: int = 10
    is_available: bool = True
    image_url: Optional[str] = None
    sort_order: int = 0
    sku: Optional[str] = None
    barcode: Optional[str] = None

    @field_validator('variant_name')
    @classmethod
    def variant_name_not_empty(cls, v: str) -> str:
        s = v.strip()
        if not s:
            raise ValueError('Variant name cannot be empty')
        return s

    @field_validator('mrp')
    @classmethod
    def mrp_non_negative(cls, v: float) -> float:
        if v < 0:
            raise ValueError(f'mrp cannot be negative ({v})')
        return round(v, 2)

    @field_validator('selling_price')
    @classmethod
    def selling_price_validate(cls, v: float, info: Any) -> float:
        if v < 0:
            raise ValueError(f'selling_price cannot be negative ({v})')
        mrp = info.data.get('mrp')
        if mrp is not None and v > mrp:
            raise ValueError(f'selling_price ({v}) cannot exceed mrp ({mrp})')
        return round(v, 2)

    @field_validator('stock_quantity', 'low_stock_alert')
    @classmethod
    def quantity_non_negative(cls, v: int) -> int:
        if v < 0:
            raise ValueError(f'Quantity must be >= 0 (got {v})')
        return v

class ProductVariantCreate(ProductVariantBase):
    product_id: int

class ProductVariantUpdate(BaseModel):
    variant_name: Optional[str] = None
    unit_value: Optional[float] = None
    unit_type: Optional[str] = None
    mrp: Optional[float] = None
    selling_price: Optional[float] = None
    stock_quantity: Optional[int] = None
    low_stock_alert: Optional[int] = None
    is_available: Optional[bool] = None
    image_url: Optional[str] = None
    sort_order: Optional[int] = None
    sku: Optional[str] = None
    barcode: Optional[str] = None

    @field_validator('mrp', 'selling_price')
    @classmethod
    def update_prices_non_negative(cls, v: Optional[float]) -> Optional[float]:
        if v is not None and v < 0:
            raise ValueError('Price cannot be negative')
        return round(v, 2) if v is not None else None

    @field_validator('stock_quantity', 'low_stock_alert')
    @classmethod
    def update_quantity_non_negative(cls, v: Optional[int]) -> Optional[int]:
        if v is not None and v < 0:
            raise ValueError('Quantity must be >= 0')
        return v

class ProductVariant(ProductVariantBase):
    id: int
    product_id: int
    created_at: datetime
    updated_at: datetime

    # Computed field
    @property
    def discount_percent(self) -> float:
        if self.mrp > 0:
            return round(((self.mrp - self.selling_price) / self.mrp) * 100, 1)
        return 0.0

    class Config:
        from_attributes = True

class StockAdjust(BaseModel):
    variant_id: int
    quantity: int   # positive = add stock, negative = remove

    @field_validator('quantity')
    @classmethod
    def quantity_not_zero(cls, v: int) -> int:
        if v == 0:
            raise ValueError('Adjustment quantity cannot be zero')
        return v


# ============================================================
# Product Models
# ============================================================

class ProductBase(BaseModel):
    name: str
    slug: Optional[str] = None
    description: Optional[str] = None
    brand_id: Optional[int] = None
    category_id: Optional[int] = None
    store_id: int = 1
    price: float = 0.0                # legacy DB not-null column compatibility
    tags: Optional[List[str]] = []
    images: Optional[List[str]] = []
    image_url: Optional[str] = None   # deprecated legacy field
    gst_rate: float = 0
    is_available: bool = True

    @field_validator('name')
    @classmethod
    def name_not_empty(cls, v: str) -> str:
        s = v.strip()
        if not s:
            raise ValueError('Product name cannot be empty')
        return s

    @field_validator('gst_rate')
    @classmethod
    def gst_rate_valid(cls, v: float) -> float:
        if v not in (0.0, 5.0, 12.0, 18.0, 28.0):
            raise ValueError(f'Invalid GST rate {v}. Allowed rates: 0, 5, 12, 18, 28')
        return v

class ProductCreate(ProductBase):
    pass

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    slug: Optional[str] = None
    description: Optional[str] = None
    brand_id: Optional[int] = None
    category_id: Optional[int] = None
    tags: Optional[List[str]] = None
    images: Optional[List[str]] = None
    image_url: Optional[str] = None
    gst_rate: Optional[float] = None
    is_available: Optional[bool] = None

class Product(ProductBase):
    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None
    variants: List[ProductVariant] = []
    brand: Optional[Brand] = None
    category: Optional[Union[Category, str]] = None

    class Config:
        from_attributes = True

class ProductListItem(BaseModel):
    """Lightweight product for list views — no nested variants"""
    id: int
    name: str
    slug: Optional[str] = None
    description: Optional[str] = None
    category_id: Optional[int] = None
    brand_id: Optional[int] = None
    is_available: bool
    tags: Optional[List[str]] = []
    images: List[str] = []
    image_url: Optional[str] = None
    gst_rate: float = 0
    created_at: datetime
    updated_at: Optional[datetime] = None
    # Aggregated from variants
    min_price: Optional[float] = None
    max_price: Optional[float] = None
    variant_count: int = 0
    total_stock: int = 0

    class Config:
        from_attributes = True


# ============================================================
# Order Models
# ============================================================

class OrderItemInput(BaseModel):
    """What the client sends when placing an order"""
    variant_id: int
    quantity: int

class OrderCreate(BaseModel):
    items: List[OrderItemInput]
    delivery_address: str
    delivery_lat: Optional[float] = None
    delivery_lng: Optional[float] = None
    total_amount: float
    delivery_fee: float = 0
    discount_amount: float = 0
    coupon_code: Optional[str] = None
    payment_method: PaymentMethod = PaymentMethod.COD
    delivery_notes: Optional[str] = None

class OrderUpdate(BaseModel):
    status: OrderStatus

class OrderAssign(BaseModel):
    rider_id: UUID

class Order(BaseModel):
    id: int
    user_id: UUID
    rider_id: Optional[UUID] = None
    status: OrderStatus
    total_amount: float
    delivery_fee: float = 0
    discount_amount: float = 0
    coupon_code: Optional[str] = None
    payment_method: Optional[str] = None
    payment_status: Optional[str] = None
    delivery_address: str
    delivery_lat: Optional[float] = None
    delivery_lng: Optional[float] = None
    delivery_notes: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ============================================================
# Customer Address Models
# ============================================================

class CustomerAddressBase(BaseModel):
    label: str = "Home"
    address_line1: str
    address_line2: Optional[str] = None
    landmark: Optional[str] = None
    city: str = "Hyderabad"
    pincode: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    is_default: bool = False

class CustomerAddressCreate(CustomerAddressBase):
    pass

class CustomerAddressUpdate(BaseModel):
    label: Optional[str] = None
    address_line1: Optional[str] = None
    address_line2: Optional[str] = None
    landmark: Optional[str] = None
    city: Optional[str] = None
    pincode: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    is_default: Optional[bool] = None

class CustomerAddress(CustomerAddressBase):
    id: int
    user_id: UUID
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================================
# Store Settings Models
# ============================================================

class StoreSettingsUpdate(BaseModel):
    store_name: Optional[str] = None
    store_logo_url: Optional[str] = None
    store_address: Optional[str] = None
    phone_number: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    delivery_radius_km: Optional[float] = None
    min_order_amount: Optional[float] = None
    delivery_fee_fixed: Optional[float] = None
    free_delivery_above: Optional[float] = None
    is_open: Optional[bool] = None
    opening_time: Optional[str] = None
    closing_time: Optional[str] = None
    days_open: Optional[List[str]] = None


# ============================================================
# Rider Location Models (unchanged)
# ============================================================

class RiderLocationBase(BaseModel):
    lat: float
    lng: float

class RiderLocationUpdate(RiderLocationBase):
    pass

class RiderLocation(RiderLocationBase):
    rider_id: UUID
    last_updated: datetime

    class Config:
        from_attributes = True


# ============================================================
# Inventory / Utility Models
# ============================================================

class LowStockItem(BaseModel):
    variant_id: int
    product_id: int
    product_name: str
    variant_name: str
    stock_quantity: int
    low_stock_alert: int

class BulkStockAdjust(BaseModel):
    adjustments: List[StockAdjust]
