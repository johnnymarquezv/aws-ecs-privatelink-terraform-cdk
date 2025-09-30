from fastapi import FastAPI
from app.routers import hello

app = FastAPI()

app.include_router(hello.router)

@app.get("/")
async def root():
    return {"message": "Welcome to the ECS Python microservice!"}
