import os
import json
import asyncio
import logging
from typing import Optional, Dict, Any, List
from datetime import datetime, timedelta
import asyncpg
import boto3
import redis.asyncio as redis
import uuid

logger = logging.getLogger(__name__)

# Database configuration
RDS_SECRET_ARN = os.getenv("RDS_SECRET_ARN", "")
DYNAMO_TABLE_NAME = os.getenv("DYNAMO_TABLE_NAME", "")
REDIS_ENDPOINT = os.getenv("REDIS_ENDPOINT", "")

# Simple database models (no ORM needed)

class DatabaseManager:
    def __init__(self):
        self.pg_pool: Optional[asyncpg.Pool] = None
        self.redis_client: Optional[redis.Redis] = None
        self.dynamodb = None
        self.rds_credentials = None
        self.engine = None
        self.SessionLocal = None
        
    async def initialize(self):
        """Initialize all database connections"""
        try:
            await self._initialize_rds()
            await self._initialize_redis()
            await self._initialize_dynamodb()
            logger.info("All database connections initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize database connections: {e}")
            # Don't raise - allow microservice to continue without databases
            logger.info("Microservice will continue without database connections")
    
    async def _initialize_rds(self):
        """Initialize RDS PostgreSQL connection"""
        if not RDS_SECRET_ARN:
            logger.warning("RDS_SECRET_ARN not provided, skipping RDS initialization")
            return
            
        try:
            # Get credentials from AWS Secrets Manager
            secrets_client = boto3.client('secretsmanager')
            secret_response = secrets_client.get_secret_value(SecretId=RDS_SECRET_ARN)
            self.rds_credentials = json.loads(secret_response['SecretString'])
            
            # Create connection string
            connection_string = (
                f"postgresql://{self.rds_credentials['username']}:"
                f"{self.rds_credentials['password']}@"
                f"{self.rds_credentials['host']}:"
                f"{self.rds_credentials['port']}/"
                f"{self.rds_credentials['dbname']}"
            )
            
            # Create asyncpg pool
            self.pg_pool = await asyncpg.create_pool(
                connection_string,
                min_size=1,
                max_size=10,
                command_timeout=60
            )
            
            # Note: Tables should be created manually or via CDK/CloudFormation
            
            logger.info("RDS PostgreSQL connection initialized")
            
        except Exception as e:
            logger.error(f"Failed to initialize RDS connection: {e}")
            # Don't raise - allow microservice to continue without RDS
    
    async def _initialize_redis(self):
        """Initialize Redis connection"""
        if not REDIS_ENDPOINT:
            logger.warning("REDIS_ENDPOINT not provided, skipping Redis initialization")
            return
            
        try:
            self.redis_client = redis.from_url(
                f"redis://{REDIS_ENDPOINT}:6379",
                decode_responses=True,
                socket_connect_timeout=5,
                socket_timeout=5,
                retry_on_timeout=True
            )
            
            # Test connection
            await self.redis_client.ping()
            logger.info("Redis connection initialized")
            
        except Exception as e:
            logger.error(f"Failed to initialize Redis connection: {e}")
            # Don't raise - allow microservice to continue without Redis
    
    async def _initialize_dynamodb(self):
        """Initialize DynamoDB connection"""
        if not DYNAMO_TABLE_NAME:
            logger.warning("DYNAMO_TABLE_NAME not provided, skipping DynamoDB initialization")
            return
            
        try:
            self.dynamodb = boto3.resource('dynamodb')
            self.dynamo_table = self.dynamodb.Table(DYNAMO_TABLE_NAME)
            
            # Test connection
            self.dynamo_table.describe_table()
            logger.info("DynamoDB connection initialized")
            
        except Exception as e:
            logger.error(f"Failed to initialize DynamoDB connection: {e}")
            # Don't raise - allow microservice to continue without DynamoDB
    
    async def close(self):
        """Close all database connections"""
        if self.pg_pool:
            await self.pg_pool.close()
        if self.redis_client:
            await self.redis_client.close()
        # Clean up any other resources if needed
    
    # RDS PostgreSQL methods
    async def create_user(self, username: str, email: str, full_name: str) -> Dict[str, Any]:
        """Create a new user in PostgreSQL"""
        if not self.pg_pool:
            raise Exception("PostgreSQL connection not initialized")
            
        async with self.pg_pool.acquire() as conn:
            user_id = uuid.uuid4()
            # Simple table creation and insert (tables created via CDK)
            await conn.execute(
                """
                CREATE TABLE IF NOT EXISTS users (
                    id UUID PRIMARY KEY,
                    username VARCHAR(50) UNIQUE NOT NULL,
                    email VARCHAR(100) UNIQUE NOT NULL,
                    full_name VARCHAR(100) NOT NULL,
                    is_active BOOLEAN DEFAULT TRUE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
            
            await conn.execute(
                """
                INSERT INTO users (id, username, email, full_name, created_at, updated_at)
                VALUES ($1, $2, $3, $4, $5, $6)
                """,
                user_id, username, email, full_name, datetime.utcnow(), datetime.utcnow()
            )
            
            return {
                "id": str(user_id),
                "username": username,
                "email": email,
                "full_name": full_name,
                "created_at": datetime.utcnow().isoformat()
            }
    
    async def get_user(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get user by ID from PostgreSQL"""
        if not self.pg_pool:
            raise Exception("PostgreSQL connection not initialized")
            
        async with self.pg_pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM users WHERE id = $1",
                uuid.UUID(user_id)
            )
            
            if row:
                return dict(row)
            return None
    
    async def log_api_request(self, endpoint: str, method: str, status_code: int, 
                            response_time: int, user_id: str = None, 
                            ip_address: str = None, user_agent: str = None):
        """Log API request to PostgreSQL"""
        if not self.pg_pool:
            return
            
        async with self.pg_pool.acquire() as conn:
            # Create table if it doesn't exist
            await conn.execute(
                """
                CREATE TABLE IF NOT EXISTS api_requests (
                    id UUID PRIMARY KEY,
                    user_id UUID,
                    endpoint VARCHAR(200) NOT NULL,
                    method VARCHAR(10) NOT NULL,
                    status_code INTEGER NOT NULL,
                    response_time INTEGER NOT NULL,
                    ip_address VARCHAR(45),
                    user_agent TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
            
            await conn.execute(
                """
                INSERT INTO api_requests (id, user_id, endpoint, method, status_code, 
                                        response_time, ip_address, user_agent, created_at)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                """,
                uuid.uuid4(),
                uuid.UUID(user_id) if user_id else None,
                endpoint,
                method,
                status_code,
                response_time,
                ip_address,
                user_agent,
                datetime.utcnow()
            )
    
    # Redis methods
    async def cache_set(self, key: str, value: Any, ttl: int = 3600):
        """Set value in Redis cache"""
        if not self.redis_client:
            return
            
        try:
            await self.redis_client.setex(key, ttl, json.dumps(value))
        except Exception as e:
            logger.error(f"Failed to set cache key {key}: {e}")
    
    async def cache_get(self, key: str) -> Optional[Any]:
        """Get value from Redis cache"""
        if not self.redis_client:
            return None
            
        try:
            value = await self.redis_client.get(key)
            if value:
                return json.loads(value)
            return None
        except Exception as e:
            logger.error(f"Failed to get cache key {key}: {e}")
            return None
    
    async def cache_delete(self, key: str):
        """Delete key from Redis cache"""
        if not self.redis_client:
            return
            
        try:
            await self.redis_client.delete(key)
        except Exception as e:
            logger.error(f"Failed to delete cache key {key}: {e}")
    
    # DynamoDB methods
    async def store_session_data(self, session_id: str, data: Dict[str, Any], ttl: int = 86400):
        """Store session data in DynamoDB"""
        if not self.dynamo_table:
            return
            
        try:
            item = {
                'id': session_id,
                'timestamp': int(datetime.utcnow().timestamp()),
                'data': json.dumps(data),
                'ttl': int((datetime.utcnow() + timedelta(seconds=ttl)).timestamp())
            }
            
            self.dynamo_table.put_item(Item=item)
        except Exception as e:
            logger.error(f"Failed to store session data: {e}")
    
    async def get_session_data(self, session_id: str) -> Optional[Dict[str, Any]]:
        """Get session data from DynamoDB"""
        if not self.dynamo_table:
            return None
            
        try:
            response = self.dynamo_table.get_item(
                Key={'id': session_id, 'timestamp': int(datetime.utcnow().timestamp())}
            )
            
            if 'Item' in response:
                return json.loads(response['Item']['data'])
            return None
        except Exception as e:
            logger.error(f"Failed to get session data: {e}")
            return None
    
    async def get_user_activity(self, user_id: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Get user activity from DynamoDB using GSI"""
        if not self.dynamo_table:
            return []
            
        try:
            response = self.dynamo_table.query(
                IndexName='user-index',
                KeyConditionExpression='userId = :user_id',
                ExpressionAttributeValues={':user_id': user_id},
                ScanIndexForward=False,
                Limit=limit
            )
            
            return [item for item in response.get('Items', [])]
        except Exception as e:
            logger.error(f"Failed to get user activity: {e}")
            return []

# Global database manager instance
db_manager = DatabaseManager()

# Dependency for FastAPI
async def get_database():
    """FastAPI dependency to get database manager"""
    return db_manager
