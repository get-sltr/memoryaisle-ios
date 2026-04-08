# CDK Infrastructure Design -- MemoryAisle

**Date:** 2026-04-08
**Status:** Approved
**Approach:** Import existing manually-deployed resources + extend with security hardening

---

## Context

MemoryAisle has a working backend deployed manually to AWS:
- API Gateway: `https://9n2u3mkkma.execute-api.us-east-1.amazonaws.com/prod/`
- Lambda: `miraGenerate` (Bedrock Claude Sonnet for Mira AI)
- Lambda: `syncData` (DynamoDB push/pull/delete for cloud sync)
- DynamoDB: `memoryaisle-user-data` (single table, partition key: userId, sort key: dataType)
- Cognito: user pool for email/password auth

What's missing: CDK project, KMS encryption, WAF, CORS lockdown, provider report Lambda, monitoring, and the zero-knowledge context update on the Lambda side.

---

## Architecture

4 CDK stacks with explicit dependency ordering via cross-stack references.

```
Deploy order:
  1. AuthStack  (exports: userPoolId, userPoolArn)
  2. DataStack  (exports: kmsKeyArn, tableArn, tableName)
  3. ApiStack   (imports from AuthStack + DataStack)
  4. MonitoringStack (imports from all three)
```

### Stack 1: AuthStack

**Purpose:** Import and configure Cognito.

- Import existing Cognito user pool by ID (do NOT recreate)
- Configure token expiry: 15-min access, 30-day refresh
- Export `userPoolId` and `userPoolArn` as CfnOutputs
- Apple Sign In provider configuration is done in Cognito console (not CDK -- requires App Store team setup with Apple Developer account)

**Resources:**
- `aws_cognito.UserPool` (imported)

### Stack 2: DataStack

**Purpose:** DynamoDB table + KMS for TIER 1 encryption.

- Import existing DynamoDB table `memoryaisle-user-data`
- Create KMS CMK: `alias/memoryaisle-health-data-{env}`
  - Automatic annual rotation enabled
  - Key policy: only the API Lambda execution role can call `kms:Decrypt` and `kms:GenerateDataKey`
  - No human IAM user gets decrypt in prod
- Enable CloudTrail logging for all KMS API calls
- Export `kmsKeyArn`, `tableArn`, `tableName`

**Resources:**
- `aws_dynamodb.Table` (imported)
- `aws_kms.Key`
- `aws_kms.Alias`

### Stack 3: ApiStack

**Purpose:** API Gateway, Lambdas, WAF, CORS.

**Imports from other stacks:**
- `AuthStack.userPoolId` -- for Cognito authorizer
- `DataStack.kmsKeyArn` -- for Lambda KMS access
- `DataStack.tableName` -- for Lambda DynamoDB access

**API Gateway:**
- Import existing REST API by ID
- Cognito authorizer on all routes
- CORS: `memoryaisle.app` origin only (plus localhost for dev)

**Lambdas (3 total):**

1. **miraGenerate** (existing, updated)
   - Runtime: Node.js 22.x
   - Bedrock `InvokeModel` permission (Claude Sonnet)
   - Update context parsing to use anonymized fields (`medicationClass`, `doseTier`, `daysSinceDose`, `phase`, `symptomState`) instead of raw medication names
   - 30-second timeout, 256MB memory
   - No DynamoDB or KMS access (Mira never persists data)

2. **syncData** (existing, updated)
   - Runtime: Node.js 22.x
   - DynamoDB read/write permission
   - KMS `GenerateDataKey` + `Decrypt` permission
   - Envelope encryption: before writing TIER 1 data types (`medicationProfile`, `symptomLogs`, `bodyComposition`, `providerReports`), generate a data key from KMS, encrypt the `data` field with AES-256-GCM, store ciphertext + encrypted data key
   - On read: decrypt the data key via KMS, decrypt ciphertext, return plaintext to client
   - TIER 2 data (`nutritionLogs`, `mealPlans`, `groceryLists`, `pantryItems`, `profile`) stored as plaintext JSON (DynamoDB SSE-KMS handles at-rest encryption)
   - 15-second timeout, 256MB memory

3. **providerReport** (new)
   - Runtime: Node.js 22.x
   - Generates weekly PDF report from user's nutrition/symptom data
   - DynamoDB read permission
   - KMS decrypt permission (needs to read TIER 1 symptom data)
   - S3 write permission (uploads PDF to report bucket)
   - 30-second timeout, 512MB memory

**WAF (WebACL):**
- Rate limit: 100 requests/minute per IP
- AWS managed rule groups: SQL injection, XSS, known bad inputs
- Associate with API Gateway stage

**Resources:**
- `aws_apigateway.RestApi` (imported)
- `aws_lambda.Function` x 3
- `aws_iam.Role` (Lambda execution role with scoped permissions)
- `aws_wafv2.WebAcl`
- `aws_wafv2.WebAclAssociation`
- `aws_s3.Bucket` (provider report PDFs, encrypted, lifecycle: delete after 30 days)

