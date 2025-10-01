# Local Microservice for VPC Endpoint Testing

This microservice is a simple web API implemented with FastAPI, designed for **local deployment and testing** of VPC endpoint connectivity. It serves as a test client to verify PrivateLink connections to CDK-deployed microservices.

**Note**: This microservice is deployed locally for testing purposes. The CDK stack deploys a separate, publicly available microservice (nginx) for infrastructure testing.

---

## Project Structure

microservice/
├── Dockerfile # Container image build instructions
├── requirements.txt # Python dependencies
├── app/
│ ├── main.py # FastAPI app entry point
│ └── routers/
│ └── hello.py # Example API route
├── tests/
│ └── test_main.py # Basic API tests
├── .dockerignore # Files excluded from Docker context
└── README.md # This file

---

## Getting Started

### Prerequisites

- Python 3.11+
- Docker
- (Optional) Virtual environment tool such as `venv` or `virtualenv`

### Install dependencies locally

```bash
python -m venv venv
source venv/bin/activate # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### Run locally (development mode)

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Visit [http://localhost:8000](http://localhost:8000) to test the service.

---

## API Endpoints

- `GET /`  
  Returns a welcome message.

- `GET /hello`  
  Returns a simple greeting message from the microservice.

- `GET /health`  
  **Health check endpoint** for load balancer health checks and connectivity testing.

Example:

```json
{
  "message": "Hello from ECS Python microservice!"
}
```

Health check response:
```json
{
  "status": "healthy",
  "service": "microservice"
}
```

---

## Running with Docker

Build the Docker image:

```bash
docker build -t ecs-python-microservice .
```

Run the container locally:

```bash
docker run -p 8000:8000 ecs-python-microservice
```

---

## Running Tests

Run tests with `pytest`:

```bash
pytest
```

---

## Testing VPC Endpoint Connectivity

This local microservice can be used to test connectivity to CDK-deployed microservices via VPC endpoints:

### 1. Deploy CDK Stack First
Ensure the CDK stack is deployed and note the VPC Endpoint Service DNS name.

### 2. Run Local Microservice
```bash
# Start the local microservice
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 3. Test Connectivity
From within the VPC (using an EC2 instance or VPN connection), test connectivity to the CDK-deployed microservice:

```bash
# Test health endpoint
curl http://<vpc-endpoint-dns-name>/health

# Test basic connectivity
curl http://<vpc-endpoint-dns-name>/

# Test from local microservice (if running in same VPC)
curl http://<vpc-endpoint-dns-name>/hello
```

### 4. Verify PrivateLink Connection
- Ensure traffic flows through VPC endpoints (not internet)
- Check CloudWatch logs for connection attempts
- Verify security group rules allow the traffic

## Notes

- This microservice is designed for **local testing** of VPC endpoint connectivity.
- The service listens on port 8000 by default.
- The Dockerfile uses `python:3.11-alpine` base image for a small image footprint.
- For production ECS deployment, use the CDK stack which deploys nginx for infrastructure testing.

---

## References

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Uvicorn ASGI Server](https://www.uvicorn.org/)
- [AWS ECS Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html)

---

## License

MIT License
