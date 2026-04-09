import * as cdk from "aws-cdk-lib";
import * as apigateway from "aws-cdk-lib/aws-apigateway";
import * as cognito from "aws-cdk-lib/aws-cognito";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as iam from "aws-cdk-lib/aws-iam";
import * as kms from "aws-cdk-lib/aws-kms";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as s3 from "aws-cdk-lib/aws-s3";
import * as wafv2 from "aws-cdk-lib/aws-wafv2";
import { Construct } from "constructs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

interface ApiStackProps extends cdk.StackProps {
  userPool: cognito.IUserPool;
  kmsKey: kms.IKey;
  table: dynamodb.ITable;
  tableName: string;
}

export class ApiStack extends cdk.Stack {
  public readonly api: apigateway.IRestApi;
  public readonly miraFunction: lambda.Function;
  public readonly syncFunction: lambda.Function;
  public readonly reportFunction: lambda.Function;

  constructor(scope: Construct, id: string, props: ApiStackProps) {
    super(scope, id, props);

    const apiId = this.node.tryGetContext("apiGatewayRestApiId");
    this.api = apigateway.RestApi.fromRestApiId(this, "ImportedApi", apiId);

    // S3 bucket for provider reports
    const reportBucket = new s3.Bucket(this, "ReportBucket", {
      bucketName: `memoryaisle-reports-${this.account}`,
      encryption: s3.BucketEncryption.S3_MANAGED,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      lifecycleRules: [{ expiration: cdk.Duration.days(30) }],
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
    });

    // Lambda directory (relative to CDK project root)
    const lambdaDir = path.join(__dirname, "..", "..", "lambda");

    // --- miraGenerate Lambda ---
    this.miraFunction = new lambda.Function(this, "MiraGenerate", {
      runtime: lambda.Runtime.NODEJS_22_X,
      handler: "index.handler",
      code: lambda.Code.fromAsset(path.join(lambdaDir, "miraGenerate")),
      timeout: cdk.Duration.seconds(30),
      memorySize: 256,
    });

    this.miraFunction.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["bedrock:InvokeModel"],
        resources: [
          `arn:aws:bedrock:us-east-1::foundation-model/us.anthropic.claude-sonnet-4-20250514-v1:0`,
        ],
      })
    );

    // --- syncData Lambda ---
    this.syncFunction = new lambda.Function(this, "SyncData", {
      runtime: lambda.Runtime.NODEJS_22_X,
      handler: "index.handler",
      code: lambda.Code.fromAsset(path.join(lambdaDir, "syncData")),
      timeout: cdk.Duration.seconds(15),
      memorySize: 256,
      environment: {
        TABLE_NAME: props.tableName,
        KMS_KEY_ARN: props.kmsKey.keyArn,
      },
    });

    props.table.grantReadWriteData(this.syncFunction);
    props.kmsKey.grantEncryptDecrypt(this.syncFunction);

    // --- providerReport Lambda ---
    this.reportFunction = new lambda.Function(this, "ProviderReport", {
      runtime: lambda.Runtime.NODEJS_22_X,
      handler: "index.handler",
      code: lambda.Code.fromAsset(
        path.join(lambdaDir, "providerReport")
      ),
      timeout: cdk.Duration.seconds(30),
      memorySize: 512,
      environment: {
        TABLE_NAME: props.tableName,
        KMS_KEY_ARN: props.kmsKey.keyArn,
        REPORT_BUCKET: reportBucket.bucketName,
      },
    });

    props.table.grantReadData(this.reportFunction);
    props.kmsKey.grantDecrypt(this.reportFunction);
    reportBucket.grantWrite(this.reportFunction);

    // --- WAF ---
    const webAcl = new wafv2.CfnWebACL(this, "ApiWaf", {
      defaultAction: { allow: {} },
      scope: "REGIONAL",
      visibilityConfig: {
        cloudWatchMetricsEnabled: true,
        metricName: "MemoryAisleApiWaf",
        sampledRequestsEnabled: true,
      },
      rules: [
        {
          name: "RateLimit",
          priority: 1,
          action: { block: {} },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: "RateLimit",
            sampledRequestsEnabled: true,
          },
          statement: {
            rateBasedStatement: {
              limit: 600,
              aggregateKeyType: "IP",
            },
          },
        },
        {
          name: "AWSManagedSQLi",
          priority: 2,
          overrideAction: { none: {} },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: "SQLi",
            sampledRequestsEnabled: true,
          },
          statement: {
            managedRuleGroupStatement: {
              vendorName: "AWS",
              name: "AWSManagedRulesSQLiRuleSet",
            },
          },
        },
        {
          name: "AWSManagedKnownBadInputs",
          priority: 3,
          overrideAction: { none: {} },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: "BadInputs",
            sampledRequestsEnabled: true,
          },
          statement: {
            managedRuleGroupStatement: {
              vendorName: "AWS",
              name: "AWSManagedRulesKnownBadInputsRuleSet",
            },
          },
        },
      ],
    });

    // Associate WAF with API Gateway stage
    new wafv2.CfnWebACLAssociation(this, "WafAssociation", {
      resourceArn: `arn:aws:apigateway:us-east-1::/restapis/${apiId}/stages/prod`,
      webAclArn: webAcl.attrArn,
    });
  }
}
