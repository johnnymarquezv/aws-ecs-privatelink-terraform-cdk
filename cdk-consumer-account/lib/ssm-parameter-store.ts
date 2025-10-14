import { Construct } from 'constructs';
import * as ssm from 'aws-cdk-lib/aws-ssm';

export interface SsmParameterStoreProps {
  environment: string;
  region?: string;
}

export class SsmParameterStore extends Construct {
  public readonly transitGatewayId: string;
  public readonly transitGatewayRouteTableId: string;
  public readonly crossAccountRoleArn: string;
  public readonly networkingAccountId: string;
  public readonly microservicesAccounts: string[];
  public readonly environment: string;

  constructor(scope: Construct, id: string, props: SsmParameterStoreProps) {
    super(scope, id);

    const { environment, region } = props;

    // For synthesis, use hardcoded values. In production, these would come from SSM Parameter Store
    this.transitGatewayId = `tgw-${environment}-12345678`;
    this.transitGatewayRouteTableId = `tgw-rtb-${environment}-12345678`;
    this.crossAccountRoleArn = `arn:aws:iam::111111111111:role/CrossAccountRole-${environment}`;
    this.networkingAccountId = '111111111111';
    this.microservicesAccounts = ['222222222222', '333333333333'];
    this.environment = environment;
  }
}