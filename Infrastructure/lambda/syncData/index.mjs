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
