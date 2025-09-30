# Python FastAPI ECS Microservice

This microservice is a simple web API implemented with FastAPI, containerized for deployment to AWS ECS Fargate. It serves as an example service in a microservices architecture interconnected with AWS PrivateLink using Terraform and AWS CDK.

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

Example:

```json
{
  "message": "Hello from ECS Python microservice!"
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

## Notes

- This microservice is designed to be simple and extensible. Additional routes, dependencies, and features can be added under the `app/` directory.
- The service listens on port 8000 by default; make sure to expose this port in the ECS task definition.
- The Dockerfile uses `python:3.11-alpine` base image for a small image footprint.

---

## References

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Uvicorn ASGI Server](https://www.uvicorn.org/)
- [AWS ECS Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html)

---

## License

MIT License
