# CDK Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a CDK project that imports existing AWS resources and adds KMS encryption, WAF, monitoring, and a provider report Lambda.

**Architecture:** 4 CDK stacks (Auth, Data, API, Monitoring) with cross-stack references. Import existing Cognito, API Gateway, and DynamoDB. Add KMS CMK for TIER 1 envelope encryption. Update Lambda code for zero-knowledge context and encryption.

**Tech Stack:** AWS CDK v2 (TypeScript), Node.js 22.x Lambdas (ESM), KMS, WAF v2, CloudWatch, CloudTrail, GuardDuty, S3

---

## File Map

```
Infrastructure/CDK/
  bin/app.ts                          # CDK app entry, instantiates all 4 stacks
  lib/auth-stack.ts                   # Import Cognito, export pool ID/ARN
  lib/data-stack.ts                   # Import DynamoDB, create KMS CMK
  lib/api-stack.ts                    # Lambdas, WAF, S3 report bucket
  lib/monitoring-stack.ts             # CloudWatch alarms, CloudTrail, GuardDuty, SNS
  cdk.json                            # CDK config
  package.json                        # Dependencies
  tsconfig.json                       # TypeScript config

Infrastructure/lambda/miraGenerate/
  index.mjs                           # Updated: anonymized context fields

Infrastructure/lambda/syncData/
  index.mjs                           # Updated: KMS envelope encryption

Infrastructure/lambda/providerReport/
  index.mjs                           # New: PDF generation + S3 upload
```

---

### Task 1: Scaffold CDK Project

**Files:**
- Create: `Infrastructure/CDK/bin/app.ts`
- Create: `Infrastructure/CDK/package.json`
- Create: `Infrastructure/CDK/tsconfig.json`
- Create: `Infrastructure/CDK/cdk.json`

- [ ] **Step 1: Initialize package.json**

```json
{
  "name": "memoryaisle-infra",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc",
    "cdk": "cdk",
    "synth": "cdk synth",
    "deploy": "cdk deploy --all",
    "diff": "cdk diff"
  },
  "dependencies": {
    "aws-cdk-lib": "^2.180.0",
    "constructs": "^10.4.0"
  },
  "devDependencies": {
    "typescript": "^5.7.0",
    "aws-cdk": "^2.180.0"
  }
}
```

Write this to `Infrastructure/CDK/package.json`.

