# Microservice Deployment Example

This document shows how to deploy the microservice in a multi-account environment using the provided CDK stacks.

## Prerequisites

1. **Container Registry**: Build and push the microservice to a container registry
2. **Terraform Infrastructure**: Deploy the base networking infrastructure
3. **AWS CDK**: Bootstrap CDK in your target accounts

## Step 1: Build and Push Microservice

### Using GitHub Container Registry

```bash
# Build and push to GitHub Container Registry
./scripts/build-microservice.sh ghcr.io your-org/microservice latest 1.0.0
```

### Using AWS ECR

```bash
# Create ECR repository
aws ecr create-repository --repository-name microservice --region us-east-1

# Build and push to ECR
./scripts/build-microservice.sh 123456789012.dkr.ecr.us-east-1.amazonaws.com microservice latest 1.0.0
```

## Step 2: Deploy Provider Account

Deploy a microservice that provides services to other accounts:

```bash
# Deploy provider with custom image
./scripts/deploy-provider-account.sh dev us-east-1 222222222222 user-service 8080 ghcr.io/your-org/microservice:latest
```

This will:
- Deploy an ECS Fargate service running the microservice
- Create a Network Load Balancer
- Expose the service via VPC Endpoint Service
- Configure cross-account access

## Step 3: Deploy Consumer Account

Deploy a microservice that consumes services from other accounts:

```bash
# Deploy consumer with service discovery
./scripts/deploy-consumer-account.sh dev us-east-1 444444444444 api-gateway 8000 ghcr.io/your-org/microservice:latest
```

## Step 4: Configure Service Discovery

The microservice automatically discovers other services via the `CONSUMER_SERVICES` environment variable. This is configured in the CDK stacks:

### Provider Configuration

```typescript
environment: {
  SERVICE_NAME: props.microserviceName,
  SERVICE_PORT: props.microservicePort.toString(),
  SERVICE_VERSION: '1.0.0',
  LOG_LEVEL: 'INFO',
  ENABLE_METRICS: 'true',
  RATE_LIMIT: '100',
  CONSUMER_SERVICES: JSON.stringify(props.consumerEndpointServices || []),
}
```

### Consumer Configuration

```typescript
environment: {
  SERVICE_NAME: `${props.microserviceName}-consumer`,
  SERVICE_PORT: props.microservicePort.toString(),
  SERVICE_VERSION: '1.0.0',
  LOG_LEVEL: 'INFO',
  ENABLE_METRICS: 'true',
  RATE_LIMIT: '100',
  CONSUMER_SERVICES: JSON.stringify(props.consumerEndpointServices.map(s => ({
    name: s.serviceName,
    endpoint: `vpce-${s.vpcEndpointServiceId.split('-').pop()}-${s.vpcEndpointServiceId.split('-')[1]}.vpce-svc-${s.vpcEndpointServiceId}.us-east-1.vpce.amazonaws.com`,
    port: s.port,
    timeout: 30
  }))),
}
```

## Step 5: Test Cross-Account Communication

### Test Provider Service

```bash
# Get VPC Endpoint Service DNS name
VPC_ENDPOINT_DNS=$(aws ec2 describe-vpc-endpoint-services --service-names com.amazonaws.vpce.us-east-1.vpce-svc-12345678 --query 'ServiceDetails[0].ServiceName' --output text)

# Test health endpoint
curl http://$VPC_ENDPOINT_DNS/health

# Test service status
curl http://$VPC_ENDPOINT_DNS/status
```

### Test Consumer Service

```bash
# Test service discovery
curl http://consumer-service-endpoint/services

# Test calling another service
curl -X POST http://consumer-service-endpoint/call/user-service \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

## Environment Variables

The microservice supports the following environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `SERVICE_NAME` | Name of the microservice | `microservice` |
| `SERVICE_PORT` | Port to listen on | `8000` |
| `SERVICE_VERSION` | Version of the service | `1.0.0` |
| `LOG_LEVEL` | Logging level | `INFO` |
| `CONSUMER_SERVICES` | JSON array of consumer services | `[]` |
| `ENABLE_METRICS` | Enable metrics endpoint | `true` |
| `RATE_LIMIT` | Requests per minute | `100` |

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

## Monitoring

### CloudWatch Logs

The microservice automatically logs to CloudWatch with structured JSON format:

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "level": "INFO",
  "message": "GET /health 200 0.003s",
  "service": "microservice",
  "method": "GET",
  "path": "/health",
  "status_code": 200,
  "process_time": 0.003,
  "client_ip": "10.0.1.100"
}
```

### Metrics

The microservice exposes Prometheus-compatible metrics at `/metrics`:

```
# HELP microservice_requests_total Total number of requests
# TYPE microservice_requests_total counter
microservice_requests_total 42

# HELP microservice_uptime_seconds Service uptime in seconds
# TYPE microservice_uptime_seconds gauge
microservice_uptime_seconds 3600

# HELP microservice_consumer_services Number of consumer services
# TYPE microservice_consumer_services gauge
microservice_consumer_services 2
```

## Security

### Network Security
- Runs in private subnets without direct internet access
- Communication via AWS PrivateLink for cross-account services
- Security groups for traffic control

### Authentication
- JWT token validation for API endpoints
- Service-to-service authentication via AWS IAM roles
- Rate limiting to prevent abuse

### Secrets Management
- AWS Secrets Manager integration for sensitive configuration
- Environment variable injection for secrets
- No hardcoded credentials

## Troubleshooting

### Common Issues

1. **Service Discovery Not Working**
   - Check `CONSUMER_SERVICES` environment variable
   - Verify VPC Endpoint Service IDs are correct
   - Ensure cross-account access is configured

2. **Health Checks Failing**
   - Check ECS task logs in CloudWatch
   - Verify port mappings are correct
   - Ensure security groups allow traffic

3. **Cross-Account Communication Issues**
   - Verify VPC Endpoint Service policies
   - Check IAM roles and permissions
   - Ensure VPC endpoints are in the same VPC

### Debugging Commands

```bash
# Check ECS service status
aws ecs describe-services --cluster microservice-cluster --services microservice-service

# Check VPC endpoint services
aws ec2 describe-vpc-endpoint-services --service-names com.amazonaws.vpce.us-east-1.vpce-svc-12345678

# Check CloudWatch logs
aws logs tail /ecs/microservice --follow

# Test connectivity
curl -v http://vpc-endpoint-dns-name/health
```

## Customization

### Adding New Endpoints

Add new API endpoints in `app/main.py`:

```python
@app.get("/custom-endpoint")
async def custom_endpoint():
    return {"message": "Custom endpoint", "service": SERVICE_NAME}
```

### Adding Service Dependencies

Configure service dependencies in the CDK stack:

```typescript
environment: {
  CONSUMER_SERVICES: JSON.stringify([
    {
      name: "user-service",
      endpoint: "vpce-12345678-abcdefgh.vpce-svc-12345678.us-east-1.vpce.amazonaws.com",
      port: 8080,
      timeout: 30
    }
  ])
}
```

### Custom Health Checks

Implement custom health checks:

```python
@app.get("/custom-health")
async def custom_health():
    # Add custom health check logic
    return {"status": "healthy", "custom_check": "passed"}
```

This microservice provides a solid foundation for building multi-account microservices with proper service discovery, monitoring, and security.
