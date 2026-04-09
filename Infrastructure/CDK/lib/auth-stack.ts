import * as cdk from "aws-cdk-lib";
import * as cognito from "aws-cdk-lib/aws-cognito";
import { Construct } from "constructs";

export class AuthStack extends cdk.Stack {
  public readonly userPool: cognito.IUserPool;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const userPoolId = this.node.tryGetContext("cognitoUserPoolId");

    this.userPool = cognito.UserPool.fromUserPoolId(
      this,
      "ImportedUserPool",
      userPoolId
    );

    new cdk.CfnOutput(this, "UserPoolId", {
      value: this.userPool.userPoolId,
      exportName: "MemoryAisle-UserPoolId",
    });

    new cdk.CfnOutput(this, "UserPoolArn", {
      value: this.userPool.userPoolArn,
      exportName: "MemoryAisle-UserPoolArn",
    });
  }
}
