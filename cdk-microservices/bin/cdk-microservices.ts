import { App } from "aws-cdk-lib";
import { MicroservicesStack } from "../lib/microservices-stack";

const app = new App();

// These context values can be passed with `cdk deploy -c` or set in cdk.json
const vpcId = app.node.tryGetContext("vpcId");
const publicSubnetIds = app.node.tryGetContext("publicSubnetIds");
const privateSubnetIds = app.node.tryGetContext("privateSubnetIds");

new MicroservicesStack(app, "MicroservicesStack", {
    vpcId,
    publicSubnetIds,
    privateSubnetIds,
    env: { region: "us-east-1" }
});
