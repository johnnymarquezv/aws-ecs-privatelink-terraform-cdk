# Security Account

This Terraform configuration creates the centralized security services for the multi-account organization.

## Quick Start

1. Deploy using the deployment script:
   ```bash
   ./scripts/deploy-security-account.sh dev us-east-1 888888888888 123456789012:111111111111:999999999999:222222222222,333333333333:444444444444,555555555555
   ```

## What This Deploys

- **Organization-wide CloudTrail** - Centralized audit logging
- **AWS Config** - Configuration compliance monitoring
- **GuardDuty** - Threat detection and monitoring
- **Security Hub** - Centralized security findings
- **Inspector V2** - Vulnerability assessments for ECR and EC2
- **CloudWatch Monitoring** - Security event monitoring and alerting
- **Cross-Account IAM Roles** - Security audit access across accounts
- **SNS Notifications** - Security alert notifications

## Configuration

See the main [README.md](../README.md) for comprehensive configuration details and deployment options.

## Outputs

- `security_audit_role_arn` - Cross-account security audit role
- `security_alerts_topic_arn` - SNS topic for security alerts
- `cloudtrail_arn` - Organization CloudTrail ARN
- `guardduty_detector_id` - GuardDuty detector ID
- `security_hub_arn` - Security Hub ARN

## License

MIT License
