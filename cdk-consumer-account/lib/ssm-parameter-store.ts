import { Construct } from 'constructs';
import * as ssm from 'aws-cdk-lib/aws-ssm';

export interface SsmParameterStoreProps {
  environment: string;
  region?: string;
}

export class SsmParameterStore extends Construct {
  public readonly vpcId: string;
  public readonly publicSubnetIds: string[];
  public readonly privateSubnetIds: string[];
  public readonly baseDefaultSecurityGroupId: string;
  public readonly basePrivateSecurityGroupId: string;
  public readonly ecsTaskExecutionRoleArn: string;
  public readonly ecsTaskRoleArn: string;
  public readonly ecsApplicationLogGroupName: string;
  public readonly artifactsS3Bucket: string;
  public readonly ecrRepositoryUrl: string;
  public readonly codebuildProjectName: string;
  public readonly monitoringRoleArn: string;
  public readonly cicdRoleArn: string;

  constructor(scope: Construct, id: string, props: SsmParameterStoreProps) {
    super(scope, id);

    const { environment, region } = props;

    // Base Infrastructure Parameters
    this.vpcId = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/base-infra/vpc-id`
    );
    this.publicSubnetIds = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/base-infra/public-subnet-ids`
    ).split(',');
    this.privateSubnetIds = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/base-infra/private-subnet-ids`
    ).split(',');
    this.baseDefaultSecurityGroupId = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/base-infra/base-default-security-group-id`
    );
    this.basePrivateSecurityGroupId = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/base-infra/base-private-security-group-id`
    );
    this.ecsTaskExecutionRoleArn = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/base-infra/ecs-task-execution-role-arn`
    );
    this.ecsTaskRoleArn = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/base-infra/ecs-task-role-arn`
    );
    this.ecsApplicationLogGroupName = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/base-infra/ecs-application-log-group-name`
    );

    // Shared Services Parameters
    this.artifactsS3Bucket = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/shared-services/artifacts-s3-bucket`
    );
    this.ecrRepositoryUrl = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/shared-services/ecr-repository-url`
    );
    this.codebuildProjectName = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/shared-services/codebuild-project-name`
    );
    this.monitoringRoleArn = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/shared-services/monitoring-role-arn`
    );
    this.cicdRoleArn = ssm.StringParameter.valueFromLookup(
      this,
      `/${environment}/shared-services/cicd-role-arn`
    );
  }
}