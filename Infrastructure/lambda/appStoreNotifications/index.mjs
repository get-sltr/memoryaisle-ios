import {
  SignedDataVerifier,
  Environment,
} from "@apple/app-store-server-library";
import {
  DynamoDBClient,
  PutItemCommand,
} from "@aws-sdk/client-dynamodb";
import { marshall } from "@aws-sdk/util-dynamodb";
import { readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const db = new DynamoDBClient({ region: "us-east-1" });
const TABLE = process.env.TABLE_NAME || "memoryaisle-user-data";
const BUNDLE_ID =
  process.env.APPLE_BUNDLE_ID || "com.sltrdigital.memoryaisle";
const APP_APPLE_ID = process.env.APPLE_APP_APPLE_ID
  ? BigInt(process.env.APPLE_APP_APPLE_ID)
  : undefined;

// Apple Root CA G3 (DER) bundled with the handler. See README for how
// to refresh this if Apple rotates the chain.
const ROOT_CERT_FILES = ["AppleRootCA-G3.cer", "AppleIncRootCertificate.cer"];
const appleRootCAs = ROOT_CERT_FILES
  .map((name) => join(__dirname, name))
  .filter((p) => existsSync(p))
  .map((p) => readFileSync(p));

if (appleRootCAs.length === 0) {
  console.error(
    "[ASSN] No Apple root certificate files present. Handler will reject every notification."
  );
}

const verifierCache = new Map();

function getVerifier(env) {
  if (!verifierCache.has(env)) {
    verifierCache.set(
      env,
      new SignedDataVerifier(
        appleRootCAs,
        false, // enableOnlineChecks (OCSP). Offline chain validation is sufficient.
        env,
        BUNDLE_ID,
        APP_APPLE_ID
      )
    );
  }
  return verifierCache.get(env);
}

export const handler = async (event) => {
  let body;
  try {
    body = event.body ? JSON.parse(event.body) : {};
  } catch {
    return respond(400, { error: "Invalid JSON" });
  }

  const signedPayload = body.signedPayload;
  if (!signedPayload) {
    return respond(400, { error: "Missing signedPayload" });
  }

  const decoded = await verifyAcrossEnvironments(signedPayload);
  if (!decoded) {
    // Return 200 so Apple stops retrying a payload we cannot verify.
    // Logs already captured the failure.
    return respond(200, { received: false });
  }

  if (
    decoded.payload.data?.bundleId &&
    decoded.payload.data.bundleId !== BUNDLE_ID
  ) {
    console.error(
      `[ASSN] Bundle ID mismatch: got ${decoded.payload.data.bundleId}`
    );
    return respond(200, { received: false });
  }

  const { transaction, renewal } = await decodeNested(
    decoded.environment,
    decoded.payload.data
  );

  const item = buildEventItem(decoded, transaction, renewal);

  try {
    await db.send(
      new PutItemCommand({
        TableName: TABLE,
        Item: marshall(item, { removeUndefinedValues: true }),
        ConditionExpression: "attribute_not_exists(dataType)",
      })
    );
  } catch (err) {
    if (err.name !== "ConditionalCheckFailedException") {
      console.error("[ASSN] DynamoDB write failed:", err);
    }
  }

  return respond(200, { received: true });
};

async function verifyAcrossEnvironments(signedPayload) {
  // Apple sends from Sandbox to the sandbox URL and Production to the
  // production URL, but operators sometimes point both boxes at the
  // same Lambda. Try production first, fall back to sandbox.
  for (const env of [Environment.PRODUCTION, Environment.SANDBOX]) {
    try {
      const payload =
        await getVerifier(env).verifyAndDecodeNotification(signedPayload);
      return { environment: env, payload };
    } catch (err) {
      // try the other environment
      if (env === Environment.SANDBOX) {
        console.error("[ASSN] Verification failed in both environments:", err);
      }
    }
  }
  return null;
}

async function decodeNested(env, data) {
  let transaction;
  let renewal;
  const verifier = getVerifier(env);
  try {
    if (data?.signedTransactionInfo) {
      transaction = await verifier.verifyAndDecodeTransaction(
        data.signedTransactionInfo
      );
    }
  } catch (err) {
    console.error("[ASSN] Transaction decode failed:", err);
  }
  try {
    if (data?.signedRenewalInfo) {
      renewal = await verifier.verifyAndDecodeRenewalInfo(
        data.signedRenewalInfo
      );
    }
  } catch (err) {
    console.error("[ASSN] Renewal decode failed:", err);
  }
  return { transaction, renewal };
}

function buildEventItem(decoded, transaction, renewal) {
  const payload = decoded.payload;
  const originalTransactionId =
    transaction?.originalTransactionId ||
    renewal?.originalTransactionId ||
    "unknown";

  return {
    userId: `SUB#${originalTransactionId}`,
    dataType: `event#${payload.notificationUUID}`,
    notificationType: payload.notificationType,
    subtype: payload.subtype || null,
    notificationUUID: payload.notificationUUID,
    environment:
      decoded.environment === Environment.PRODUCTION
        ? "Production"
        : "Sandbox",
    productId: transaction?.productId || null,
    originalTransactionId,
    transactionId: transaction?.transactionId || null,
    appAccountToken: transaction?.appAccountToken || null,
    purchaseDate: transaction?.purchaseDate || null,
    expiresDate: transaction?.expiresDate || null,
    autoRenewStatus: renewal?.autoRenewStatus ?? null,
    recordedAt: new Date().toISOString(),
  };
}

function respond(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  };
}
