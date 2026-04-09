import * as cdk from "aws-cdk-lib";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as kms from "aws-cdk-lib/aws-kms";
import { Construct } from "constructs";

export class DataStack extends cdk.Stack {
  public readonly table: dynamodb.ITable;
  public readonly tableName: string;
  public readonly kmsKey: kms.IKey;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const dynamoTableName = this.node.tryGetContext("dynamoTableName");
    this.tableName = dynamoTableName;

    this.table = dynamodb.Table.fromTableName(
      this,
      "ImportedTable",
      dynamoTableName
    );

    const environment = this.node.tryGetContext("environment") || "prod";

    this.kmsKey = new kms.Key(this, "HealthDataKey", {
      alias: `memoryaisle-health-data-${environment}`,
      description:
        "Encrypts TIER 1 health data (medication, symptoms, body composition)",
      enableKeyRotation: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    new cdk.CfnOutput(this, "KmsKeyArn", {
      value: this.kmsKey.keyArn,
      exportName: "MemoryAisle-KmsKeyArn",
    });

    new cdk.CfnOutput(this, "TableArn", {
      value: this.table.tableArn,
      exportName: "MemoryAisle-TableArn",
    });

    new cdk.CfnOutput(this, "TableName", {
      value: this.tableName,
      exportName: "MemoryAisle-TableName",
    });
  }
}