- [ ] **Step 2: Create tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "lib": ["ES2022"],
    "outDir": "dist",
    "rootDir": ".",
    "strict": true,
    "noImplicitAny": true,
    "declaration": true,
    "sourceMap": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["bin/**/*", "lib/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

Write to `Infrastructure/CDK/tsconfig.json`.

- [ ] **Step 3: Create cdk.json**

```json
{
  "app": "npx ts-node --esm bin/app.ts",
  "context": {
    "cognitoUserPoolId": "us-east-1_8jluiv1HL",
    "apiGatewayRestApiId": "9n2u3mkkma",
    "dynamoTableName": "memoryaisle-user-data",
    "alertEmail": "kevin@sltrdigital.com",
    "environment": "prod"
  }
}
```

Write to `Infrastructure/CDK/cdk.json`.

- [ ] **Step 4: Create app entry point**

```typescript
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
```

Write to `Infrastructure/CDK/bin/app.ts`.

- [ ] **Step 5: Install dependencies**

Run: `cd Infrastructure/CDK && npm install`
Expected: `node_modules/` created, no errors.

- [ ] **Step 6: Commit**

```bash
git add Infrastructure/CDK/package.json Infrastructure/CDK/tsconfig.json Infrastructure/CDK/cdk.json Infrastructure/CDK/bin/app.ts
git commit -m "[infra] Scaffold CDK project with 4-stack architecture"
```

---

### Task 2: AuthStack

**Files:**
- Create: `Infrastructure/CDK/lib/auth-stack.ts`

- [ ] **Step 1: Write AuthStack**

```typescript
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
```

Write to `Infrastructure/CDK/lib/auth-stack.ts`.

- [ ] **Step 2: Verify TypeScript compiles**

Run: `cd Infrastructure/CDK && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add Infrastructure/CDK/lib/auth-stack.ts
git commit -m "[infra] AuthStack - import existing Cognito user pool"
```

---

### Task 3: DataStack

**Files:**
- Create: `Infrastructure/CDK/lib/data-stack.ts`

- [ ] **Step 1: Write DataStack**

```typescript
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
```

Write to `Infrastructure/CDK/lib/data-stack.ts`.

- [ ] **Step 2: Verify TypeScript compiles**

Run: `cd Infrastructure/CDK && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add Infrastructure/CDK/lib/data-stack.ts
git commit -m "[infra] DataStack - import DynamoDB + create KMS CMK for TIER 1 encryption"
```

---

### Task 4: Update miraGenerate Lambda for anonymized context

**Files:**
- Modify: `Infrastructure/lambda/miraGenerate/index.mjs`

- [ ] **Step 1: Rewrite miraGenerate with anonymized context**

```javascript
import {
  BedrockRuntimeClient,
  InvokeModelCommand,
} from "@aws-sdk/client-bedrock-runtime";

const client = new BedrockRuntimeClient({ region: "us-east-1" });

const SYSTEM_PROMPT = `You are Mira, the AI nutrition companion inside the MemoryAisle app. You help GLP-1 medication users lose fat without losing muscle.

Your personality:
- Warm, supportive, knowledgeable but never clinical
- You're a companion, not a doctor
- Acknowledge uncertainty explicitly
- Never recommend starting, stopping, or changing medication
- Always defer to "talk to your prescriber" for medical questions
- Never reference specific brand names of medications
- Never ask for or reference the user's real name

Your expertise:
- Protein-first nutrition for body composition on GLP-1s
- Symptom-adaptive eating (nausea, food aversion, low appetite)
- Meal planning around medication cycles (injectable and oral)
- Grocery shopping guidance with GLP-1 context
- Training-day vs rest-day nutrition
- Hydration (GLP-1s suppress thirst)
- Maintenance and taper nutrition

Keep responses concise (2-4 sentences unless the user asks for detail). Use specific numbers when possible (grams of protein, portion sizes). Never use em dashes.`;

export const handler = async (event) => {
  const body = JSON.parse(event.body || "{}");
  const { message, context } = body;

  if (!message) {
    return {
      statusCode: 400,
      headers: corsHeaders(),
      body: JSON.stringify({ error: "Message is required" }),
    };
  }

  const userContext = context
    ? buildAnonymizedContext(context)
    : "";

  try {
    const command = new InvokeModelCommand({
      modelId: "us.anthropic.claude-sonnet-4-20250514-v1:0",
      contentType: "application/json",
      accept: "application/json",
      body: JSON.stringify({
        anthropic_version: "bedrock-2023-05-31",
        max_tokens: 512,
        system: SYSTEM_PROMPT + userContext,
        messages: [{ role: "user", content: message }],
      }),
    });

    const response = await client.send(command);
    const result = JSON.parse(new TextDecoder().decode(response.body));
    const reply =
      result.content?.[0]?.text ||
      "I'm having trouble right now. Try again in a moment.";

    return {
      statusCode: 200,
      headers: corsHeaders(),
      body: JSON.stringify({ reply }),
    };
  } catch (error) {
    console.error("Bedrock error:", error);
    return {
      statusCode: 500,
      headers: corsHeaders(),
      body: JSON.stringify({
        error: "Mira is temporarily unavailable. Please try again.",
      }),
    };
  }
};

function buildAnonymizedContext(ctx) {
  const lines = ["\n\nUser context (anonymized):"];
  if (ctx.medicationClass)
    lines.push(`- Medication class: ${ctx.medicationClass}`);
  if (ctx.doseTier) lines.push(`- Dose tier: ${ctx.doseTier}`);
  if (ctx.daysSinceDose != null)
    lines.push(`- Days since dose: ${ctx.daysSinceDose}`);
  if (ctx.phase) lines.push(`- Cycle phase: ${ctx.phase}`);
  if (ctx.symptomState)
    lines.push(`- Symptom state: ${ctx.symptomState}`);
  if (ctx.mode) lines.push(`- Mode: ${ctx.mode}`);
  if (ctx.proteinTarget)
    lines.push(`- Protein target: ${ctx.proteinTarget}g`);
  if (ctx.proteinToday != null)
    lines.push(`- Protein today: ${ctx.proteinToday}g`);
  if (ctx.waterToday != null)
    lines.push(`- Water today: ${ctx.waterToday}L`);
  if (ctx.trainingLevel)
    lines.push(`- Training level: ${ctx.trainingLevel}`);
  if (ctx.trainingToday != null)
    lines.push(`- Training today: ${ctx.trainingToday}`);
  if (ctx.calorieTarget)
    lines.push(`- Calorie target: ${ctx.calorieTarget}`);
  if (ctx.dietaryRestrictions?.length)
    lines.push(
      `- Dietary restrictions: ${ctx.dietaryRestrictions.join(", ")}`
    );
  return lines.join("\n");
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "https://memoryaisle.app",
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "POST,OPTIONS",
    "Content-Type": "application/json",
  };
}
```

Write to `Infrastructure/lambda/miraGenerate/index.mjs` (replaces existing file).

- [ ] **Step 2: Commit**

```bash
git add Infrastructure/lambda/miraGenerate/index.mjs
git commit -m "[infra] miraGenerate Lambda - anonymized context, locked CORS"
```

---

### Task 5: Update syncData Lambda with KMS envelope encryption

**Files:**
- Modify: `Infrastructure/lambda/syncData/index.mjs`

- [ ] **Step 1: Rewrite syncData with KMS envelope encryption**

```javascript
import {
  DynamoDBClient,
  PutItemCommand,
  QueryCommand,
  DeleteItemCommand,
} from "@aws-sdk/client-dynamodb";
import { marshall, unmarshall } from "@aws-sdk/util-dynamodb";
import {
  KMSClient,
  GenerateDataKeyCommand,
  DecryptCommand,
} from "@aws-sdk/client-kms";
import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";

const db = new DynamoDBClient({ region: "us-east-1" });
const kms = new KMSClient({ region: "us-east-1" });
const TABLE = process.env.TABLE_NAME || "memoryaisle-user-data";
const KMS_KEY_ARN = process.env.KMS_KEY_ARN;

const TIER1_TYPES = new Set([
  "medicationProfile",
  "symptomLogs",
  "bodyComposition",
  "providerReports",
]);

export const handler = async (event) => {
  const method = event.httpMethod;
  const path = event.path;
  const body = event.body ? JSON.parse(event.body) : {};

  const userId =
    event.requestContext?.authorizer?.claims?.sub || body.userId;
  if (!userId) {
    return response(401, { error: "Unauthorized" });
  }

  try {
    if (method === "POST" && path === "/sync/push") {
      return await pushData(userId, body);
    }
    if (method === "GET" && path === "/sync/pull") {
      return await pullData(userId, event.queryStringParameters);
    }
    if (method === "DELETE" && path === "/sync/delete-account") {
      return await deleteAllUserData(userId);
    }
    return response(404, { error: "Not found" });
  } catch (error) {
    console.error("Sync error:", error);
    return response(500, { error: "Sync failed" });
  }
};

async function pushData(userId, body) {
  const { dataType, data, timestamp } = body;
  if (!dataType || !data) {
    return response(400, { error: "dataType and data required" });
  }

  const updatedAt = timestamp || new Date().toISOString();

  if (TIER1_TYPES.has(dataType) && KMS_KEY_ARN) {
    const encrypted = await envelopeEncrypt(JSON.stringify(data));
    const item = {
      userId,
      dataType,
      encryptedData: encrypted.ciphertext,
      encryptedDataKey: encrypted.encryptedDataKey,
      iv: encrypted.iv,
      authTag: encrypted.authTag,
      updatedAt,
    };
    await db.send(
      new PutItemCommand({ TableName: TABLE, Item: marshall(item) })
    );
  } else {
    const item = {
      userId,
      dataType,
      data: JSON.stringify(data),
      updatedAt,
    };
    await db.send(
      new PutItemCommand({ TableName: TABLE, Item: marshall(item) })
    );
  }

  return response(200, { status: "synced", dataType });
}

async function pullData(userId, params) {
  const dataType = params?.dataType;

  const queryParams = {
    TableName: TABLE,
    KeyConditionExpression: dataType
      ? "userId = :uid AND dataType = :dt"
      : "userId = :uid",
    ExpressionAttributeValues: marshall(
      dataType ? { ":uid": userId, ":dt": dataType } : { ":uid": userId }
    ),
  };

  const result = await db.send(new QueryCommand(queryParams));
  const items = [];

  for (const raw of result.Items || []) {
    const item = unmarshall(raw);

    if (item.encryptedDataKey) {
      const plaintext = await envelopeDecrypt(
        item.encryptedData,
        item.encryptedDataKey,
        item.iv,
        item.authTag
      );
      items.push({
        dataType: item.dataType,
        data: JSON.parse(plaintext),
        updatedAt: item.updatedAt,
      });
    } else {
      items.push({
        dataType: item.dataType,
        data: JSON.parse(item.data),
        updatedAt: item.updatedAt,
      });
    }
  }

  return response(200, { items });
}

async function deleteAllUserData(userId) {
  const result = await db.send(
    new QueryCommand({
      TableName: TABLE,
      KeyConditionExpression: "userId = :uid",
      ExpressionAttributeValues: marshall({ ":uid": userId }),
    })
  );

  for (const item of result.Items || []) {
    const unmarshalled = unmarshall(item);
    await db.send(
      new DeleteItemCommand({
        TableName: TABLE,
        Key: marshall({
          userId: unmarshalled.userId,
          dataType: unmarshalled.dataType,
        }),
      })
    );
  }

  return response(200, {
    status: "all data deleted",
    itemsRemoved: (result.Items || []).length,
  });
}

async function envelopeEncrypt(plaintext) {
  const { Plaintext: dataKey, CiphertextBlob: encryptedDataKey } =
    await kms.send(
      new GenerateDataKeyCommand({
        KeyId: KMS_KEY_ARN,
        KeySpec: "AES_256",
      })
    );

  const iv = randomBytes(12);
  const cipher = createCipheriv(
    "aes-256-gcm",
    Buffer.from(dataKey),
    iv
  );

  let ciphertext = cipher.update(plaintext, "utf8", "base64");
  ciphertext += cipher.final("base64");
  const authTag = cipher.getAuthTag().toString("base64");

  // Wipe plaintext key from memory
  Buffer.from(dataKey).fill(0);

  return {
    ciphertext,
    encryptedDataKey: Buffer.from(encryptedDataKey).toString("base64"),
    iv: iv.toString("base64"),
    authTag,
  };
}

async function envelopeDecrypt(ciphertext, encryptedDataKey, iv, authTag) {
  const { Plaintext: dataKey } = await kms.send(
    new DecryptCommand({
      CiphertextBlob: Buffer.from(encryptedDataKey, "base64"),
    })
  );

  const decipher = createDecipheriv(
    "aes-256-gcm",
    Buffer.from(dataKey),
    Buffer.from(iv, "base64")
  );
  decipher.setAuthTag(Buffer.from(authTag, "base64"));

  let plaintext = decipher.update(ciphertext, "base64", "utf8");
  plaintext += decipher.final("utf8");

  // Wipe plaintext key from memory
  Buffer.from(dataKey).fill(0);

  return plaintext;
}

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      "Access-Control-Allow-Origin": "https://memoryaisle.app",
      "Access-Control-Allow-Headers": "Content-Type,Authorization",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  };
}
```

Write to `Infrastructure/lambda/syncData/index.mjs` (replaces existing file).

- [ ] **Step 2: Commit**

```bash
git add Infrastructure/lambda/syncData/index.mjs
git commit -m "[infra] syncData Lambda - KMS envelope encryption for TIER 1, locked CORS"
```

---

### Task 6: Create providerReport Lambda

**Files:**
- Create: `Infrastructure/lambda/providerReport/index.mjs`

- [ ] **Step 1: Write providerReport Lambda**

```javascript
import {
  DynamoDBClient,
  QueryCommand,
} from "@aws-sdk/client-dynamodb";
import { unmarshall } from "@aws-sdk/util-dynamodb";
import { marshall } from "@aws-sdk/util-dynamodb";
import {
  KMSClient,
  DecryptCommand,
} from "@aws-sdk/client-kms";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { createDecipheriv } from "node:crypto";

const db = new DynamoDBClient({ region: "us-east-1" });
const kms = new KMSClient({ region: "us-east-1" });
const s3 = new S3Client({ region: "us-east-1" });

const TABLE = process.env.TABLE_NAME || "memoryaisle-user-data";
const BUCKET = process.env.REPORT_BUCKET;

export const handler = async (event) => {
  const body = JSON.parse(event.body || "{}");
  const userId =
    event.requestContext?.authorizer?.claims?.sub || body.userId;

  if (!userId) {
    return response(401, { error: "Unauthorized" });
  }

  try {
    const nutritionLogs = await fetchData(userId, "nutritionLogs");
    const symptomLogs = await fetchDecryptedData(userId, "symptomLogs");

    const report = buildReport(nutritionLogs, symptomLogs);
    const html = renderReportHtml(report);

    const key = `reports/${userId}/${report.generatedAt}.html`;
    await s3.send(
      new PutObjectCommand({
        Bucket: BUCKET,
        Key: key,
        Body: html,
        ContentType: "text/html",
      })
    );

    return response(200, {
      report,
      exportUrl: `s3://${BUCKET}/${key}`,
    });
  } catch (error) {
    console.error("Report generation error:", error);
    return response(500, { error: "Could not generate report" });
  }
};

