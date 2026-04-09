#!/usr/bin/env node
import "source-map-support/register.js";
import * as cdk from "aws-cdk-lib";
import { AuthStack } from "../lib/auth-stack.js";
import { DataStack } from "../lib/data-stack.js";
import { ApiStack } from "../lib/api-stack.js";
import { MonitoringStack } from "../lib/monitoring-stack.js";

const app = new cdk.App();

const env = {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: "us-east-1",
};

const authStack = new AuthStack(app, "MemoryAisle-Auth", { env });

const dataStack = new DataStack(app, "MemoryAisle-Data", { env });

const apiStack = new ApiStack(app, "MemoryAisle-Api", {
  env,
  userPool: authStack.userPool,
  kmsKey: dataStack.kmsKey,
  table: dataStack.table,
  tableName: dataStack.tableName,
});

new MonitoringStack(app, "MemoryAisle-Monitoring", {
  env,
  api: apiStack.api,
  miraFunction: apiStack.miraFunction,
  syncFunction: apiStack.syncFunction,
  reportFunction: apiStack.reportFunction,
  alertEmail: app.node.tryGetContext("alertEmail"),
});

app.synth();
