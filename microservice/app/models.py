from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
from uuid import UUID

# Request/Response Models
class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50, description="Username")
    email: EmailStr = Field(..., description="Email address")
    full_name: str = Field(..., min_length=1, max_length=100, description="Full name")

class UserUpdate(BaseModel):
    username: Optional[str] = Field(None, min_length=3, max_length=50)
    email: Optional[EmailStr] = None
    full_name: Optional[str] = Field(None, min_length=1, max_length=100)
    is_active: Optional[bool] = None

class UserResponse(BaseModel):
    id: UUID
    username: str
    email: str
    full_name: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

class ApiRequestLog(BaseModel):
    endpoint: str
    method: str
    status_code: int
    response_time: int
    user_id: Optional[UUID] = None
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None

class SessionData(BaseModel):
    session_id: str
    user_id: Optional[UUID] = None
    data: Dict[str, Any]
    ttl: int = 86400  # 24 hours default

class UserActivity(BaseModel):
    id: str
    user_id: str
    activity_type: str
    description: str
    metadata: Dict[str, Any]
    timestamp: int

class DatabaseStatus(BaseModel):
    postgresql: bool
    redis: bool
    dynamodb: bool
    last_check: datetime

class DatabaseMetrics(BaseModel):
    postgresql_connections: int
    redis_memory_usage: str
    dynamodb_item_count: int
    cache_hit_rate: float
    last_updated: datetime

# Database Health Models
class DatabaseHealth(BaseModel):
    status: str
    databases: DatabaseStatus
    metrics: Optional[DatabaseMetrics] = None
    errors: List[str] = []

# Service Response Models
class ServiceResponse(BaseModel):
    success: bool
    message: str
    data: Optional[Any] = None
    timestamp: datetime

class ErrorResponse(BaseModel):
    error: str
    detail: Optional[str] = None
    timestamp: datetime
