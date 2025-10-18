import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as rds from 'aws-cdk-lib/aws-rds';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as elasticache from 'aws-cdk-lib/aws-elasticache';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as backup from 'aws-cdk-lib/aws-backup';
import * as events from 'aws-cdk-lib/aws-events';
import * as ssm from 'aws-cdk-lib/aws-ssm';
import { Construct } from 'constructs';

export interface DatabaseStackProps extends cdk.StackProps {
  environment: 'dev' | 'staging' | 'prod';
  vpc: ec2.Vpc;
  serviceName: string;
  vpcCidr: string;
}

export class DatabaseStack extends cdk.Stack {
  public readonly rdsCluster: rds.DatabaseCluster;
  public readonly dynamoTable: dynamodb.Table;
  public readonly redisCluster: elasticache.CfnCacheCluster;
  public readonly backupVault: backup.BackupVault;
  public readonly rdsSecret: secretsmanager.Secret;

  constructor(scope: Construct, id: string, props: DatabaseStackProps) {
    super(scope, id, props);

    const { environment, vpc, serviceName, vpcCidr } = props;

    // Environment-specific database configuration
    const dbConfig = this.getDatabaseConfig(environment);

    // Create security groups for databases
    const rdsSecurityGroup = new ec2.SecurityGroup(this, 'RdsSecurityGroup', {
      vpc: vpc,
      description: `Security group for RDS cluster in ${environment}`,
      allowAllOutbound: false,
    });

    const redisSecurityGroup = new ec2.SecurityGroup(this, 'RedisSecurityGroup', {
      vpc: vpc,
      description: `Security group for Redis cluster in ${environment}`,
      allowAllOutbound: false,
    });

    // Allow database access from VPC
    rdsSecurityGroup.addIngressRule(
      ec2.Peer.ipv4(vpcCidr),
      ec2.Port.tcp(5432),
      'PostgreSQL access from VPC'
    );

    redisSecurityGroup.addIngressRule(
      ec2.Peer.ipv4(vpcCidr),
      ec2.Port.tcp(6379),
      'Redis access from VPC'
    );

    // Create database subnet group
    const dbSubnetGroup = new rds.SubnetGroup(this, 'DatabaseSubnetGroup', {
      description: `Database subnet group for ${serviceName} in ${environment}`,
      vpc: vpc,
      vpcSubnets: {
        subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
      },
    });

    // Create RDS secret for database credentials
    this.rdsSecret = new secretsmanager.Secret(this, 'RdsSecret', {
      description: `Database credentials for ${serviceName} in ${environment}`,
      generateSecretString: {
        secretStringTemplate: JSON.stringify({ username: 'postgres' }),
        generateStringKey: 'password',
        excludeCharacters: '"@/\\',
        includeSpace: false,
        passwordLength: 32,
      },
    });

    // Create RDS PostgreSQL cluster
    this.rdsCluster = new rds.DatabaseCluster(this, 'RdsCluster', {
      engine: rds.DatabaseClusterEngine.auroraPostgres({
        version: rds.AuroraPostgresEngineVersion.VER_15_3,
      }),
      credentials: rds.Credentials.fromSecret(this.rdsSecret),
      instanceProps: {
        instanceType: dbConfig.rds.instanceType,
        vpcSubnets: {
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
        },
        vpc: vpc,
        securityGroups: [rdsSecurityGroup],
        enablePerformanceInsights: true,
      },
      defaultDatabaseName: dbConfig.rds.databaseName,
      backup: {
        retention: cdk.Duration.days(dbConfig.rds.backupRetentionDays),
        preferredWindow: dbConfig.rds.backupWindow,
      },
      storageEncrypted: true,
      deletionProtection: environment === 'prod',
      removalPolicy: environment === 'prod' ? cdk.RemovalPolicy.RETAIN : cdk.RemovalPolicy.DESTROY,
      subnetGroup: dbSubnetGroup,
    });

    // Create DynamoDB table
    this.dynamoTable = new dynamodb.Table(this, 'DynamoTable', {
      tableName: `${serviceName}-${environment}-data`,
      partitionKey: {
        name: 'id',
        type: dynamodb.AttributeType.STRING,
      },
      sortKey: {
        name: 'timestamp',
        type: dynamodb.AttributeType.NUMBER,
      },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      pointInTimeRecovery: true,
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
      removalPolicy: environment === 'prod' ? cdk.RemovalPolicy.RETAIN : cdk.RemovalPolicy.DESTROY,
      timeToLiveAttribute: 'ttl',
    });

    // Add Global Secondary Index for DynamoDB
    this.dynamoTable.addGlobalSecondaryIndex({
      indexName: 'user-index',
      partitionKey: {
        name: 'userId',
        type: dynamodb.AttributeType.STRING,
      },
      sortKey: {
        name: 'createdAt',
        type: dynamodb.AttributeType.NUMBER,
      },
    });

    // Create ElastiCache Redis cluster
    const redisSubnetGroup = new elasticache.CfnSubnetGroup(this, 'RedisSubnetGroup', {
      description: `Redis subnet group for ${serviceName} in ${environment}`,
      subnetIds: vpc.privateSubnets.map(subnet => subnet.subnetId),
    });

    this.redisCluster = new elasticache.CfnCacheCluster(this, 'RedisCluster', {
      cacheNodeType: dbConfig.redis.nodeType,
      engine: 'redis',
      numCacheNodes: dbConfig.redis.numNodes,
      vpcSecurityGroupIds: [redisSecurityGroup.securityGroupId],
      cacheSubnetGroupName: redisSubnetGroup.ref,
      engineVersion: '7.0',
      port: 6379,
      preferredMaintenanceWindow: dbConfig.redis.maintenanceWindow,
      snapshotRetentionLimit: dbConfig.redis.snapshotRetentionDays,
      snapshotWindow: dbConfig.redis.snapshotWindow,
    });

    // Create backup vault for database backups
    this.backupVault = new backup.BackupVault(this, 'BackupVault', {
      backupVaultName: `${serviceName}-${environment}-backup-vault`,
      removalPolicy: environment === 'prod' ? cdk.RemovalPolicy.RETAIN : cdk.RemovalPolicy.DESTROY,
    });

    // Create backup plan for RDS
    const backupPlan = new backup.BackupPlan(this, 'DatabaseBackupPlan', {
      backupPlanName: `${serviceName}-${environment}-database-backup-plan`,
      backupPlanRules: [
        new backup.BackupPlanRule({
          ruleName: 'DailyBackup',
          scheduleExpression: events.Schedule.cron({
            hour: '2',
            minute: '0',
          }),
          deleteAfter: cdk.Duration.days(dbConfig.backup.retentionDays),
          moveToColdStorageAfter: cdk.Duration.days(30),
        }),
        new backup.BackupPlanRule({
          ruleName: 'WeeklyBackup',
          scheduleExpression: events.Schedule.cron({
            weekDay: 'SUN',
            hour: '3',
            minute: '0',
          }),
          deleteAfter: cdk.Duration.days(90),
          moveToColdStorageAfter: cdk.Duration.days(7),
        }),
      ],
    });

    // Add RDS cluster to backup plan
    backupPlan.addSelection('RdsBackupSelection', {
      resources: [backup.BackupResource.fromRdsDatabaseCluster(this.rdsCluster)],
      role: new iam.Role(this, 'BackupRole', {
        assumedBy: new iam.ServicePrincipal('backup.amazonaws.com'),
        managedPolicies: [
          iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSBackupServiceRolePolicyForBackup'),
        ],
      }),
    });

    // Create CloudWatch Log Groups for database monitoring
    new logs.LogGroup(this, 'RdsLogGroup', {
      logGroupName: `/aws/rds/cluster/${this.rdsCluster.clusterIdentifier}/postgresql`,
      retention: logs.RetentionDays[dbConfig.logRetention],
      removalPolicy: environment === 'prod' ? cdk.RemovalPolicy.RETAIN : cdk.RemovalPolicy.DESTROY,
    });

    // Export database values to SSM Parameter Store
    new ssm.StringParameter(this, 'RdsEndpointParameter', {
      parameterName: `/${environment}/${serviceName}/database/rds-endpoint`,
      stringValue: this.rdsCluster.clusterEndpoint.hostname,
      description: 'RDS cluster endpoint for database connections',
      tier: ssm.ParameterTier.STANDARD,
    });

    new ssm.StringParameter(this, 'RdsSecretArnParameter', {
      parameterName: `/${environment}/${serviceName}/database/rds-secret-arn`,
      stringValue: this.rdsSecret.secretArn,
      description: 'RDS secret ARN for database credentials',
      tier: ssm.ParameterTier.STANDARD,
    });

    new ssm.StringParameter(this, 'RdsPortParameter', {
      parameterName: `/${environment}/${serviceName}/database/rds-port`,
      stringValue: '5432',
      description: 'RDS cluster port',
      tier: ssm.ParameterTier.STANDARD,
    });

    new ssm.StringParameter(this, 'RdsDatabaseNameParameter', {
      parameterName: `/${environment}/${serviceName}/database/rds-database-name`,
      stringValue: dbConfig.rds.databaseName,
      description: 'RDS database name',
      tier: ssm.ParameterTier.STANDARD,
    });

    new ssm.StringParameter(this, 'DynamoTableNameParameter', {
      parameterName: `/${environment}/${serviceName}/database/dynamo-table-name`,
      stringValue: this.dynamoTable.tableName,
      description: 'DynamoDB table name',
      tier: ssm.ParameterTier.STANDARD,
    });

    new ssm.StringParameter(this, 'DynamoTableArnParameter', {
      parameterName: `/${environment}/${serviceName}/database/dynamo-table-arn`,
      stringValue: this.dynamoTable.tableArn,
      description: 'DynamoDB table ARN',
      tier: ssm.ParameterTier.STANDARD,
    });

    new ssm.StringParameter(this, 'RedisEndpointParameter', {
      parameterName: `/${environment}/${serviceName}/database/redis-endpoint`,
      stringValue: this.redisCluster.attrRedisEndpointAddress,
      description: 'Redis cluster endpoint',
      tier: ssm.ParameterTier.STANDARD,
    });

    new ssm.StringParameter(this, 'RedisPortParameter', {
      parameterName: `/${environment}/${serviceName}/database/redis-port`,
      stringValue: '6379',
      description: 'Redis cluster port',
      tier: ssm.ParameterTier.STANDARD,
    });

    new ssm.StringParameter(this, 'BackupVaultArnParameter', {
      parameterName: `/${environment}/${serviceName}/database/backup-vault-arn`,
      stringValue: this.backupVault.backupVaultArn,
      description: 'Backup vault ARN for database backups',
      tier: ssm.ParameterTier.STANDARD,
    });

    // Output database connection information
    new cdk.CfnOutput(this, 'RdsClusterEndpoint', {
      value: this.rdsCluster.clusterEndpoint.hostname,
      description: 'RDS cluster endpoint',
      exportName: `${serviceName}-${environment}-rds-endpoint`,
    });

    new cdk.CfnOutput(this, 'RdsSecretArn', {
      value: this.rdsSecret.secretArn,
      description: 'RDS secret ARN',
      exportName: `${serviceName}-${environment}-rds-secret-arn`,
    });

    new cdk.CfnOutput(this, 'DynamoTableName', {
      value: this.dynamoTable.tableName,
      description: 'DynamoDB table name',
      exportName: `${serviceName}-${environment}-dynamo-table-name`,
    });

    new cdk.CfnOutput(this, 'RedisEndpoint', {
      value: this.redisCluster.attrRedisEndpointAddress,
      description: 'Redis cluster endpoint',
      exportName: `${serviceName}-${environment}-redis-endpoint`,
    });

    // Add environment-specific tags
    cdk.Tags.of(this).add('Environment', environment);
    cdk.Tags.of(this).add('Service', serviceName);
    cdk.Tags.of(this).add('ServiceType', 'Database');
    cdk.Tags.of(this).add('ManagedBy', 'CDK');
    cdk.Tags.of(this).add('Account', 'Provider');
  }

