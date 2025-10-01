import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';

export interface ConnectivityStackProps extends cdk.StackProps {
  vpcId: string;
  privateSubnetIds: string[];
  basePrivateSecurityGroupId: string;
  consumerEndpointServices: Array<{
    serviceName: string;
    vpcEndpointServiceId: string;
    port: number;
  }>;
}

export class ConnectivityStack extends cdk.Stack {
  public readonly consumerEndpoints: ec2.VpcEndpoint[] = [];

  constructor(scope: Construct, id: string, props: ConnectivityStackProps) {
    super(scope, id, props);

    // Import VPC from Terraform outputs
    const vpc = ec2.Vpc.fromLookup(this, 'ImportedVpc', {
      vpcId: props.vpcId,
    });

    // Import base security group from Terraform
    const basePrivateSecurityGroup = ec2.SecurityGroup.fromSecurityGroupId(
      this, 
      'ImportedBasePrivateSecurityGroup', 
      props.basePrivateSecurityGroupId
    );

    // Create interface VPC endpoints for consuming other microservices
    props.consumerEndpointServices.forEach((endpointService, index) => {
      const consumerEndpoint = new ec2.VpcEndpoint(this, `ConsumerEndpoint${index}`, {
        vpc: vpc,
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
            vpc: vpc,
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

    // Output summary
    new cdk.CfnOutput(this, 'ConsumerEndpointsCount', {
      value: this.consumerEndpoints.length.toString(),
      description: 'Number of consumer VPC endpoints created',
    });
  }
}
