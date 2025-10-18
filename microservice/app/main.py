from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
import os
import json
import asyncio
import aiohttp
import time
from datetime import datetime, UTC
from typing import List, Dict, Optional
import logging
from contextlib import asynccontextmanager

# Import database and routers (conditional to allow running without dependencies)
try:
    from .database import db_manager
    from .routers import database
    DATABASE_AVAILABLE = True
except ImportError as e:
    print(f"Database dependencies not available: {e}")
    print("Microservice will run without database functionality")
    db_manager = None
    database = None
    DATABASE_AVAILABLE = False

# Configure logging
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format='{"timestamp": "%(asctime)s", "level": "%(levelname)s", "message": "%(message)s", "service": "%(name)s"}'
)
logger = logging.getLogger(__name__)

# Service configuration
SERVICE_NAME = os.getenv("SERVICE_NAME", "microservice")
SERVICE_PORT = int(os.getenv("SERVICE_PORT", "8000"))
SERVICE_VERSION = os.getenv("SERVICE_VERSION", "1.0.0")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
ENABLE_METRICS = os.getenv("ENABLE_METRICS", "true").lower() == "true"
RATE_LIMIT = int(os.getenv("RATE_LIMIT", "100"))

# Parse consumer services from environment
CONSUMER_SERVICES = []
try:
    consumer_services_json = os.getenv("CONSUMER_SERVICES", "[]")
    CONSUMER_SERVICES = json.loads(consumer_services_json)
except json.JSONDecodeError:
    logger.warning("Invalid CONSUMER_SERVICES JSON, using empty list")

# Metrics storage
metrics = {
    "requests_total": 0,
    "requests_by_status": {},
    "requests_by_endpoint": {},
    "service_calls_total": 0,
    "service_calls_by_service": {},
    "start_time": time.time()
}

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info(f"Starting {SERVICE_NAME} v{SERVICE_VERSION} on port {SERVICE_PORT}")
    logger.info(f"Consumer services: {len(CONSUMER_SERVICES)}")
    
    # Initialize database connections (if available)
    if DATABASE_AVAILABLE and db_manager:
        await db_manager.initialize()
        # Database initialization is non-blocking - microservice continues even if databases fail
    else:
        logger.info("Database functionality not available - running without databases")
    
    yield
    
    # Shutdown
    logger.info(f"Shutting down {SERVICE_NAME}")
    if DATABASE_AVAILABLE and db_manager:
        try:
            await db_manager.close()
            logger.info("Database connections closed successfully")
        except Exception as e:
            logger.error(f"Error closing database connections: {e}")

app = FastAPI(
    title=f"{SERVICE_NAME.title()} API",
    description=f"Multi-account microservice for {SERVICE_NAME}",
    version=SERVICE_VERSION,
    lifespan=lifespan
)

# Add middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["*"]  # Configure appropriately for production
)

# Rate limiting (simple in-memory implementation)
request_counts = {}

async def rate_limit_middleware(request: Request, call_next):
    client_ip = request.client.host
    current_time = time.time()
    
    # Clean old entries
    request_counts[client_ip] = [
        req_time for req_time in request_counts.get(client_ip, [])
        if current_time - req_time < 60  # Last minute
    ]
    
    # Check rate limit
    if len(request_counts.get(client_ip, [])) >= RATE_LIMIT:
        return JSONResponse(
            status_code=429,
            content={"error": "Rate limit exceeded", "retry_after": 60}
        )
    
    # Add current request
    if client_ip not in request_counts:
        request_counts[client_ip] = []
    request_counts[client_ip].append(current_time)
    
    response = await call_next(request)
    return response

app.middleware("http")(rate_limit_middleware)

# Include database router (if available)
if DATABASE_AVAILABLE and database:
    app.include_router(database.router)

# Request logging middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    
    # Update metrics
    metrics["requests_total"] += 1
    endpoint = f"{request.method} {request.url.path}"
    metrics["requests_by_endpoint"][endpoint] = metrics["requests_by_endpoint"].get(endpoint, 0) + 1
    
    response = await call_next(request)
    
    # Log request
    process_time = time.time() - start_time
    status_code = response.status_code
    metrics["requests_by_status"][str(status_code)] = metrics["requests_by_status"].get(str(status_code), 0) + 1
    
    logger.info(
        f"{request.method} {request.url.path} {status_code} {process_time:.3f}s",
        extra={
            "method": request.method,
            "path": request.url.path,
            "status_code": status_code,
            "process_time": process_time,
            "client_ip": request.client.host
        }
    )
    
    return response

@app.get("/")
async def root():
    """Root endpoint with service information"""
    return {
        "message": f"Welcome to {SERVICE_NAME}",
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "status": "running",
        "timestamp": datetime.now(UTC).isoformat() + "Z",
        "consumer_services": len(CONSUMER_SERVICES)
    }

@app.get("/health")
async def health_check():
    """Basic health check endpoint"""
    return {
        "status": "healthy",
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "timestamp": datetime.now(UTC).isoformat() + "Z"
    }

