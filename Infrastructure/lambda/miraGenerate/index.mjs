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

  const userContext = context ? buildAnonymizedContext(context) : "";

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
  if (ctx.symptomState) lines.push(`- Symptom state: ${ctx.symptomState}`);
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
