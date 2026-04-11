import * as cdk from "aws-cdk-lib";
import * as apigateway from "aws-cdk-lib/aws-apigateway";
import * as cloudwatch from "aws-cdk-lib/aws-cloudwatch";
import * as cloudwatch_actions from "aws-cdk-lib/aws-cloudwatch-actions";
import * as cloudtrail from "aws-cdk-lib/aws-cloudtrail";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as s3 from "aws-cdk-lib/aws-s3";
import * as sns from "aws-cdk-lib/aws-sns";
import * as sns_subscriptions from "aws-cdk-lib/aws-sns-subscriptions";
import { Construct } from "constructs";

interface MonitoringStackProps extends cdk.StackProps {
  api: apigateway.IRestApi;
  miraFunction: lambda.Function;
  miraSpeakFunction: lambda.Function;
  syncFunction: lambda.Function;
  reportFunction: lambda.Function;
  alertEmail: string;
}

export class MonitoringStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: MonitoringStackProps) {
    super(scope, id, props);

    // SNS alert topic
    const alertTopic = new sns.Topic(this, "AlertTopic", {
      topicName: "memoryaisle-alerts",
    });
    alertTopic.addSubscription(
      new sns_subscriptions.EmailSubscription(props.alertEmail)
    );

    // CloudTrail
    const trailBucket = new s3.Bucket(this, "TrailBucket", {
      bucketName: `memoryaisle-cloudtrail-${this.account}`,
      encryption: s3.BucketEncryption.S3_MANAGED,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      lifecycleRules: [{ expiration: cdk.Duration.days(90) }],
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
    });

    new cloudtrail.Trail(this, "ApiTrail", {
      trailName: "memoryaisle-trail",
      bucket: trailBucket,
      isMultiRegionTrail: false,
      includeGlobalServiceEvents: true,
    });

    // GuardDuty - already enabled on this account, skip creation

    // Lambda error alarms
    const lambdaAlarm = (name: string, fn: lambda.Function) => {
      const alarm = new cloudwatch.Alarm(this, `${name}ErrorAlarm`, {
        alarmName: `memoryaisle-${name}-errors`,
        metric: fn.metricErrors({ period: cdk.Duration.minutes(5) }),
        threshold: 5,
        evaluationPeriods: 2,
        comparisonOperator:
          cloudwatch.ComparisonOperator
            .GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
      });
      alarm.addAlarmAction(new cloudwatch_actions.SnsAction(alertTopic));
      return alarm;
    };

    lambdaAlarm("mira", props.miraFunction);
    lambdaAlarm("miraSpeak", props.miraSpeakFunction);
    lambdaAlarm("sync", props.syncFunction);
    lambdaAlarm("report", props.reportFunction);

    // API Gateway 5xx alarm
    const api5xxAlarm = new cloudwatch.Alarm(this, "Api5xxAlarm", {
      alarmName: "memoryaisle-api-5xx",
      metric: new cloudwatch.Metric({
        namespace: "AWS/ApiGateway",
        metricName: "5XXError",
        dimensionsMap: { ApiName: "memoryaisle-api" },
        period: cdk.Duration.minutes(5),
        statistic: "Sum",
      }),
      threshold: 10,
      evaluationPeriods: 2,
    });
    api5xxAlarm.addAlarmAction(
      new cloudwatch_actions.SnsAction(alertTopic)
    );

    // DynamoDB throttle alarm
    const throttleAlarm = new cloudwatch.Alarm(this, "DynamoThrottle", {
      alarmName: "memoryaisle-dynamo-throttle",
      metric: new cloudwatch.Metric({
        namespace: "AWS/DynamoDB",
        metricName: "ThrottledRequests",
        dimensionsMap: { TableName: "memoryaisle-user-data" },
        period: cdk.Duration.minutes(5),
        statistic: "Sum",
      }),
      threshold: 1,
      evaluationPeriods: 1,
    });
    throttleAlarm.addAlarmAction(
      new cloudwatch_actions.SnsAction(alertTopic)
    );
  }
}
