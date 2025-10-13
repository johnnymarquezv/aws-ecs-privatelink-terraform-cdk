import { Template } from 'aws-cdk-lib/assertions';
import * as cdk from 'aws-cdk-lib';
import { ConsumerStack } from '../lib/consumer-stack';

describe('ConsumerStack', () => {
  test('creates ECS cluster and service for API consumer', () => {
    const app = new cdk.App();
    const stack = new ConsumerStack(app, 'TestStack', {
      environment: 'dev',
      serviceType: 'api-consumer',
    });

    const template = Template.fromStack(stack);

    // Check ECS cluster
    template.hasResourceProperties('AWS::ECS::Cluster', {
      ClusterName: 'api-consumer-dev-cluster',
    });

    // Check ECS service
    template.hasResourceProperties('AWS::ECS::Service', {
      LaunchType: 'FARGATE',
      DesiredCount: 1,
    });

    // Note: VPC Endpoint creation is commented out in the current implementation
  });

  test('creates ECS cluster and service for User consumer', () => {
    const app = new cdk.App();
    const stack = new ConsumerStack(app, 'TestUserStack', {
      environment: 'prod',
      serviceType: 'user-consumer',
    });

    const template = Template.fromStack(stack);

    // Check ECS cluster
    template.hasResourceProperties('AWS::ECS::Cluster', {
      ClusterName: 'user-consumer-prod-cluster',
    });

    // Check ECS service
    template.hasResourceProperties('AWS::ECS::Service', {
      LaunchType: 'FARGATE',
      DesiredCount: 3,
    });
  });
});
