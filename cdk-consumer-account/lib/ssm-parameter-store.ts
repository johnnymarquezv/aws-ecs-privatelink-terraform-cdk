import { Construct } from 'constructs';

export interface ConnectivityConfigProps {
  environment: string;
  region?: string;
  networkingAccountId?: string;
  crossAccountRoleArn?: string;
}

export class ConnectivityConfig extends Construct {
  public readonly transitGatewayId: string;
  public readonly transitGatewayRouteTableId: string;
  public readonly crossAccountRoleArn: string;
  public readonly networkingAccountId: string;
  public readonly microservicesAccounts: string[];
  public readonly environment: string;

  constructor(scope: Construct, id: string, props: ConnectivityConfigProps) {
    super(scope, id);

    const { environment, region, networkingAccountId, crossAccountRoleArn } = props;

    // Use hardcoded values for each environment
    // These should be updated with actual values after Terraform deployment
    const config = this.getEnvironmentConfig(environment);
    
    this.transitGatewayId = config.transitGatewayId;
    this.transitGatewayRouteTableId = config.transitGatewayRouteTableId;
    this.crossAccountRoleArn = config.crossAccountRoleArn;
    this.networkingAccountId = config.networkingAccountId;
    this.microservicesAccounts = config.microservicesAccounts;
    this.environment = environment;
  }

  private getEnvironmentConfig(environment: string) {
    const configs = {
      dev: {
        transitGatewayId: 'tgw-dev-placeholder',
        transitGatewayRouteTableId: 'tgw-rtb-dev-placeholder',
        crossAccountRoleArn: 'arn:aws:iam::111111111111:role/CrossAccountRole-dev',
        networkingAccountId: '111111111111',
        microservicesAccounts: ['222222222222', '333333333333']
      },
      staging: {
        transitGatewayId: 'tgw-staging-placeholder',
        transitGatewayRouteTableId: 'tgw-rtb-staging-placeholder',
        crossAccountRoleArn: 'arn:aws:iam::111111111111:role/CrossAccountRole-staging',
        networkingAccountId: '111111111111',
        microservicesAccounts: ['222222222222', '333333333333']
      },
      prod: {
        transitGatewayId: 'tgw-prod-placeholder',
        transitGatewayRouteTableId: 'tgw-rtb-prod-placeholder',
        crossAccountRoleArn: 'arn:aws:iam::111111111111:role/CrossAccountRole-prod',
        networkingAccountId: '111111111111',
        microservicesAccounts: ['222222222222', '333333333333']
      }
    };

    return configs[environment as keyof typeof configs] || configs.dev;
  }
}