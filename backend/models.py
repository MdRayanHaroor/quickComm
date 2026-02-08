from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from uuid import UUID

# Enums
from enum import Enum

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

# Profile Models
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

# Product Models
class ProductBase(BaseModel):
    name: str
    description: Optional[str] = None
    size: Optional[str] = None
    price: float
    category: str = "Main Course"
    image_url: Optional[str] = None
    is_available: bool = True

class ProductCreate(ProductBase):
    pass
class Product(ProductBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True

# Order Models
class OrderItemBase(BaseModel):
    product_id: int
    quantity: int

class OrderCreate(BaseModel):
    items: List[OrderItemBase]
    delivery_address: str
    delivery_lat: Optional[float] = None
    delivery_lng: Optional[float] = None
    total_amount: float

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
    delivery_address: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# Rider Location Models
class RiderLocationBase(BaseModel):
    lat: float
    lng: float

class RiderLocationUpdate(RiderLocationBase):
    pass

class RiderLocation(RiderLocationBase):
    id: int
    rider_id: UUID
    last_updated: datetime

    class Config:
        from_attributes = True
