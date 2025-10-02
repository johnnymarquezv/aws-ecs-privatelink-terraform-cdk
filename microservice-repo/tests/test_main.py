import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_root():
    """Test root endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert "service" in data
    assert "version" in data
    assert "status" in data

def test_health():
    """Test health check endpoint"""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "service" in data
    assert "version" in data

def test_ready():
    """Test readiness check endpoint"""
    response = client.get("/ready")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ready"
    assert "dependencies" in data

def test_services():
    """Test services list endpoint"""
    response = client.get("/services")
    assert response.status_code == 200
    data = response.json()
    assert "services" in data
    assert "count" in data
    assert isinstance(data["services"], list)

def test_status():
    """Test status endpoint"""
    response = client.get("/status")
    assert response.status_code == 200
    data = response.json()
    assert "service" in data
    assert "version" in data
    assert "status" in data
    assert "uptime_seconds" in data
    assert "metrics" in data

def test_metrics():
    """Test metrics endpoint"""
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "microservice_requests_total" in response.text
    assert "microservice_uptime_seconds" in response.text

def test_call_service_not_found():
    """Test calling a non-existent service"""
    response = client.post("/call/nonexistent-service", json={})
    assert response.status_code == 404
    data = response.json()
    assert "not found" in data["detail"]

def test_rate_limiting():
    """Test rate limiting (simplified test)"""
    # This is a basic test - in production you'd want more sophisticated testing
    responses = []
    for _ in range(5):  # Make a few requests
        response = client.get("/health")
        responses.append(response.status_code)
    
    # All should succeed (rate limit is 100 per minute)
    assert all(status == 200 for status in responses)