@app.get("/ready")
async def readiness_check():
    """Readiness check endpoint (includes dependency checks)"""
    dependencies_status = {}
    
    # HTTP service is ready if we can reach this endpoint
    dependencies_status["http"] = True
    
    # Check database connections (if available)
    if DATABASE_AVAILABLE and db_manager:
        try:
            # Check PostgreSQL
            if db_manager.pg_pool:
                async with db_manager.pg_pool.acquire() as conn:
                    await conn.fetchval("SELECT 1")
                dependencies_status["postgresql"] = True
            else:
                dependencies_status["postgresql"] = False
                
            # Check Redis
            if db_manager.redis_client:
                await db_manager.redis_client.ping()
                dependencies_status["redis"] = True
            else:
                dependencies_status["redis"] = False
                
            # Check DynamoDB
            if db_manager.dynamo_table:
                db_manager.dynamo_table.describe_table()
                dependencies_status["dynamodb"] = True
            else:
                dependencies_status["dynamodb"] = False
                
        except Exception as e:
            logger.warning(f"Database readiness check failed: {e}")
            dependencies_status["postgresql"] = False
            dependencies_status["redis"] = False
            dependencies_status["dynamodb"] = False
    else:
        # Database functionality not available
        dependencies_status["postgresql"] = False
        dependencies_status["redis"] = False
        dependencies_status["dynamodb"] = False
    
    # Service is ready if HTTP is working (databases are optional for basic functionality)
    if dependencies_status.get("http", False):
        return {
            "status": "ready",
            "service": SERVICE_NAME,
            "version": SERVICE_VERSION,
            "timestamp": datetime.now(UTC).isoformat() + "Z",
            "dependencies": dependencies_status,
            "note": "Database connections are optional for basic functionality"
        }
    
    raise HTTPException(status_code=503, detail="Service not ready")

@app.get("/services")
async def list_services():
    """List discovered consumer services"""
    return {
        "services": CONSUMER_SERVICES,
        "count": len(CONSUMER_SERVICES),
        "timestamp": datetime.now(UTC).isoformat() + "Z"
    }

@app.post("/call/{service_name}")
async def call_service(service_name: str, request_data: dict = None):
    """Call another microservice"""
    # Find the service
    service = next((s for s in CONSUMER_SERVICES if s["name"] == service_name), None)
    if not service:
        raise HTTPException(status_code=404, detail=f"Service {service_name} not found")
    
    # Update metrics
    metrics["service_calls_total"] += 1
    metrics["service_calls_by_service"][service_name] = metrics["service_calls_by_service"].get(service_name, 0) + 1
    
    try:
        # Make the call
        url = f"http://{service['endpoint']}:{service['port']}"
        timeout = service.get("timeout", 30)
        
        async with aiohttp.ClientSession() as session:
            async with session.post(url, json=request_data, timeout=timeout) as response:
                result = await response.json()
                
                logger.info(f"Called {service_name}: {response.status}")
                return {
                    "service": service_name,
                    "status": response.status,
                    "result": result,
                    "timestamp": datetime.now(UTC).isoformat() + "Z"
                }
    except asyncio.TimeoutError:
        logger.error(f"Timeout calling {service_name}")
        raise HTTPException(status_code=504, detail=f"Timeout calling {service_name}")
    except Exception as e:
        logger.error(f"Error calling {service_name}: {e}")
        raise HTTPException(status_code=502, detail=f"Error calling {service_name}: {str(e)}")

@app.get("/status")
async def service_status():
    """Get detailed service status"""
    uptime = time.time() - metrics["start_time"]
    
    return {
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "status": "running",
        "uptime_seconds": uptime,
        "uptime_human": f"{int(uptime // 3600)}h {int((uptime % 3600) // 60)}m {int(uptime % 60)}s",
        "metrics": {
            "requests_total": metrics["requests_total"],
            "requests_by_status": metrics["requests_by_status"],
            "requests_by_endpoint": metrics["requests_by_endpoint"],
            "service_calls_total": metrics["service_calls_total"],
            "service_calls_by_service": metrics["service_calls_by_service"]
        },
        "consumer_services": len(CONSUMER_SERVICES),
        "timestamp": datetime.now(UTC).isoformat() + "Z"
    }

@app.get("/metrics")
async def prometheus_metrics():
    """Prometheus-compatible metrics endpoint"""
    if not ENABLE_METRICS:
        raise HTTPException(status_code=404, detail="Metrics disabled")
    
    uptime = time.time() - metrics["start_time"]
    
    metrics_text = f"""# HELP microservice_requests_total Total number of requests
# TYPE microservice_requests_total counter
microservice_requests_total {metrics["requests_total"]}

# HELP microservice_uptime_seconds Service uptime in seconds
# TYPE microservice_uptime_seconds gauge
microservice_uptime_seconds {uptime}

# HELP microservice_consumer_services Number of consumer services
# TYPE microservice_consumer_services gauge
microservice_consumer_services {len(CONSUMER_SERVICES)}
"""
    
    # Add status code metrics
    for status, count in metrics["requests_by_status"].items():
        metrics_text += f"microservice_requests_by_status{{status=\"{status}\"}} {count}\n"
    
    # Add endpoint metrics
    for endpoint, count in metrics["requests_by_endpoint"].items():
        safe_endpoint = endpoint.replace(" ", "_").replace("/", "_")
        metrics_text += f"microservice_requests_by_endpoint{{endpoint=\"{safe_endpoint}\"}} {count}\n"
    
    # Add service call metrics
    for service, count in metrics["service_calls_by_service"].items():
        metrics_text += f"microservice_service_calls_total{{service=\"{service}\"}} {count}\n"
    
    return metrics_text

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=SERVICE_PORT)