import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as logs from 'aws-cdk-lib/aws-logs';
import { Construct } from 'constructs';
import { getServiceConfig, getEnvironmentConfig, getAccountConfig } from './config';
// Database resources will be integrated directly into this stack

export interface ProviderStackProps extends cdk.StackProps {
  environment: 'dev' | 'staging' | 'prod';
  serviceType: 'api-service';
}

export class ProviderStack extends cdk.Stack {
  public readonly vpc: ec2.Vpc;
  public readonly cluster: ecs.Cluster;
  public readonly nlb: elbv2.NetworkLoadBalancer;
  public readonly vpcEndpointService: ec2.VpcEndpointService;
  // Database resources integrated directly

  constructor(scope: Construct, id: string, props: ProviderStackProps) {
    super(scope, id, props);

    const { environment, serviceType } = props;
    // Get service configuration based on service type
    const serviceConfig = getServiceConfig(serviceType);
    const envConfig = getEnvironmentConfig(environment);
    const accountConfig = getAccountConfig(this.node.root as cdk.App, 'consumer');

    // Create VPC with all networking infrastructure
    this.vpc = new ec2.Vpc(this, 'ProviderVpc', {
      vpcName: `${serviceConfig.name}-${environment}-vpc`,
      ipAddresses: ec2.IpAddresses.cidr(envConfig.vpcCidr),
      availabilityZones: [`${accountConfig.region}a`, `${accountConfig.region}b`],
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

    // Add database permissions to task role
    taskRole.addManagedPolicy(
      iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonDynamoDBFullAccess')
    );
    taskRole.addManagedPolicy(
      iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonElastiCacheFullAccess')
    );
    
    // Add RDS permissions
    taskRole.addToPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'rds-db:connect',
        'secretsmanager:GetSecretValue',
      ],
      resources: ['*'],
    }));

    // Add SSM Parameter Store permissions for database configuration
    taskRole.addToPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'ssm:GetParameter',
        'ssm:GetParameters',
        'ssm:GetParametersByPath',
      ],
      resources: [
        `arn:aws:ssm:${this.region}:${this.account}:parameter/${environment}/*`,
      ],
    }));

    // Create CloudWatch Log Group
    const logGroup = new logs.LogGroup(this, 'ApplicationLogGroup', {
      logGroupName: `/${environment}/${serviceConfig.name}/ecs-application-logs`,
      retention: logs.RetentionDays[envConfig.logRetentionDays === 7 ? 'ONE_WEEK' : 
                                   envConfig.logRetentionDays === 30 ? 'ONE_MONTH' : 'THREE_MONTHS'],
    });

    // Create ECS Cluster
    this.cluster = new ecs.Cluster(this, 'ProviderCluster', {
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

    // Use GitHub Container Registry for microservice images
    const containerRegistryUrl = `ghcr.io/johnnymarquezv/aws-ecs-privatelink-terraform-cdk/microservice`;

    // Add container to task definition
    const container = taskDefinition.addContainer('Container', {
      image: ecs.ContainerImage.fromRegistry(`${containerRegistryUrl}:${environment}`),
      logging: ecs.LogDrivers.awsLogs({
        streamPrefix: serviceConfig.name,
        logGroup: logGroup,
      }),
      environment: {
        SERVICE_NAME: serviceConfig.name,
        ENVIRONMENT: environment,
        SERVICE_PORT: serviceConfig.port.toString(),
        SERVICE_VERSION: '1.0.0',
        LOG_LEVEL: 'INFO',
        ENABLE_METRICS: 'true',
        RATE_LIMIT: '100',
        CONSUMER_SERVICES: JSON.stringify([]), // No consumer services for provider
        // Database configuration will be retrieved from SSM Parameter Store at runtime
        SSM_PARAMETER_PREFIX: `/${environment}/${serviceConfig.name}/database`,
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
        new iam.ArnPrincipal(`arn:aws:iam::${accountConfig.accountId}:root`)
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

    // Transit Gateway connectivity removed - managed by Terraform

    // Database resources will be added here if needed
    // For now, we'll focus on the core microservice infrastructure

    // Add environment-specific tags
    cdk.Tags.of(this).add('Environment', environment);
    cdk.Tags.of(this).add('Service', serviceConfig.name);
    cdk.Tags.of(this).add('ServiceType', 'Provider');
    cdk.Tags.of(this).add('ManagedBy', 'CDK');
    cdk.Tags.of(this).add('Account', 'Provider');
  }
}