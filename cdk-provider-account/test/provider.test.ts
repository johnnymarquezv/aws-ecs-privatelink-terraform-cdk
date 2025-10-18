import { Template } from 'aws-cdk-lib/assertions';
import * as cdk from 'aws-cdk-lib';
import { ProviderStack } from '../lib/provider-stack';

describe('ProviderStack', () => {
  test('creates ECS cluster and service for API service', () => {
    const app = new cdk.App();
    const stack = new ProviderStack(app, 'TestStack', {
      environment: 'dev',
      serviceType: 'api-service',
    });

    const template = Template.fromStack(stack);

    // Check ECS cluster
    template.hasResourceProperties('AWS::ECS::Cluster', {
      ClusterName: 'api-service-dev-cluster',
    });

    // Check ECS service
    template.hasResourceProperties('AWS::ECS::Service', {
      LaunchType: 'FARGATE',
      DesiredCount: 1,
    });

    // Check Network Load Balancer
    template.hasResourceProperties('AWS::ElasticLoadBalancingV2::LoadBalancer', {
      Type: 'network',
    });

    // Check VPC Endpoint Service
    template.hasResourceProperties('AWS::EC2::VPCEndpointService', {
      AcceptanceRequired: true,
    });
  });

});
