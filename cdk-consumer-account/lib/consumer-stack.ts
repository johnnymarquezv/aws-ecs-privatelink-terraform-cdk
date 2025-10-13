import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as logs from 'aws-cdk-lib/aws-logs';
import { Construct } from 'constructs';
import { TransitGatewayConnectivity } from './transit-gateway-connectivity';
import { SsmParameterStore } from './ssm-parameter-store';

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
      maxCapacity: 3,
      vpcCidr: '10.11.0.0/16',
      publicSubnetCidrs: ['10.11.1.0/24', '10.11.2.0/24'],
      privateSubnetCidrs: ['10.11.3.0/24', '10.11.4.0/24'],
      logRetentionDays: 7
    },
    staging: {
      memoryLimitMiB: 1024,
      cpu: 512,
      desiredCount: 2,
      minCapacity: 2,
      maxCapacity: 5,
      vpcCidr: '10.12.0.0/16',
      publicSubnetCidrs: ['10.12.1.0/24', '10.12.2.0/24'],
      privateSubnetCidrs: ['10.12.3.0/24', '10.12.4.0/24'],
      logRetentionDays: 30
    },
    prod: {
      memoryLimitMiB: 2048,
      cpu: 1024,
      desiredCount: 3,
      minCapacity: 3,
      maxCapacity: 10,
      vpcCidr: '10.13.0.0/16',
      publicSubnetCidrs: ['10.13.1.0/24', '10.13.2.0/24'],
      privateSubnetCidrs: ['10.13.3.0/24', '10.13.4.0/24'],
      logRetentionDays: 90
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
  public readonly vpc: ec2.Vpc;
  public readonly cluster: ecs.Cluster;
  public readonly consumerEndpoints: ec2.VpcEndpoint[] = [];
  public readonly transitGatewayConnectivity: TransitGatewayConnectivity;

  constructor(scope: Construct, id: string, props: ConsumerStackProps) {
    super(scope, id, props);

    const { environment, serviceType } = props;
    // Get service configuration based on service type
    const serviceConfig = serviceType === 'api-consumer' ? CONFIG.API_CONSUMER : CONFIG.USER_CONSUMER;
    const envConfig = CONFIG.ENVIRONMENTS[environment];

    // Create VPC with all networking infrastructure
    this.vpc = new ec2.Vpc(this, 'ConsumerVpc', {
      vpcName: `${serviceConfig.name}-${environment}-vpc`,
      cidr: envConfig.vpcCidr,
      maxAzs: 2,
      enableDnsHostnames: true,
      enableDnsSupport: true,
      subnetConfiguration: [
        {
          cidrMask: 24,
          name: 'Public',
          subnetType: ec2.SubnetType.PUBLIC,
        },
        {
          cidrMask: 24,
          name: 'Private',
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
        },
      ],
      natGateways: 2, // High availability NAT gateways
    });

    // Create security groups
    const vpcEndpointsSecurityGroup = new ec2.SecurityGroup(this, 'VpcEndpointsSecurityGroup', {
      vpc: this.vpc,
      description: 'Security group for VPC endpoints',
      allowAllOutbound: true,
    });

    vpcEndpointsSecurityGroup.addIngressRule(
      ec2.Peer.ipv4(this.vpc.vpcCidrBlock),
      ec2.Port.tcp(443),
      'HTTPS from VPC'
    );

    // Create VPC endpoints for AWS services
    const s3Endpoint = new ec2.GatewayVpcEndpoint(this, 'S3Endpoint', {
      vpc: this.vpc,
      service: ec2.GatewayVpcEndpointAwsService.S3,
    });

    const dynamodbEndpoint = new ec2.GatewayVpcEndpoint(this, 'DynamoDBEndpoint', {
      vpc: this.vpc,
      service: ec2.GatewayVpcEndpointAwsService.DYNAMODB,
    });

    const ecrDkrEndpoint = new ec2.InterfaceVpcEndpoint(this, 'EcrDkrEndpoint', {
      vpc: this.vpc,
      service: ec2.InterfaceVpcEndpointAwsService.ECR_DOCKER,
      securityGroups: [vpcEndpointsSecurityGroup],
      privateDnsEnabled: true,
    });

    const ecrApiEndpoint = new ec2.InterfaceVpcEndpoint(this, 'EcrApiEndpoint', {
      vpc: this.vpc,
      service: ec2.InterfaceVpcEndpointAwsService.ECR,
      securityGroups: [vpcEndpointsSecurityGroup],
      privateDnsEnabled: true,
    });

    const cloudWatchLogsEndpoint = new ec2.InterfaceVpcEndpoint(this, 'CloudWatchLogsEndpoint', {
      vpc: this.vpc,
      service: ec2.InterfaceVpcEndpointAwsService.CLOUDWATCH_LOGS,
      securityGroups: [vpcEndpointsSecurityGroup],
      privateDnsEnabled: true,
    });

    // Create IAM roles
    const taskExecutionRole = new iam.Role(this, 'TaskExecutionRole', {
      assumedBy: new iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AmazonECSTaskExecutionRolePolicy'),
      ],
    });

    const taskRole = new iam.Role(this, 'TaskRole', {
      assumedBy: new iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
    });

    // Create CloudWatch Log Group
    const logGroup = new logs.LogGroup(this, 'ApplicationLogGroup', {
      logGroupName: `/${environment}/${serviceConfig.name}/ecs-application-logs`,
      retention: logs.RetentionDays[envConfig.logRetentionDays === 7 ? 'ONE_WEEK' : 
                                   envConfig.logRetentionDays === 30 ? 'ONE_MONTH' : 'THREE_MONTHS'],
    });

    // Create ECS Cluster for consumer microservice
    this.cluster = new ecs.Cluster(this, 'ConsumerCluster', {
      vpc: this.vpc,
      clusterName: `${serviceConfig.name}-${environment}-cluster`,
      containerInsights: true,
    });

    // Create application-specific security group
    const appSecurityGroup = new ec2.SecurityGroup(this, 'AppSecurityGroup', {
      vpc: this.vpc,
      description: `Security group for ${serviceConfig.name} in ${environment}`,
      allowAllOutbound: true,
    });

    // Allow traffic from VPC CIDR to application port
    appSecurityGroup.addIngressRule(
      ec2.Peer.ipv4(this.vpc.vpcCidrBlock),
      ec2.Port.tcp(serviceConfig.port),
      'Allow traffic from VPC'
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
    
    // Create endpoint for API service
    if (serviceType === 'api-consumer' && endpointServices['api-service']) {
      const apiEndpoint = new ec2.InterfaceVpcEndpoint(this, 'ApiServiceEndpoint', {
        vpc: this.vpc,
        service: new ec2.InterfaceVpcEndpointService(endpointServices['api-service']),
        subnets: {
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
        },
        securityGroups: [appSecurityGroup],
      });
      this.consumerEndpoints.push(apiEndpoint);
    }

    // Create endpoint for User service
    if (serviceType === 'user-consumer' && endpointServices['user-service']) {
      const userEndpoint = new ec2.InterfaceVpcEndpoint(this, 'UserServiceEndpoint', {
        vpc: this.vpc,
        service: new ec2.InterfaceVpcEndpointService(endpointServices['user-service']),
        subnets: {
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
        },
        securityGroups: [appSecurityGroup],
      });
      this.consumerEndpoints.push(userEndpoint);
    }

    // Output VPC ID for cross-account connectivity
    new cdk.CfnOutput(this, 'VpcId', {
      value: this.vpc.vpcId,
      description: 'VPC ID for cross-account peering',
      exportName: `${serviceConfig.name}-${environment}-vpc-id`,
    });

    // Output VPC CIDR for cross-account connectivity
    new cdk.CfnOutput(this, 'VpcCidr', {
      value: this.vpc.vpcCidrBlock,
      description: 'VPC CIDR block for cross-account peering',
      exportName: `${serviceConfig.name}-${environment}-vpc-cidr`,
    });

    // Create Transit Gateway connectivity
    const ssmParams = new SsmParameterStore(this, 'SsmParameters', {
      environment: environment
    });

    this.transitGatewayConnectivity = new TransitGatewayConnectivity(this, 'TransitGatewayConnectivity', {
      vpc: this.vpc,
      transitGatewayId: ssmParams.transitGatewayId,
      transitGatewayRouteTableId: ssmParams.transitGatewayRouteTableId,
      environment: environment,
      accountType: 'consumer',
      serviceName: serviceConfig.name
    });

    // Add environment-specific tags
    cdk.Tags.of(this).add('Environment', environment);
    cdk.Tags.of(this).add('Service', serviceConfig.name);
    cdk.Tags.of(this).add('ServiceType', 'Consumer');
    cdk.Tags.of(this).add('ManagedBy', 'CDK');
    cdk.Tags.of(this).add('Account', 'Consumer');
  }
}