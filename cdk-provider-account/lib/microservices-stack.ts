import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as logs from 'aws-cdk-lib/aws-logs';
import { Construct } from 'constructs';

export interface MicroservicesStackProps extends cdk.StackProps {
  vpcId: string;
  publicSubnetIds: string[];
  privateSubnetIds: string[];
  microserviceName: string;
  microservicePort: number;
  microserviceImage: string;
  // Terraform-managed resources
  baseDefaultSecurityGroupId: string;
  basePrivateSecurityGroupId: string;
  ecsTaskExecutionRoleArn: string;
  ecsTaskRoleArn: string;
  ecsApplicationLogGroupName: string;
  // Multi-account configuration
  allowedAccounts?: string[];
  environment?: string;
  serviceDescription?: string;
}

export class MicroservicesStack extends cdk.Stack {
  public readonly vpc: ec2.IVpc;
  public readonly cluster: ecs.Cluster;
  public readonly nlb: elbv2.NetworkLoadBalancer;
  public readonly vpcEndpointService: ec2.VpcEndpointService;

  constructor(scope: Construct, id: string, props: MicroservicesStackProps) {
    super(scope, id, props);

    // Import VPC from Terraform outputs
    this.vpc = ec2.Vpc.fromLookup(this, 'ImportedVpc', {
      vpcId: props.vpcId,
    });

    // Create ECS Cluster
    this.cluster = new ecs.Cluster(this, 'MicroserviceCluster', {
      vpc: this.vpc,
      clusterName: `${props.microserviceName}-cluster`,
      containerInsights: true,
    });

    // Import CloudWatch Log Group from Terraform
    const logGroup = logs.LogGroup.fromLogGroupName(this, 'ImportedLogGroup', props.ecsApplicationLogGroupName);

    // Import IAM roles from Terraform
    const taskExecutionRole = iam.Role.fromRoleArn(this, 'ImportedTaskExecutionRole', props.ecsTaskExecutionRoleArn);
    const taskRole = iam.Role.fromRoleArn(this, 'ImportedTaskRole', props.ecsTaskRoleArn);

    // Create Task Definition
    const taskDefinition = new ecs.FargateTaskDefinition(this, 'MicroserviceTaskDef', {
      family: props.microserviceName,
      cpu: 256,
      memoryLimitMiB: 512,
      executionRole: taskExecutionRole,
      taskRole: taskRole,
    });

    // Add container to task definition
    const container = taskDefinition.addContainer('MicroserviceContainer', {
      image: ecs.ContainerImage.fromRegistry(props.microserviceImage),
      logging: ecs.LogDrivers.awsLogs({
        streamPrefix: props.microserviceName,
        logGroup: logGroup,
      }),
      environment: {
        PORT: props.microservicePort.toString(),
      },
    });

    container.addPortMappings({
      containerPort: props.microservicePort,
      protocol: ecs.Protocol.TCP,
    });

    // Import base security groups from Terraform
    const baseDefaultSecurityGroup = ec2.SecurityGroup.fromSecurityGroupId(
      this, 
      'ImportedBaseDefaultSecurityGroup', 
      props.baseDefaultSecurityGroupId
    );
    
    const basePrivateSecurityGroup = ec2.SecurityGroup.fromSecurityGroupId(
      this, 
      'ImportedBasePrivateSecurityGroup', 
      props.basePrivateSecurityGroupId
    );

    // Create application-specific security group that extends base security groups
    const ecsSecurityGroup = new ec2.SecurityGroup(this, 'EcsSecurityGroup', {
      vpc: this.vpc,
      description: `Application-specific security group for ${props.microserviceName} ECS service`,
      allowAllOutbound: true,
    });

    // Add specific rules for this microservice
    ecsSecurityGroup.addIngressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(props.microservicePort),
      'Allow inbound traffic on microservice port'
    );

    // Allow communication with base security groups
    ecsSecurityGroup.addIngressRule(
      ec2.Peer.securityGroupId(basePrivateSecurityGroup.securityGroupId),
      ec2.Port.tcp(props.microservicePort),
      'Allow traffic from base private security group'
    );

    // Create ECS Service
    const ecsService = new ecs.FargateService(this, 'MicroserviceService', {
      cluster: this.cluster,
      taskDefinition: taskDefinition,
      desiredCount: 2,
      securityGroups: [ecsSecurityGroup],
      vpcSubnets: {
        subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
      },
      assignPublicIp: false,
    });

    // Create Network Load Balancer
    this.nlb = new elbv2.NetworkLoadBalancer(this, 'MicroserviceNLB', {
      vpc: this.vpc,
      internetFacing: false,
      vpcSubnets: {
        subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
      },
    });

    // Create Target Group
    const targetGroup = new elbv2.NetworkTargetGroup(this, 'MicroserviceTargetGroup', {
      vpc: this.vpc,
      port: props.microservicePort,
      protocol: elbv2.Protocol.TCP,
      targetType: elbv2.TargetType.IP,
      healthCheck: {
        enabled: true,
        healthyHttpCodes: '200',
        interval: cdk.Duration.seconds(30),
        path: '/', // nginx serves on root path
        port: props.microservicePort.toString(),
        protocol: elbv2.Protocol.HTTP,
        timeout: cdk.Duration.seconds(5),
        unhealthyThresholdCount: 3,
      },
    });

    // Add listener to NLB
    this.nlb.addListener('MicroserviceListener', {
      port: props.microservicePort,
      protocol: elbv2.Protocol.TCP,
      defaultTargetGroups: [targetGroup],
    });

    // Attach ECS service to target group
    ecsService.attachToNetworkTargetGroup(targetGroup);

    // Create VPC Endpoint Service (Provider) with proper cross-account access
    const allowedPrincipals = props.allowedAccounts && props.allowedAccounts.length > 0
      ? props.allowedAccounts.map(accountId => new iam.ArnPrincipal(`arn:aws:iam::${accountId}:root`))
      : [new iam.ArnPrincipal('*')]; // Fallback to allow all if no accounts specified

    this.vpcEndpointService = new ec2.VpcEndpointService(this, 'MicroserviceVpcEndpointService', {
      vpcEndpointServiceLoadBalancers: [this.nlb],
      acceptanceRequired: false,
      allowedPrincipals: allowedPrincipals,
    });

    // Provider-specific outputs and configuration

    // Outputs
    new cdk.CfnOutput(this, 'VpcEndpointServiceId', {
      value: this.vpcEndpointService.vpcEndpointServiceId,
      description: 'VPC Endpoint Service ID for this microservice',
      exportName: `${props.microserviceName}-vpc-endpoint-service-id`,
    });

    new cdk.CfnOutput(this, 'VpcEndpointServiceName', {
      value: this.vpcEndpointService.vpcEndpointServiceName,
      description: 'VPC Endpoint Service Name for this microservice',
      exportName: `${props.microserviceName}-vpc-endpoint-service-name`,
    });

    new cdk.CfnOutput(this, 'NetworkLoadBalancerArn', {
      value: this.nlb.loadBalancerArn,
      description: 'Network Load Balancer ARN for this microservice',
      exportName: `${props.microserviceName}-nlb-arn`,
    });

    new cdk.CfnOutput(this, 'EcsClusterArn', {
      value: this.cluster.clusterArn,
      description: 'ECS Cluster ARN for this microservice',
      exportName: `${props.microserviceName}-ecs-cluster-arn`,
    });
  }
}


