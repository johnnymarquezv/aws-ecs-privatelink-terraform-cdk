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

    // Connectivity Parameters from Networking Account
    this.transitGatewayId = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/connectivity/transit-gateway-id`
    );
    this.transitGatewayRouteTableId = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/connectivity/transit-gateway-route-table-id`
    );
    this.crossAccountRoleArn = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/connectivity/cross-account-role-arn`
    );
    this.networkingAccountId = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/connectivity/networking-account-id`
    );
    this.microservicesAccounts = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/connectivity/microservices-accounts`
    ).split(',');
    this.environment = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/connectivity/environment`
    );
  }
}