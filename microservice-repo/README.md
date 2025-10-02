# Multi-Account Microservice

A production-ready microservice designed for deployment in multi-account AWS environments using ECS, PrivateLink, and cross-account communication.

## Overview

This microservice provides:
- **Health Check Endpoints** for load balancer health checks
- **API Endpoints** for service-to-service communication
- **Cross-Account Communication** via AWS PrivateLink
- **Observability** with structured logging and metrics
- **Security** with proper authentication and authorization

## Features

- **FastAPI Framework** - Modern, fast web framework for building APIs
- **Health Checks** - `/health` and `/ready` endpoints for load balancer health checks
- **Service Discovery** - Automatic discovery of other microservices via environment variables
- **Structured Logging** - JSON-formatted logs for CloudWatch integration
- **Metrics Collection** - Prometheus-compatible metrics endpoint
- **CORS Support** - Cross-origin resource sharing for web applications
- **Rate Limiting** - Built-in rate limiting for API protection

## API Endpoints

### Health and Status
- `GET /health` - Basic health check
- `GET /ready` - Readiness check (includes dependencies)
- `GET /metrics` - Prometheus metrics endpoint

### Service Communication
- `GET /` - Welcome message and service information
- `GET /services` - List of discovered services
- `POST /call/{service_name}` - Call another microservice
- `GET /status` - Service status and configuration

### Example Responses

#### Health Check
```json
{
  "status": "healthy",
  "service": "microservice",
  "version": "1.0.0",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

#### Service Discovery
```json
{
  "services": [
    {
      "name": "user-service",
      "endpoint": "vpce-12345678-abcdefgh.vpce-svc-12345678.us-east-1.vpce.amazonaws.com",
      "port": 8080,
      "status": "available"
    }
  ]
}
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SERVICE_NAME` | Name of the microservice | `microservice` |
| `SERVICE_PORT` | Port to listen on | `8000` |
| `SERVICE_VERSION` | Version of the service | `1.0.0` |
| `LOG_LEVEL` | Logging level | `INFO` |
| `CONSUMER_SERVICES` | JSON array of consumer services | `[]` |
| `ENABLE_METRICS` | Enable metrics endpoint | `true` |
| `RATE_LIMIT` | Requests per minute | `100` |

### Consumer Services Configuration

The `CONSUMER_SERVICES` environment variable should contain a JSON array of services this microservice can consume:

```json
[
  {
    "name": "user-service",
    "endpoint": "vpce-12345678-abcdefgh.vpce-svc-12345678.us-east-1.vpce.amazonaws.com",
    "port": 8080,
    "timeout": 30
  },
  {
    "name": "notification-service",
    "endpoint": "vpce-87654321-fedcba98.vpce-svc-87654321.us-east-1.vpce.amazonaws.com",
    "port": 8081,
    "timeout": 30
  }
]
```

## Development

### Prerequisites
- Python 3.11+
- Docker
- (Optional) Virtual environment tool such as `venv` or `virtualenv`

### Local Development

1. **Install dependencies**:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **Run locally**:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

3. **Test the service**:
   ```bash
   curl http://localhost:8000/health
   curl http://localhost:8000/
   ```

### Docker Development

1. **Build the image**:
   ```bash
   docker build -t microservice:latest .
   ```

2. **Run the container**:
   ```bash
   docker run -p 8000:8000 \
     -e SERVICE_NAME=test-service \
     -e CONSUMER_SERVICES='[{"name":"user-service","endpoint":"localhost","port":8080}]' \
     microservice:latest
   ```

### Testing

Run the test suite:
```bash
pytest
```

Run with coverage:
```bash
pytest --cov=app --cov-report=html
```

## Production Deployment

### ECS Task Definition

The microservice is designed to run in AWS ECS with the following configuration:

```json
{
  "family": "microservice",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "microservice",
      "image": "your-registry/microservice:latest",
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "SERVICE_NAME",
          "value": "microservice"
        },
        {
          "name": "SERVICE_PORT",
          "value": "8000"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/microservice",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### Health Checks

The service provides health check endpoints for load balancer health checks:

- **Health Check**: `GET /health` - Returns 200 if service is healthy
- **Readiness Check**: `GET /ready` - Returns 200 if service is ready to accept traffic

### Monitoring

The service includes built-in monitoring capabilities:

- **Structured Logging**: JSON-formatted logs for CloudWatch
- **Metrics**: Prometheus-compatible metrics at `/metrics`
- **Health Checks**: Multiple health check endpoints
- **Service Discovery**: Automatic discovery of other services

## Security

### Authentication
- JWT token validation for API endpoints
- Service-to-service authentication via AWS IAM roles
- Rate limiting to prevent abuse

### Network Security
- Runs in private subnets without direct internet access
- Communication via AWS PrivateLink for cross-account services
- Security groups for traffic control

### Secrets Management
- AWS Secrets Manager integration for sensitive configuration
- Environment variable injection for secrets
- No hardcoded credentials

## Observability

### Logging
- Structured JSON logging
- Request/response logging
- Error tracking and reporting
- Correlation IDs for request tracing

### Metrics
- Request count and duration
- Error rates and types
- Service discovery status
- Health check status

### Tracing
- AWS X-Ray integration
- Distributed tracing across services
- Performance monitoring

## Cross-Account Communication

This microservice is designed to work in a multi-account environment:

1. **Provider Mode**: Exposes services via VPC Endpoint Services
2. **Consumer Mode**: Consumes services via Interface VPC Endpoints
3. **Service Discovery**: Automatic discovery of available services
4. **Load Balancing**: Built-in load balancing for service calls

## License

MIT License

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## Support

For issues and questions:
- Create an issue in the repository
- Check the documentation
- Review the troubleshooting guide