  private getDatabaseConfig(environment: string) {
    const configs = {
      dev: {
        rds: {
          instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MEDIUM),
          databaseName: 'microservicedb',
          backupRetentionDays: 7,
          backupWindow: '03:00-04:00',
        },
        redis: {
          nodeType: 'cache.t3.micro',
          numNodes: 1,
          maintenanceWindow: 'sun:04:00-sun:05:00',
          snapshotRetentionDays: 5,
          snapshotWindow: '03:00-04:00',
        },
        backup: {
          retentionDays: 30,
        },
        logRetention: 'ONE_WEEK' as const,
      },
      staging: {
        rds: {
          instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.LARGE),
          databaseName: 'microservicedb',
          backupRetentionDays: 14,
          backupWindow: '03:00-04:00',
        },
        redis: {
          nodeType: 'cache.t3.small',
          numNodes: 1,
          maintenanceWindow: 'sun:04:00-sun:05:00',
          snapshotRetentionDays: 7,
          snapshotWindow: '03:00-04:00',
        },
        backup: {
          retentionDays: 60,
        },
        logRetention: 'TWO_WEEKS' as const,
      },
      prod: {
        rds: {
          instanceType: ec2.InstanceType.of(ec2.InstanceClass.R5, ec2.InstanceSize.LARGE),
          databaseName: 'microservicedb',
          backupRetentionDays: 30,
          backupWindow: '03:00-04:00',
        },
        redis: {
          nodeType: 'cache.r5.large',
          numNodes: 2,
          maintenanceWindow: 'sun:04:00-sun:05:00',
          snapshotRetentionDays: 14,
          snapshotWindow: '03:00-04:00',
        },
        backup: {
          retentionDays: 365,
        },
        logRetention: 'ONE_MONTH' as const,
      },
    };

    return configs[environment as keyof typeof configs];
  }
}
