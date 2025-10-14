import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as cdk from 'aws-cdk-lib';

export interface TransitGatewayConnectivityProps {
  vpc: ec2.IVpc;
  transitGatewayId: string;
  transitGatewayRouteTableId: string;
  environment: string;
  accountType: 'provider' | 'consumer';
  serviceName: string;
}

export class TransitGatewayConnectivity extends Construct {
  public readonly transitGatewayAttachment: ec2.CfnTransitGatewayAttachment;
  public readonly routeTableAssociation: ec2.CfnTransitGatewayRouteTableAssociation;
  public readonly routeTablePropagation: ec2.CfnTransitGatewayRouteTablePropagation;

  constructor(scope: Construct, id: string, props: TransitGatewayConnectivityProps) {
    super(scope, id);

    const { vpc, transitGatewayId, transitGatewayRouteTableId, environment, accountType, serviceName } = props;

    // Create Transit Gateway attachment
    this.transitGatewayAttachment = new ec2.CfnTransitGatewayAttachment(this, 'TransitGatewayAttachment', {
      transitGatewayId: transitGatewayId,
      vpcId: vpc.vpcId,
      subnetIds: vpc.privateSubnets.map(subnet => subnet.subnetId),
      tags: [
        {
          key: 'Name',
          value: `${serviceName}-${environment}-tgw-attachment`
        },
        {
          key: 'Environment',
          value: environment
        },
        {
          key: 'AccountType',
          value: accountType
        },
        {
          key: 'Service',
          value: serviceName
        }
      ]
    });

    // Associate with Transit Gateway route table
    this.routeTableAssociation = new ec2.CfnTransitGatewayRouteTableAssociation(this, 'RouteTableAssociation', {
      transitGatewayRouteTableId: transitGatewayRouteTableId,
      transitGatewayAttachmentId: this.transitGatewayAttachment.ref
    });

    // Propagate routes to Transit Gateway route table
    this.routeTablePropagation = new ec2.CfnTransitGatewayRouteTablePropagation(this, 'RouteTablePropagation', {
      transitGatewayRouteTableId: transitGatewayRouteTableId,
      transitGatewayAttachmentId: this.transitGatewayAttachment.ref
    });

    // Add routes to Transit Gateway for cross-account communication
    // Note: Routes are managed by the networking account, not individual accounts
    // This ensures centralized route management and avoids conflicts

    // Output Transit Gateway attachment ID
    new cdk.CfnOutput(this, 'TransitGatewayAttachmentId', {
      value: this.transitGatewayAttachment.ref,
      description: 'Transit Gateway attachment ID',
      exportName: `${serviceName}-${environment}-tgw-attachment-id`
    });
  }
}

