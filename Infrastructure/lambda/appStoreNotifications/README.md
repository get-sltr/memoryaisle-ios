# App Store Server Notifications Handler

Receives signed notification payloads from Apple (renewal, refund,
cancellation, refund-reversal, etc.) and logs each event into the
shared DynamoDB table keyed by `originalTransactionId`.

## Pre-deploy steps (manual, one-time)

1. **Download Apple Root CA G3** into this directory so the handler
   can verify notification signatures offline:
   ```
   curl -o Infrastructure/lambda/appStoreNotifications/AppleRootCA-G3.cer \
     https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
   ```
   The handler looks for this file by name at cold start. If absent it
   rejects every notification, so confirm the file is present before
   uploading.

2. **Install the npm dependency** (first lambda in this project to
   carry a `node_modules/` tree — the folder must be included in the
   lambda asset that CDK zips):
   ```
   cd Infrastructure/lambda/appStoreNotifications
   npm install --omit=dev
   ```

3. **Capture the App Store app id** from App Store Connect
   (App Information → General → Apple ID, a numeric string) and pass
   it to CDK as context:
   ```
   cd Infrastructure/CDK
   npx cdk deploy MemoryAisle-Api \
     --context appleAppAppleId=1234567890
   ```
   Leaving it empty relaxes the per-app check in the signature
   verifier; set it once the app is live.

## Post-deploy steps (manual, one-time)

Routes for every lambda in this project are wired by hand in the API
Gateway console. Do the same for this one:

1. API Gateway console → MemoryAisle REST API → **Resources** →
   Create resource `/apple/notifications`.
2. Add method **POST**, integration type **Lambda Proxy**, target
   `AppStoreNotifications` function.
3. Deploy the API to the `prod` stage.
4. Copy the invoke URL, e.g.
   `https://9n2u3mkkma.execute-api.us-east-1.amazonaws.com/prod/apple/notifications`.
5. App Store Connect → App → **App Information** → App Store Server
   Notifications:
   - Paste into **Sandbox Server URL** first. Run sandbox purchase /
     cancel / refund flows via TestFlight and confirm entries appear
     in DynamoDB (`SUB#<originalTransactionId>` items) and in
     CloudWatch logs.
   - Only after sandbox is green, paste into **Production Server URL**.

## Limitations (follow-up work)

- Events are stored by `originalTransactionId`, not by user. The
  iOS client now passes `appAccountToken` (the Cognito `sub` UUID)
  on purchase, and it lands on each event in DynamoDB. A future
  `/subscription/link` endpoint should denormalise this into a
  per-user subscription-state item so widgets and provider reports
  can read entitlement without scanning every event.
- No SQS buffering. If DynamoDB throttles, Apple will retry (that is
  fine) but processing is synchronous. Consider SQS if notification
  volume grows.
- OCSP revocation checks are disabled. Offline chain validation
  against Apple Root CA G3 is sufficient today; revisit if Apple
  publishes guidance or rotates a leaf cert early.