async function fetchData(userId, dataType) {
  const result = await db.send(
    new QueryCommand({
      TableName: TABLE,
      KeyConditionExpression: "userId = :uid AND dataType = :dt",
      ExpressionAttributeValues: marshall({
        ":uid": userId,
        ":dt": dataType,
      }),
    })
  );
  const items = (result.Items || []).map((i) => unmarshall(i));
  if (items.length === 0) return [];
  return JSON.parse(items[0].data || "[]");
}

async function fetchDecryptedData(userId, dataType) {
  const result = await db.send(
    new QueryCommand({
      TableName: TABLE,
      KeyConditionExpression: "userId = :uid AND dataType = :dt",
      ExpressionAttributeValues: marshall({
        ":uid": userId,
        ":dt": dataType,
      }),
    })
  );
  const items = (result.Items || []).map((i) => unmarshall(i));
  if (items.length === 0) return [];

  const item = items[0];
  if (item.encryptedDataKey) {
    const { Plaintext: dataKey } = await kms.send(
      new DecryptCommand({
        CiphertextBlob: Buffer.from(item.encryptedDataKey, "base64"),
      })
    );
    const decipher = createDecipheriv(
      "aes-256-gcm",
      Buffer.from(dataKey),
      Buffer.from(item.iv, "base64")
    );
    decipher.setAuthTag(Buffer.from(item.authTag, "base64"));
    let plaintext = decipher.update(item.encryptedData, "base64", "utf8");
    plaintext += decipher.final("utf8");
    Buffer.from(dataKey).fill(0);
    return JSON.parse(plaintext);
  }
  return JSON.parse(item.data || "[]");
}

