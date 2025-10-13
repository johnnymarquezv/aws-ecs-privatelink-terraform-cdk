import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as logs from 'aws-cdk-lib/aws-logs';
import { Construct } from 'constructs';

// Hardcoded configuration constants
const CONFIG = {
  // Account configuration
  CONSUMER_ACCOUNT_ID: '333333333333',
  PROVIDER_ACCOUNT_ID: '222222222222',
  REGION: 'us-east-1',
  
  // Service configuration
  API_CONSUMER: {
    name: 'api-consumer',
    port: 80,
    image: 'nginx:alpine',
    description: 'API Consumer Service'
  },
  USER_CONSUMER: {
    name: 'user-consumer',
    port: 80,
    image: 'nginx:alpine',
    description: 'User Consumer Service'
  },
  
  // Environment-specific configuration
  ENVIRONMENTS: {
    dev: {
      memoryLimitMiB: 512,
      cpu: 256,
      desiredCount: 1,
      minCapacity: 1,
      maxCapacity: 3
    },
    staging: {
      memoryLimitMiB: 1024,
      cpu: 512,
      desiredCount: 2,
      minCapacity: 2,
      maxCapacity: 5
    },
    prod: {
      memoryLimitMiB: 2048,
      cpu: 1024,
      desiredCount: 3,
      minCapacity: 3,
      maxCapacity: 10
    }
  },
  
  // VPC Endpoint Service IDs (hardcoded for each environment)
  VPC_ENDPOINT_SERVICES: {
    dev: {
      'api-service': 'vpce-svc-1234567890abcdef0',
      'user-service': 'vpce-svc-0987654321fedcba0'
    },
    staging: {
      'api-service': 'vpce-svc-staging-api-abcdef0',
      'user-service': 'vpce-svc-staging-user-fedcba0'
    },
    prod: {
      'api-service': 'vpce-svc-prod-api-abcdef0',
      'user-service': 'vpce-svc-prod-user-fedcba0'
    }
  }
} as const;

export interface ConsumerStackProps extends cdk.StackProps {
  environment: 'dev' | 'staging' | 'prod';
  serviceType: 'api-consumer' | 'user-consumer';
}

export class ConsumerStack extends cdk.Stack {
  public readonly vpc: ec2.IVpc;
  public readonly cluster: ecs.Cluster;
  public readonly consumerEndpoints: ec2.VpcEndpoint[] = [];

