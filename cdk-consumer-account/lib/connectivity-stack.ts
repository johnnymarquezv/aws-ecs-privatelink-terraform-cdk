import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as logs from 'aws-cdk-lib/aws-logs';
import { Construct } from 'constructs';

export interface ConnectivityStackProps extends cdk.StackProps {
  vpcId: string;
  privateSubnetIds: string[];
  microserviceName: string;
  microservicePort: number;
  microserviceImage: string;
  // Terraform-managed resources
  basePrivateSecurityGroupId: string;
  ecsTaskExecutionRoleArn: string;
  ecsTaskRoleArn: string;
  ecsApplicationLogGroupName: string;
  // Multi-account configuration
  environment?: string;
  consumerEndpointServices: Array<{
    serviceName: string;
    vpcEndpointServiceId: string;
    port: number;
  }>;
}

export class ConnectivityStack extends cdk.Stack {
  public readonly vpc: ec2.IVpc;
  public readonly cluster: ecs.Cluster;
  public readonly consumerEndpoints: ec2.VpcEndpoint[] = [];

  constructor(scope: Construct, id: string, props: ConnectivityStackProps) {
    super(scope, id, props);

    // Import VPC from Terraform outputs
    this.vpc = ec2.Vpc.fromLookup(this, 'ImportedVpc', {
      vpcId: props.vpcId,
    });

    // Create ECS Cluster for consumer microservice
    this.cluster = new ecs.Cluster(this, 'ConsumerCluster', {
      vpc: this.vpc,
      clusterName: `${props.microserviceName}-consumer-cluster`,
      containerInsights: true,
    });

    // Import CloudWatch Log Group from Terraform
    const logGroup = logs.LogGroup.fromLogGroupName(this, 'ImportedLogGroup', props.ecsApplicationLogGroupName);

    // Import IAM roles from Terraform
    const taskExecutionRole = iam.Role.fromRoleArn(this, 'ImportedTaskExecutionRole', props.ecsTaskExecutionRoleArn);
    const taskRole = iam.Role.fromRoleArn(this, 'ImportedTaskRole', props.ecsTaskRoleArn);

    // Create Task Definition for consumer
    const taskDefinition = new ecs.FargateTaskDefinition(this, 'ConsumerTaskDef', {
      family: `${props.microserviceName}-consumer`,
      cpu: 256,
      memoryLimitMiB: 512,
      executionRole: taskExecutionRole,
      taskRole: taskRole,
    });

    // Add container to task definition
    const container = taskDefinition.addContainer('ConsumerContainer', {
      image: ecs.ContainerImage.fromRegistry(props.microserviceImage),
      logging: ecs.LogDrivers.awsLogs({
        streamPrefix: `${props.microserviceName}-consumer`,
        logGroup: logGroup,
      }),
      environment: {
        SERVICE_NAME: `${props.microserviceName}-consumer`,
        SERVICE_PORT: props.microservicePort.toString(),
        SERVICE_VERSION: '1.0.0',
        LOG_LEVEL: 'INFO',
        ENABLE_METRICS: 'true',
        RATE_LIMIT: '100',
        // Add environment variables for service discovery
        CONSUMER_SERVICES: JSON.stringify(props.consumerEndpointServices.map(s => ({
          name: s.serviceName,
          endpoint: `vpce-${s.vpcEndpointServiceId.split('-').pop()}-${s.vpcEndpointServiceId.split('-')[1]}.vpce-svc-${s.vpcEndpointServiceId}.us-east-1.vpce.amazonaws.com`,
          port: s.port,
          timeout: 30
        }))),
      },
    });

    container.addPortMappings({
      containerPort: props.microservicePort,
      protocol: ecs.Protocol.TCP,
    });

    // Import base security groups from Terraform
    const basePrivateSecurityGroup = ec2.SecurityGroup.fromSecurityGroupId(
      this, 
      'ImportedBasePrivateSecurityGroup', 
      props.basePrivateSecurityGroupId
    );

    // Create security group for consumer
    const consumerSecurityGroup = new ec2.SecurityGroup(this, 'ConsumerSecurityGroup', {
      vpc: this.vpc,
      description: `Security group for ${props.microserviceName} consumer`,
      allowAllOutbound: true,
    });

    // Allow communication with base security groups
    consumerSecurityGroup.addIngressRule(
      ec2.Peer.securityGroupId(basePrivateSecurityGroup.securityGroupId),
      ec2.Port.tcp(props.microservicePort),
      'Allow traffic from base private security group'
    );

    // Create ECS Service
    const ecsService = new ecs.FargateService(this, 'ConsumerService', {
      cluster: this.cluster,
      taskDefinition: taskDefinition,
      desiredCount: 1,
      securityGroups: [consumerSecurityGroup],
      vpcSubnets: {
        subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
      },
      assignPublicIp: false,
    });

    // Create interface VPC endpoints for consuming other microservices
    props.consumerEndpointServices.forEach((endpointService, index) => {
      const consumerEndpoint = new ec2.VpcEndpoint(this, `ConsumerEndpoint${index}`, {
        vpc: this.vpc,
        service: ec2.VpcEndpointService.fromVpcEndpointServiceId(
          this,
          `ConsumerEndpointService${index}`,
          endpointService.vpcEndpointServiceId
        ),
        vpcEndpoints: [ec2.VpcEndpointType.INTERFACE],
        subnets: {
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
        },
        securityGroups: [
          new ec2.SecurityGroup(this, `ConsumerEndpointSecurityGroup${index}`, {
            vpc: this.vpc,
            description: `Security group for consumer endpoint ${endpointService.serviceName}`,
            allowAllOutbound: true,
          }),
        ],
      });

      this.consumerEndpoints.push(consumerEndpoint);

      // Output the endpoint details
      new cdk.CfnOutput(this, `ConsumerEndpoint${index}DnsName`, {
        value: consumerEndpoint.vpcEndpointDnsEntries[0].dnsName,
        description: `DNS name for consumer endpoint ${endpointService.serviceName}`,
        exportName: `${endpointService.serviceName}-consumer-endpoint-dns`,
      });
    });

    // Outputs
    new cdk.CfnOutput(this, 'ConsumerEndpointsCount', {
      value: this.consumerEndpoints.length.toString(),
      description: 'Number of consumer VPC endpoints created',
    });

    new cdk.CfnOutput(this, 'ConsumerClusterArn', {
      value: this.cluster.clusterArn,
      description: 'Consumer ECS Cluster ARN',
      exportName: `${props.microserviceName}-consumer-cluster-arn`,
    });
  }
}