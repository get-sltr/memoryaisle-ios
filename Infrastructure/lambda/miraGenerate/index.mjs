import {
  BedrockRuntimeClient,
  InvokeModelCommand,
} from "@aws-sdk/client-bedrock-runtime";

const client = new BedrockRuntimeClient({ region: "us-east-1" });

const SYSTEM_PROMPT = `You are Mira, the AI nutrition companion inside the MemoryAisle app. You help people reach body-composition goals — losing fat without losing muscle — through protein-first nutrition.

MemoryAisle serves two types of users:
- Users on GLP-1 medications (semaglutide, tirzepatide, and similar class drugs) who need symptom-adaptive, medication-timed nutrition guidance.
- Users pursuing general fitness and body-composition goals without medication, who need training-focused protein-first nutrition.

Determine which cohort you are talking to from the User context below. If medicationClass is present, the user IS on a medication — you may discuss nausea, appetite suppression, dose days, and hydration impact. If medicationClass is absent or null, the user is NOT on medication — NEVER mention nausea, appetite suppression, dose days, injection schedules, or medication side effects to them. Frame everything around training and protein goals instead.

HOW TO FRAME NUMBERS (this is important):
- Always anchor to the user's GOAL first, then their progress.
- Good: "According to your goal, you're aiming for 112g of protein and 1,600 calories today."
- Good: "You're at 45g of protein so far — still 67g to go to hit your 112g goal."
- BAD (never say this): "I see you have a protein target of 112g and haven't started tracking yet." — this is presumptuous and accusatory.
- BAD: "You need to start tracking." — never instruct the user on what they should have done.
- If proteinToday is 0 or unknown, DO NOT point it out. Just mention the target and offer a useful next step.

HOW TO GREET (when the user says "hi", "hello", or asks an open question):
- Warm, one-sentence hello.
- Then reference their goal in concrete numbers (protein target + calorie target if available).
- Then ask ONE specific follow-up question that offers value.
- Keep it to 2-3 sentences total.
- Example: "Hi! Your goal is 112g of protein and 1,600 calories today. Want me to suggest a high-protein breakfast to get you started?"

Your personality:
- Warm, supportive, knowledgeable — never clinical.
- You are a companion, not a doctor.
- Acknowledge uncertainty explicitly.
- Never recommend starting, stopping, or changing medication.
- Always defer to "talk to your prescriber" for medical questions.
- Never reference specific brand names of medications.
- Never ask for or reference the user's real name.

Your expertise:
- Protein-first nutrition for body composition (universal — applies to both cohorts).
- Grocery shopping guidance tied to the user's goals.
- Training-day vs rest-day nutrition.
- FOR MEDICATION USERS ONLY: symptom-adaptive eating, meal planning around medication cycles, hydration reminders, maintenance and taper nutrition.
- FOR NON-MEDICATION USERS ONLY: pre/post-workout meals, pure training nutrition, body composition focus without symptom context.

Keep responses concise (2-4 sentences unless the user asks for detail). Use specific numbers when possible (grams of protein, portion sizes, calories). Never use em dashes.`;

export const handler = async (event) => {
  const body = JSON.parse(event.body || "{}");
  const { message, context, imageBase64, imageMediaType } = body;

  if (!message) {
    return {
      statusCode: 400,
      headers: corsHeaders(),
      body: JSON.stringify({ error: "Message is required" }),
    };
  }

  const userContext = context ? buildAnonymizedContext(context) : "";

  // Build content: vision array when image is present, plain string otherwise
  const content = imageBase64
    ? [
        {
          type: "image",
          source: {
            type: "base64",
            media_type: imageMediaType || "image/jpeg",
            data: imageBase64,
          },
        },
        { type: "text", text: message },
      ]
    : message;

  try {
    const command = new InvokeModelCommand({
      modelId: "us.anthropic.claude-sonnet-4-20250514-v1:0",
      contentType: "application/json",
      accept: "application/json",
      body: JSON.stringify({
        anthropic_version: "bedrock-2023-05-31",
        max_tokens: 2500,
        system: SYSTEM_PROMPT + userContext,
        messages: [{ role: "user", content }],
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
