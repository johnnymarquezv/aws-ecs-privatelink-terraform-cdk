from fastapi import FastAPI
from app.routers import hello

app = FastAPI()

app.include_router(hello.router)

@app.get("/")
async def root():
    return {"message": "Welcome to the ECS Python microservice!"}

@app.get("/health")
async def health_check():
    """Health check endpoint for load balancer health checks"""
    return {"status": "healthy", "service": "microservice"}