### Stack 4: MonitoringStack

**Purpose:** Alarms, logging, threat detection.

**CloudWatch Alarms:**
- KMS decrypt call volume > 1000/hour (anomaly detection)
- API Gateway 5xx error rate > 5%
- Cognito failed authentication > 50/hour
- Lambda error rate > 10%
- DynamoDB throttled requests > 0

**CloudTrail:**
- Trail enabled for all management events
- S3 bucket for log storage (encrypted, lifecycle: 90 days)

**GuardDuty:**
- Enable for the account (if not already)

**SNS Topic:**
- Alert notifications (email to kevin@sltrdigital.com)

**Resources:**
- `aws_cloudwatch.Alarm` x 5
- `aws_cloudtrail.Trail`
- `aws_guardduty.Detector`
- `aws_sns.Topic`
- `aws_s3.Bucket` (CloudTrail logs)

---

## Lambda: syncData KMS Encryption Flow

```
WRITE (push):
  1. Parse request body: { dataType, data, timestamp }
  2. Check if dataType is TIER 1: medicationProfile, symptomLogs, bodyComposition, providerReports
  3. If TIER 1:
     a. Call KMS GenerateDataKey (keyId = CMK ARN, keySpec = AES_256)
     b. Receive: { Plaintext: dataKey, CiphertextBlob: encryptedDataKey }
     c. Encrypt data with dataKey using AES-256-GCM (Node crypto)
     d. Store in DynamoDB: { userId, dataType, encryptedData, encryptedDataKey, iv, authTag, updatedAt }
     e. Wipe plaintext dataKey from memory
  4. If TIER 2: store as-is (JSON string)

READ (pull):
  1. Query DynamoDB by userId + dataType
  2. If item has encryptedDataKey field (TIER 1):
     a. Call KMS Decrypt (CiphertextBlob = encryptedDataKey)
     b. Receive plaintext dataKey
     c. Decrypt encryptedData with dataKey using AES-256-GCM
     d. Return plaintext to client
     e. Wipe dataKey from memory
  3. If no encryptedDataKey (TIER 2): return data as-is
```

---

## Lambda: miraGenerate Context Update

Current context parsing reads `context.medication` (raw brand name like "Ozempic").

Update to read anonymized fields matching the iOS `MedicationAnonymizer` output:
- `context.medicationClass` (e.g., "glp1_agonist_semaglutide_class")
- `context.doseTier` (e.g., "low", "medium", "high")
- `context.daysSinceDose` (integer)
- `context.phase` (e.g., "appetite_suppression", "steady")
- `context.symptomState` (e.g., "mild_nausea")
- `context.trainingToday` (boolean)
- `context.calorieTarget` (integer)
- `context.dietaryRestrictions` (string array)

System prompt userContext block changes from brand names to anonymous descriptors.

---

## CDK Project Structure

```
Infrastructure/
  CDK/
    bin/
      app.ts                   # CDK app entry point
    lib/
      auth-stack.ts            # Stack 1
      data-stack.ts            # Stack 2
      api-stack.ts             # Stack 3
      monitoring-stack.ts      # Stack 4
    lambda/
      miraGenerate/
        index.mjs              # Updated with anonymized context
      syncData/
        index.mjs              # Updated with KMS envelope encryption
      providerReport/
        index.mjs              # New: PDF generation
    cdk.json
    package.json
    tsconfig.json
```

---

## Environment Configuration

```typescript
const env = {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: 'us-east-1',
};

// Existing resource IDs (imported, not created)
const existingResources = {
  cognitoUserPoolId: 'us-east-1_XXXXXXXXX',  // from AWS console
  apiGatewayRestApiId: '9n2u3mkkma',
  dynamoTableName: 'memoryaisle-user-data',
};
```

These IDs will be stored in `cdk.context.json` or environment variables. Never in source code.

---

## Security Constraints

- KMS key rotation: automatic, annual
- Lambda execution role: least-privilege (only DynamoDB + KMS actions needed)
- No `*` resources in IAM policies
- CORS: locked to `memoryaisle.app` (and `localhost:3000` in dev)
- WAF blocks before request hits Lambda
- All S3 buckets: block public access, SSE-S3 encryption, versioning disabled
- CloudTrail: cannot be disabled without alarm

---

## What This Does NOT Include (deferred)

- Aurora Serverless v2 (Phase 2, when relational queries are needed)
- AppStore server notifications Lambda (add when StoreKit 2 server-side validation is needed)
- CI/CD pipeline (Xcode Cloud or GitHub Actions -- separate concern)
- Custom domain for API Gateway (can add later with Route 53 + ACM)
- VPC (Lambdas run in default VPC-less mode; add VPC when Aurora is introduced)
