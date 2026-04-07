import { DynamoDBClient, PutItemCommand, QueryCommand, DeleteItemCommand } from "@aws-sdk/client-dynamodb";
import { marshall, unmarshall } from "@aws-sdk/util-dynamodb";

const db = new DynamoDBClient({ region: "us-east-1" });
const TABLE = "memoryaisle-user-data";

export const handler = async (event) => {
  const method = event.httpMethod;
  const path = event.path;
  const body = event.body ? JSON.parse(event.body) : {};

  // Extract userId from Cognito authorizer or body
  const userId = event.requestContext?.authorizer?.claims?.sub || body.userId;
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

// Push data from device to cloud
async function pushData(userId, body) {
  const { dataType, data, timestamp } = body;
  if (!dataType || !data) {
    return response(400, { error: "dataType and data required" });
  }

  const item = {
    userId,
    dataType, // e.g. "profile", "nutritionLogs", "symptomLogs", "pantryItems", "giRecords"
    data: JSON.stringify(data),
    updatedAt: timestamp || new Date().toISOString(),
  };

  await db.send(new PutItemCommand({
    TableName: TABLE,
    Item: marshall(item),
  }));

  return response(200, { status: "synced", dataType });
}

// Pull data from cloud to device
async function pullData(userId, params) {
  const dataType = params?.dataType;

  const queryParams = {
    TableName: TABLE,
    KeyConditionExpression: dataType
      ? "userId = :uid AND dataType = :dt"
      : "userId = :uid",
    ExpressionAttributeValues: marshall(
      dataType
        ? { ":uid": userId, ":dt": dataType }
        : { ":uid": userId }
    ),
  };

  const result = await db.send(new QueryCommand(queryParams));
  const items = (result.Items || []).map(item => {
    const unmarshalled = unmarshall(item);
    return {
      dataType: unmarshalled.dataType,
      data: JSON.parse(unmarshalled.data),
      updatedAt: unmarshalled.updatedAt,
    };
  });

  return response(200, { items });
}

// Delete ALL user data (account deletion)
async function deleteAllUserData(userId) {
  // Query all items for this user
  const result = await db.send(new QueryCommand({
    TableName: TABLE,
    KeyConditionExpression: "userId = :uid",
    ExpressionAttributeValues: marshall({ ":uid": userId }),
  }));

  // Delete each item
  for (const item of result.Items || []) {
    const unmarshalled = unmarshall(item);
    await db.send(new DeleteItemCommand({
      TableName: TABLE,
      Key: marshall({
        userId: unmarshalled.userId,
        dataType: unmarshalled.dataType,
      }),
    }));
  }

  return response(200, { status: "all data deleted", itemsRemoved: (result.Items || []).length });
}

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Content-Type,Authorization",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  };
}
