import {
  DynamoDBClient,
  QueryCommand,
} from "@aws-sdk/client-dynamodb";
import { unmarshall, marshall } from "@aws-sdk/util-dynamodb";
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
    recentNutrition.reduce((s, l) => s + (l.caloriesConsumed || 0), 0) / days;
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