  constructor(scope: Construct, id: string, props: ConsumerStackProps) {
    super(scope, id, props);

    const { environment, serviceType } = props;
    // Get service configuration based on service type
    const serviceConfig = serviceType === 'api-consumer' ? CONFIG.API_CONSUMER : CONFIG.USER_CONSUMER;
    const envConfig = CONFIG.ENVIRONMENTS[environment];

    // For now, use hardcoded values for synthesis
    // In production, these would come from SSM Parameter Store populated by Terraform
    const vpcId = `vpc-${environment}-${serviceType}`;
    const publicSubnetIds = [`subnet-${environment}-${serviceType}-pub1`, `subnet-${environment}-${serviceType}-pub2`];
    const privateSubnetIds = [`subnet-${environment}-${serviceType}-priv1`, `subnet-${environment}-${serviceType}-priv2`];
    const baseDefaultSecurityGroupId = `sg-${environment}-${serviceType}-default`;
    const basePrivateSecurityGroupId = `sg-${environment}-${serviceType}-private`;
    const ecsTaskExecutionRoleArn = `arn:aws:iam::${CONFIG.CONSUMER_ACCOUNT_ID}:role/${environment}-${serviceType}-ecs-task-execution-role`;
    const ecsTaskRoleArn = `arn:aws:iam::${CONFIG.CONSUMER_ACCOUNT_ID}:role/${environment}-${serviceType}-ecs-task-role`;
    const ecsApplicationLogGroupName = `/${environment}/${serviceType}/ecs-application-logs`;

    // Import VPC from Terraform outputs
    // Using fromVpcAttributes for local testing without AWS credentials
    this.vpc = ec2.Vpc.fromVpcAttributes(this, 'ImportedVpc', {
      vpcId: vpcId,
      availabilityZones: [`${CONFIG.REGION}a`, `${CONFIG.REGION}b`],
      publicSubnetIds: publicSubnetIds,
      privateSubnetIds: privateSubnetIds,
    });

    // Create ECS Cluster for consumer microservice
    this.cluster = new ecs.Cluster(this, 'ConsumerCluster', {
      vpc: this.vpc,
      clusterName: `${serviceConfig.name}-${environment}-cluster`,
      containerInsights: true,
    });

    // Import CloudWatch Log Group from Terraform
    const logGroup = logs.LogGroup.fromLogGroupName(this, 'ImportedLogGroup', ecsApplicationLogGroupName);

    // Import IAM roles from Terraform
    const taskExecutionRole = iam.Role.fromRoleArn(this, 'TaskExecutionRole', ecsTaskExecutionRoleArn);
    const taskRole = iam.Role.fromRoleArn(this, 'TaskRole', ecsTaskRoleArn);

    // Create application-specific security group
    const appSecurityGroup = new ec2.SecurityGroup(this, 'AppSecurityGroup', {
      vpc: this.vpc,
      description: `Security group for ${serviceConfig.name} in ${environment}`,
      allowAllOutbound: true,
    });

    // Import base security groups from Terraform
    const baseDefaultSecurityGroup = ec2.SecurityGroup.fromSecurityGroupId(
      this,
      'BaseDefaultSecurityGroup',
      baseDefaultSecurityGroupId
    );
    const basePrivateSecurityGroup = ec2.SecurityGroup.fromSecurityGroupId(
      this,
      'BasePrivateSecurityGroup',
      basePrivateSecurityGroupId
    );

    // Allow traffic from base security groups
    appSecurityGroup.addIngressRule(
      baseDefaultSecurityGroup,
      ec2.Port.tcp(serviceConfig.port),
      'Allow traffic from base default security group'
    );
    appSecurityGroup.addIngressRule(
      basePrivateSecurityGroup,
      ec2.Port.tcp(serviceConfig.port),
      'Allow traffic from base private security group'
    );

    // Create task definition
    const taskDefinition = new ecs.FargateTaskDefinition(this, 'TaskDefinition', {
      memoryLimitMiB: envConfig.memoryLimitMiB,
      cpu: envConfig.cpu,
      executionRole: taskExecutionRole,
      taskRole: taskRole,
    });

    // Add container to task definition
    const container = taskDefinition.addContainer('Container', {
      image: ecs.ContainerImage.fromRegistry(serviceConfig.image),
      logging: ecs.LogDrivers.awsLogs({
        streamPrefix: serviceConfig.name,
        logGroup: logGroup,
      }),
      environment: {
        SERVICE_NAME: serviceConfig.name,
        ENVIRONMENT: environment,
        PORT: serviceConfig.port.toString(),
        SERVICE_DESCRIPTION: serviceConfig.description,
      },
    });

    container.addPortMappings({
      containerPort: serviceConfig.port,
      protocol: ecs.Protocol.TCP,
    });

    // Create ECS service
    const service = new ecs.FargateService(this, 'Service', {
      cluster: this.cluster,
      taskDefinition: taskDefinition,
      desiredCount: envConfig.desiredCount,
      securityGroups: [appSecurityGroup],
      assignPublicIp: false,
      vpcSubnets: {
        subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
      },
    });

    // Create Interface VPC Endpoints for consuming external services
    const endpointServices = CONFIG.VPC_ENDPOINT_SERVICES[environment];
    
    // TODO: VPC endpoint creation commented out for now due to CDK API issues
    // Create endpoint for API service
    // if (serviceType === 'api-consumer' && endpointServices['api-service']) {
    //   const apiEndpoint = new ec2.VpcEndpoint(this, 'ApiServiceEndpoint', {
    //     vpc: this.vpc,
    //     service: endpointServices['api-service'],
    //     vpcSubnets: {
    //       subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
    //     },
    //     securityGroups: [appSecurityGroup],
    //   });
    //   this.consumerEndpoints.push(apiEndpoint);
    // }

    // Create endpoint for User service
    // if (serviceType === 'user-consumer' && endpointServices['user-service']) {
    //   const userEndpoint = new ec2.VpcEndpoint(this, 'UserServiceEndpoint', {
    //     vpc: this.vpc,
    //     service: endpointServices['user-service'],
    //     vpcSubnets: {
    //       subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
    //     },
    //     securityGroups: [appSecurityGroup],
    //   });
    //   this.consumerEndpoints.push(userEndpoint);
    // }

    // Add environment-specific tags
    cdk.Tags.of(this).add('Environment', environment);
    cdk.Tags.of(this).add('Service', serviceConfig.name);
    cdk.Tags.of(this).add('ServiceType', 'Consumer');
    cdk.Tags.of(this).add('ManagedBy', 'CDK');
  }
}
