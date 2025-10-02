# Shared Services Account

This Terraform configuration creates the CI/CD, monitoring, and shared services infrastructure for the multi-account organization.

## Quick Start

1. Deploy using the deployment script:
   ```bash
   ./scripts/deploy-shared-services-account.sh dev us-east-1 999999999999 123456789012:888888888888:111111111111:222222222222,333333333333:444444444444,555555555555 https://github.com/your-org/microservice
   ```

## What This Deploys

- **ECR Repository** - Container registry for microservice images
- **CodeBuild Project** - CI/CD build pipeline
- **S3 Artifacts Bucket** - Build artifacts storage
- **Amazon Managed Prometheus** - Metrics collection and monitoring
- **CloudWatch Dashboards** - Operational visibility
- **X-Ray Tracing** - Distributed tracing (optional)
- **Cross-Account IAM Roles** - Monitoring access across accounts
- **SNS Notifications** - Deployment notifications

## Configuration

See the main [README.md](../README.md) for comprehensive configuration details and deployment options.

## Outputs

- `ecr_repository_url` - Container registry URL
- `codebuild_project_name` - CI/CD build project name
- `monitoring_role_arn` - Cross-account monitoring role
- `prometheus_workspace_id` - Prometheus workspace ID
- `prometheus_endpoint` - Prometheus endpoint URL
- `artifacts_s3_bucket` - Build artifacts bucket name

## License

MIT License
