import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as logs from 'aws-cdk-lib/aws-logs';
import { Construct } from 'constructs';
import { SsmParameterStore } from './ssm-parameter-store';

// Hardcoded configuration constants
const CONFIG = {
  // Account configuration
  PROVIDER_ACCOUNT_ID: '222222222222',
  NETWORKING_ACCOUNT_ID: '111111111111',
  REGION: 'us-east-1',
  
  // Service configuration
  API_SERVICE: {
    name: 'api-service',
    port: 8080,
    image: 'nginx:alpine',
    description: 'API Service Provider'
  },
  USER_SERVICE: {
    name: 'user-service',
    port: 3000,
    image: 'nginx:alpine',
    description: 'User Service Provider'
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
  }
} as const;

export interface ProviderStackProps extends cdk.StackProps {
  environment: 'dev' | 'staging' | 'prod';
  serviceType: 'api-service' | 'user-service';
}

export class ProviderStack extends cdk.Stack {
  public readonly vpc: ec2.IVpc;
  public readonly cluster: ecs.Cluster;
  public readonly nlb: elbv2.NetworkLoadBalancer;
  public readonly vpcEndpointService: ec2.VpcEndpointService;

  constructor(scope: Construct, id: string, props: ProviderStackProps) {
    super(scope, id, props);

    const { environment, serviceType } = props;
    // Get service configuration based on service type
    const serviceConfig = serviceType === 'api-service' ? CONFIG.API_SERVICE : CONFIG.USER_SERVICE;
    const envConfig = CONFIG.ENVIRONMENTS[environment];

    // For now, use hardcoded values for synthesis
    // In production, these would come from SSM Parameter Store populated by Terraform
    const vpcId = `vpc-${environment}-${serviceType}`;
    const publicSubnetIds = [`subnet-${environment}-${serviceType}-pub1`, `subnet-${environment}-${serviceType}-pub2`];
    const privateSubnetIds = [`subnet-${environment}-${serviceType}-priv1`, `subnet-${environment}-${serviceType}-priv2`];
    const baseDefaultSecurityGroupId = `sg-${environment}-${serviceType}-default`;
    const basePrivateSecurityGroupId = `sg-${environment}-${serviceType}-private`;
    const ecsTaskExecutionRoleArn = `arn:aws:iam::${CONFIG.PROVIDER_ACCOUNT_ID}:role/${environment}-${serviceType}-ecs-task-execution-role`;
    const ecsTaskRoleArn = `arn:aws:iam::${CONFIG.PROVIDER_ACCOUNT_ID}:role/${environment}-${serviceType}-ecs-task-role`;
    const ecsApplicationLogGroupName = `/${environment}/${serviceType}/ecs-application-logs`;

    // Import VPC from Terraform outputs
    // Using fromVpcAttributes for local testing without AWS credentials
    this.vpc = ec2.Vpc.fromVpcAttributes(this, 'ImportedVpc', {
      vpcId: vpcId,
      availabilityZones: [`${CONFIG.REGION}a`, `${CONFIG.REGION}b`],
      publicSubnetIds: publicSubnetIds,
      privateSubnetIds: privateSubnetIds,
    });

    // Create ECS Cluster
    this.cluster = new ecs.Cluster(this, 'ProviderCluster', {
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

    // Create Network Load Balancer
    this.nlb = new elbv2.NetworkLoadBalancer(this, 'NLB', {
      vpc: this.vpc,
      internetFacing: false,
      vpcSubnets: {
        subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
      },
    });

    // Create target group
    const targetGroup = new elbv2.NetworkTargetGroup(this, 'TargetGroup', {
      vpc: this.vpc,
      port: serviceConfig.port,
      protocol: elbv2.Protocol.TCP,
      targetType: elbv2.TargetType.IP,
      healthCheck: {
        enabled: true,
        healthyHttpCodes: '200',
        path: '/health',
        port: serviceConfig.port.toString(),
        protocol: elbv2.Protocol.HTTP,
      },
    });

    // Add listener
    this.nlb.addListener('Listener', {
      port: serviceConfig.port,
      protocol: elbv2.Protocol.TCP,
      defaultTargetGroups: [targetGroup],
    });

    // Attach ECS service to target group
    service.attachToNetworkTargetGroup(targetGroup);

    // Create VPC Endpoint Service
    this.vpcEndpointService = new ec2.VpcEndpointService(this, 'VpcEndpointService', {
      vpcEndpointServiceLoadBalancers: [this.nlb],
      acceptanceRequired: true,
      allowedPrincipals: [
        new iam.ArnPrincipal(`arn:aws:iam::${CONFIG.NETWORKING_ACCOUNT_ID}:root`)
      ],
    });

    // Output VPC Endpoint Service ID for consumer configuration
    new cdk.CfnOutput(this, 'VpcEndpointServiceId', {
      value: this.vpcEndpointService.vpcEndpointServiceId,
      description: 'VPC Endpoint Service ID for cross-account access',
      exportName: `${serviceConfig.name}-${environment}-vpc-endpoint-service-id`,
    });

    // Output NLB DNS name
    new cdk.CfnOutput(this, 'NLBDnsName', {
      value: this.nlb.loadBalancerDnsName,
      description: 'Network Load Balancer DNS name',
      exportName: `${serviceConfig.name}-${environment}-nlb-dns-name`,
    });

    // Add environment-specific tags
    cdk.Tags.of(this).add('Environment', environment);
    cdk.Tags.of(this).add('Service', serviceConfig.name);
    cdk.Tags.of(this).add('ServiceType', 'Provider');
    cdk.Tags.of(this).add('ManagedBy', 'CDK');
  }
}