function buildReport(nutritionLogs, symptomLogs) {
  const now = new Date();
  const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  const recentNutrition = (nutritionLogs || []).filter(
    (l) => new Date(l.date) >= weekAgo
  );
  const recentSymptoms = (symptomLogs || []).filter(
    (l) => new Date(l.date) >= weekAgo
  );

  const days = Math.max(1, recentNutrition.length);

  const avgProtein =
    recentNutrition.reduce((s, l) => s + (l.proteinGrams || 0), 0) / days;
  const avgCalories =
    recentNutrition.reduce((s, l) => s + (l.caloriesConsumed || 0), 0) /
    days;
  const avgWater =
    recentNutrition.reduce((s, l) => s + (l.waterLiters || 0), 0) / days;
  const avgNausea =
    recentSymptoms.length > 0
      ? recentSymptoms.reduce((s, l) => s + (l.nauseaLevel || 0), 0) /
        recentSymptoms.length
      : 0;
  const avgEnergy =
    recentSymptoms.length > 0
      ? recentSymptoms.reduce((s, l) => s + (l.energyLevel || 0), 0) /
        recentSymptoms.length
      : 0;

  return {
    generatedAt: now.toISOString(),
    periodStart: weekAgo.toISOString(),
    periodEnd: now.toISOString(),
    daysTracked: days,
    avgProteinGrams: Math.round(avgProtein),
    avgCalories: Math.round(avgCalories),
    avgWaterLiters: Math.round(avgWater * 10) / 10,
    avgNauseaLevel: Math.round(avgNausea * 10) / 10,
    avgEnergyLevel: Math.round(avgEnergy * 10) / 10,
    symptomDays: recentSymptoms.length,
  };
}

