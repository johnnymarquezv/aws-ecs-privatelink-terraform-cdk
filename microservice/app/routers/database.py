from fastapi import APIRouter, HTTPException, Depends, Request
from typing import List, Optional
from datetime import datetime
import logging

from ..database import get_database, DatabaseManager
from ..models import (
    UserCreate, UserUpdate, UserResponse, SessionData, 
    UserActivity, DatabaseStatus, DatabaseHealth, ServiceResponse
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/database", tags=["database"])

@router.get("/health", response_model=DatabaseHealth)
async def database_health(db: DatabaseManager = Depends(get_database)):
    """Check database health status"""
    try:
        # Check PostgreSQL
        postgresql_status = False
        if db.pg_pool:
            try:
                async with db.pg_pool.acquire() as conn:
                    await conn.fetchval("SELECT 1")
                postgresql_status = True
            except Exception as e:
                logger.error(f"PostgreSQL health check failed: {e}")
        
        # Check Redis
        redis_status = False
        if db.redis_client:
            try:
                await db.redis_client.ping()
                redis_status = True
            except Exception as e:
                logger.error(f"Redis health check failed: {e}")
        
        # Check DynamoDB
        dynamodb_status = False
        if db.dynamo_table:
            try:
                db.dynamo_table.describe_table()
                dynamodb_status = True
            except Exception as e:
                logger.error(f"DynamoDB health check failed: {e}")
        
        overall_status = "healthy" if all([postgresql_status, redis_status, dynamodb_status]) else "degraded"
        
        return DatabaseHealth(
            status=overall_status,
            databases=DatabaseStatus(
                postgresql=postgresql_status,
                redis=redis_status,
                dynamodb=dynamodb_status,
                last_check=datetime.utcnow()
            )
        )
        
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        raise HTTPException(status_code=500, detail=f"Database health check failed: {str(e)}")

@router.post("/users", response_model=UserResponse)
async def create_user(
    user_data: UserCreate,
    db: DatabaseManager = Depends(get_database)
):
    """Create a new user"""
    try:
        if not db.pg_pool:
            raise HTTPException(status_code=503, detail="PostgreSQL not available")
        
        user = await db.create_user(
            username=user_data.username,
            email=user_data.email,
            full_name=user_data.full_name
        )
        
        return UserResponse(**user)
        
    except Exception as e:
        logger.error(f"Failed to create user: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create user: {str(e)}")

@router.get("/users/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: str,
    db: DatabaseManager = Depends(get_database)
):
    """Get user by ID"""
    try:
        if not db.pg_pool:
            raise HTTPException(status_code=503, detail="PostgreSQL not available")
        
        user = await db.get_user(user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        return UserResponse(**user)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get user: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get user: {str(e)}")

@router.post("/cache/{key}")
async def set_cache(
    key: str,
    value: dict,
    ttl: int = 3600,
    db: DatabaseManager = Depends(get_database)
):
    """Set value in Redis cache"""
    try:
        if not db.redis_client:
            raise HTTPException(status_code=503, detail="Redis not available")
        
        await db.cache_set(key, value, ttl)
        return ServiceResponse(
            success=True,
            message=f"Cache key '{key}' set successfully",
            timestamp=datetime.utcnow()
        )
        
    except Exception as e:
        logger.error(f"Failed to set cache: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to set cache: {str(e)}")

@router.get("/cache/{key}")
async def get_cache(
    key: str,
    db: DatabaseManager = Depends(get_database)
):
    """Get value from Redis cache"""
    try:
        if not db.redis_client:
            raise HTTPException(status_code=503, detail="Redis not available")
        
        value = await db.cache_get(key)
        if value is None:
            raise HTTPException(status_code=404, detail="Cache key not found")
        
        return ServiceResponse(
            success=True,
            message="Cache value retrieved successfully",
            data=value,
            timestamp=datetime.utcnow()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get cache: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get cache: {str(e)}")

@router.delete("/cache/{key}")
async def delete_cache(
    key: str,
    db: DatabaseManager = Depends(get_database)
):
    """Delete key from Redis cache"""
    try:
        if not db.redis_client:
            raise HTTPException(status_code=503, detail="Redis not available")
        
        await db.cache_delete(key)
        return ServiceResponse(
            success=True,
            message=f"Cache key '{key}' deleted successfully",
            timestamp=datetime.utcnow()
        )
        
    except Exception as e:
        logger.error(f"Failed to delete cache: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete cache: {str(e)}")

@router.post("/sessions")
async def store_session(
    session_data: SessionData,
    db: DatabaseManager = Depends(get_database)
):
    """Store session data in DynamoDB"""
    try:
        if not db.dynamo_table:
            raise HTTPException(status_code=503, detail="DynamoDB not available")
        
        await db.store_session_data(
            session_id=session_data.session_id,
            data=session_data.data,
            ttl=session_data.ttl
        )
        
        return ServiceResponse(
            success=True,
            message="Session data stored successfully",
            timestamp=datetime.utcnow()
        )
        
    except Exception as e:
        logger.error(f"Failed to store session: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to store session: {str(e)}")

@router.get("/sessions/{session_id}")
async def get_session(
    session_id: str,
    db: DatabaseManager = Depends(get_database)
):
    """Get session data from DynamoDB"""
    try:
        if not db.dynamo_table:
            raise HTTPException(status_code=503, detail="DynamoDB not available")
        
        data = await db.get_session_data(session_id)
        if data is None:
            raise HTTPException(status_code=404, detail="Session not found")
        
        return ServiceResponse(
            success=True,
            message="Session data retrieved successfully",
            data=data,
            timestamp=datetime.utcnow()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get session: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get session: {str(e)}")

@router.get("/users/{user_id}/activity", response_model=List[UserActivity])
async def get_user_activity(
    user_id: str,
    limit: int = 10,
    db: DatabaseManager = Depends(get_database)
):
    """Get user activity from DynamoDB"""
    try:
        if not db.dynamo_table:
            raise HTTPException(status_code=503, detail="DynamoDB not available")
        
        activities = await db.get_user_activity(user_id, limit)
        return [UserActivity(**activity) for activity in activities]
        
    except Exception as e:
        logger.error(f"Failed to get user activity: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get user activity: {str(e)}")

@router.get("/stats")
async def get_database_stats(db: DatabaseManager = Depends(get_database)):
    """Get database statistics and health information"""
    try:
        stats = {
            "postgresql_connected": db.pg_pool is not None,
            "redis_connected": db.redis_client is not None,
            "dynamodb_connected": db.dynamo_table is not None,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        return ServiceResponse(
            success=True,
            message="Database statistics retrieved successfully",
            data=stats,
            timestamp=datetime.utcnow()
        )
        
    except Exception as e:
        logger.error(f"Failed to get database stats: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get database stats: {str(e)}")