function renderReportHtml(report) {
  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>MemoryAisle Provider Report</title>
<style>body{font-family:system-ui;max-width:600px;margin:40px auto;color:#1f2937}
h1{color:#7C3AED}table{width:100%;border-collapse:collapse;margin:20px 0}
td,th{padding:8px 12px;border-bottom:1px solid #e5e7eb;text-align:left}
th{color:#6b7280;font-weight:500;font-size:13px}
td{font-size:15px}.disclaimer{color:#9ca3af;font-size:11px;margin-top:40px}</style></head>
<body>
<h1>MemoryAisle Weekly Report</h1>
<p>Period: ${report.periodStart.split("T")[0]} to ${report.periodEnd.split("T")[0]} (${report.daysTracked} days tracked)</p>
<table>
<tr><th>Metric</th><th>Average</th></tr>
<tr><td>Daily Protein</td><td>${report.avgProteinGrams}g</td></tr>
<tr><td>Daily Calories</td><td>${report.avgCalories}</td></tr>
<tr><td>Daily Water</td><td>${report.avgWaterLiters}L</td></tr>
<tr><td>Nausea Level</td><td>${report.avgNauseaLevel}/5</td></tr>
<tr><td>Energy Level</td><td>${report.avgEnergyLevel}/5</td></tr>
<tr><td>Symptom Days</td><td>${report.symptomDays}</td></tr>
</table>
<p class="disclaimer">Generated by MemoryAisle. This report is not medical advice. Share with your healthcare provider for context on your nutrition during GLP-1 treatment.</p>
</body></html>`;
}

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      "Access-Control-Allow-Origin": "https://memoryaisle.app",
      "Access-Control-Allow-Headers": "Content-Type,Authorization",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  };
}
```

Write to `Infrastructure/lambda/providerReport/index.mjs`.

- [ ] **Step 2: Commit**

```bash
git add Infrastructure/lambda/providerReport/index.mjs
git commit -m "[infra] providerReport Lambda - weekly HTML report with KMS decryption"
```

---

### Task 7: ApiStack

**Files:**
- Create: `Infrastructure/CDK/lib/api-stack.ts`

- [ ] **Step 1: Write ApiStack**

```typescript
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
      functionName: "memoryaisle-mira-generate",
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
      functionName: "memoryaisle-sync-data",
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
      functionName: "memoryaisle-provider-report",
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
    // Note: requires the stage ARN, which we construct from the imported API
    new wafv2.CfnWebACLAssociation(this, "WafAssociation", {
      resourceArn: `arn:aws:apigateway:us-east-1::/restapis/${apiId}/stages/prod`,
      webAclArn: webAcl.attrArn,
    });
  }
}
```

Write to `Infrastructure/CDK/lib/api-stack.ts`.

- [ ] **Step 2: Verify TypeScript compiles**

Run: `cd Infrastructure/CDK && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add Infrastructure/CDK/lib/api-stack.ts
git commit -m "[infra] ApiStack - 3 Lambdas, WAF, S3 report bucket, KMS permissions"
```

---

### Task 8: MonitoringStack

**Files:**
- Create: `Infrastructure/CDK/lib/monitoring-stack.ts`

- [ ] **Step 1: Write MonitoringStack**

```typescript
import * as cdk from "aws-cdk-lib";
import * as apigateway from "aws-cdk-lib/aws-apigateway";
import * as cloudwatch from "aws-cdk-lib/aws-cloudwatch";
import * as cloudwatch_actions from "aws-cdk-lib/aws-cloudwatch-actions";
import * as cloudtrail from "aws-cdk-lib/aws-cloudtrail";
import * as guardduty from "aws-cdk-lib/aws-guardduty";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as s3 from "aws-cdk-lib/aws-s3";
import * as sns from "aws-cdk-lib/aws-sns";
import * as sns_subscriptions from "aws-cdk-lib/aws-sns-subscriptions";
import { Construct } from "constructs";

interface MonitoringStackProps extends cdk.StackProps {
  api: apigateway.IRestApi;
  miraFunction: lambda.Function;
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

    // GuardDuty
    new guardduty.CfnDetector(this, "GuardDuty", {
      enable: true,
    });

    // Lambda error alarms
    const lambdaAlarm = (
      name: string,
      fn: lambda.Function
    ) => {
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
```

Write to `Infrastructure/CDK/lib/monitoring-stack.ts`.

- [ ] **Step 2: Verify TypeScript compiles**

Run: `cd Infrastructure/CDK && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add Infrastructure/CDK/lib/monitoring-stack.ts
git commit -m "[infra] MonitoringStack - CloudWatch alarms, CloudTrail, GuardDuty, SNS alerts"
```

---

### Task 9: Synthesize and validate

- [ ] **Step 1: Run CDK synth**

Run: `cd Infrastructure/CDK && npx cdk synth`
Expected: CloudFormation templates generated in `cdk.out/` for all 4 stacks without errors.

- [ ] **Step 2: Run CDK diff (if AWS credentials configured)**

Run: `cd Infrastructure/CDK && npx cdk diff`
Expected: shows planned changes for each stack. No destructive changes to existing resources.

- [ ] **Step 3: Commit cdk.out gitignore**

Add to `.gitignore`:
```
Infrastructure/CDK/cdk.out/
Infrastructure/CDK/node_modules/
Infrastructure/CDK/dist/
```

```bash
git add .gitignore
git commit -m "[infra] Add CDK build artifacts to gitignore"
```

---

### Task 10: Final commit and summary

- [ ] **Step 1: Verify all files are committed**

Run: `git status`
Expected: clean working tree.

- [ ] **Step 2: Tag the branch**

```bash
git log --oneline -10
```

Verify all infra commits are present.
