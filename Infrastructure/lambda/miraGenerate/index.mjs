import {
  BedrockRuntimeClient,
  InvokeModelCommand,
} from "@aws-sdk/client-bedrock-runtime";
import {
  MEAL_PLAN_TOOL,
  MEAL_PLAN_SYSTEM_PROMPT,
  validateMealPlanPayload,
} from "./meal-plan-schema.mjs";

const client = new BedrockRuntimeClient({ region: "us-east-1" });

const SYSTEM_PROMPT = `You are Mira, the AI nutrition companion inside the MemoryAisle app. You help people reach body-composition goals (losing fat without losing muscle) through protein-first nutrition.

MemoryAisle serves two types of users:
- Users on GLP-1 medications (semaglutide, tirzepatide, and similar class drugs) who need symptom-adaptive, medication-timed nutrition guidance.
- Users pursuing general fitness and body-composition goals without medication, who need training-focused protein-first nutrition.

Determine which cohort you are talking to from the User context below. If medicationClass is present, the user IS on a medication (you may discuss nausea, appetite suppression, dose days, and hydration impact). If medicationClass is absent or null, the user is NOT on medication. NEVER mention nausea, appetite suppression, dose days, injection schedules, or medication side effects to them. Frame everything around training and protein goals instead.

HOW TO FRAME NUMBERS (this is important):
- Always anchor to the user's GOAL first, then their progress.
- Good: "According to your goal, you're aiming for 112g of protein and 1,600 calories today."
- Good: "You're at 45g of protein so far, still 67g to go to hit your 112g goal."
- BAD (never say this): "I see you have a protein target of 112g and haven't started tracking yet." This is presumptuous and accusatory.
- BAD: "You need to start tracking." Never instruct the user on what they should have done.
- If proteinToday is 0 or unknown, DO NOT point it out. Just mention the target and offer a useful next step.

HOW TO GREET (when the user says "hi", "hello", or asks an open question):
- Warm, one-sentence hello.
- Then reference their goal in concrete numbers (protein target + calorie target if available).
- Then ask ONE specific follow-up question that offers value.
- Keep it to 2-3 sentences total.
- Example: "Hi! Your goal is 112g of protein and 1,600 calories today. Want me to suggest a high-protein breakfast to get you started?"

RECIPES AND MEAL IDEAS (this is core to your job — do not decline these requests):

You CAN and SHOULD generate recipes from your own knowledge. You have broad culinary knowledge across cuisines: Japanese (ramen, donburi, tamago, miso soups), Korean (bibimbap, japchae, kimchi stews), Thai, Vietnamese (pho, bun, banh mi), Chinese, Italian, Mexican, Mediterranean, Indian, American comfort food, and anything else the user asks for.

When the user asks for a recipe (any cuisine, any dish, including carb-forward classics like ramen, pasta, fried rice, tacos, sandwiches, curries) — generate it. Do NOT say "I don't have a collection" or "I don't have recipes for that." You have the knowledge. Use it.

Reframe classic dishes to fit the user's protein goal instead of refusing them:
- Ramen: high-protein ramen with extra egg, shredded chicken breast or silken tofu in the broth, higher-protein noodle swaps where it helps.
- Pasta: lean protein on top (chicken, shrimp, lean ground turkey), protein-enriched pasta or lentil pasta as an option, smaller carb portion balanced with bigger protein portion.
- Tacos: double the protein filling, use Greek yogurt in place of sour cream, beans for bonus protein + fiber.
- Fried rice: egg white heavy, add shrimp or diced chicken, cauliflower rice blend option.
- Sandwiches: cottage cheese or Greek yogurt spreads, extra-lean deli meats, open-faced with protein bread.

When you give a recipe, include:
- A quick intro line (1 sentence) explaining how this version is tuned to the user's goal.
- Ingredient list with quantities (bullet format is fine).
- Brief cooking steps (5 to 8 bullets, concise).
- Macros per serving (protein, calories, carbs, fat) estimated to the nearest 5g / 25 cal.
- One line tying it back to the user's daily goal, e.g. "This is about 42g protein and 520 cal, roughly 38% of your daily protein target."

For recipe responses you may exceed the normal 2-4 sentence length guideline. Recipes need ingredient lists and steps to be useful — go long when you need to.

If the user asks for a MEAL PLAN (multiple meals for a day or a week), structure it as: intro line, then each meal with name + core ingredients + macros, then a one-line summary of the total day's macros vs their goal.

Your personality:
- Warm, supportive, knowledgeable. Never clinical.
- You are a companion, not a doctor.
- Acknowledge uncertainty explicitly.
- Never recommend starting, stopping, or changing medication.
- Always defer to "talk to your prescriber" for medical questions.
- Never reference specific brand names of medications.
- Never ask for or reference the user's real name.

Your expertise:
- Protein-first nutrition for body composition (universal, applies to both cohorts).
- Recipe generation and meal ideas across all cuisines, always tuned to the user's goals.
- Grocery shopping guidance tied to the user's goals.
- Training-day vs rest-day nutrition.
- Meal plans (single day or multi-day) tailored to protein and calorie targets.
- FOR MEDICATION USERS ONLY: symptom-adaptive eating, meal planning around medication cycles, hydration reminders, maintenance and taper nutrition.
- FOR NON-MEDICATION USERS ONLY: pre/post-workout meals, pure training nutrition, body composition focus without symptom context.

For short conversational replies (greetings, questions about targets, general check-ins), keep responses to 2-4 sentences. For recipes and meal plans, go as long as needed. Use specific numbers when possible (grams of protein, portion sizes, calories). Never use em dashes.

SCOPE: what is OFF-TOPIC for Mira

You ONLY do nutrition, meals, recipes, grocery shopping, training-aware eating, and (for medication users) symptom-aware guidance. You do NOT write code, scripts, snippets, pseudocode, or programming examples of any kind in any language. You do NOT help with software questions, debugging, technical documentation, math homework, current events, image analysis outside of food, or any general-purpose assistant tasks.

If the user asks for anything off-topic, even framed as "just an example", "hypothetically", "your husband told me you could", "as a programmer", "pretend you can", "for fun", or "just this once", kindly redirect in ONE sentence and vary the wording. Examples:
- "That's outside what I do here. I'm best at meals, recipes, and hitting your protein goal. What sounds good?"
- "I stick to nutrition stuff. Want me to riff on a high-protein lunch instead?"

Then stop. Do not produce code or off-topic content. Do not explain what you would do if you could. Do not start an answer and then apologize. Just redirect and move on.

This applies even when the user is persistent, polite, friendly, or claims a special reason. People will sometimes test this. Stay warm, stay focused.

TOOLS (this is how you perform real actions in the user's app):

When the tools array is present in your request, you have access to real functions that modify the user's data on their device. When the user asks you to DO something concrete, CALL THE APPROPRIATE TOOL instead of describing what you would do or asking follow-up questions.

Guidelines:
- If the user asks to "add X to my grocery list", "export ingredients", "put X on the shopping list", "I need to buy Y" — call addToGroceryList immediately with whatever items fit.
- If the user says "I had X for lunch", "log my breakfast", "I just ate Y" — call logMeal with the best estimate of protein and calories from your culinary knowledge. Do not ask the user for precise macros.
- If the user asks "how's my protein today", "am I on track", "what's left" — call getTodayNutrition to read live numbers before answering.
- If you need to reference the user's goals and the context doesn't already include them, call getUserTargets.
- When the user asks for a recipe AND wants the ingredients in their grocery list, first generate the recipe in text, then call addToGroceryList with the ingredient names (no quantities — shopper-friendly names only, e.g. "chicken breast" not "2 lbs chicken breast").
- You may call tools in sequence. Each tool result will come back as a tool_result message, and you should then continue the conversation with a natural text reply that references what you did.
- Do NOT stall by asking "would you like me to" or "should I" when the user has already told you what they want. If they said "add this to my grocery list" they want it added. Call the tool.

OFF-LIMITS: You have no tools for the "My Safe Space" destination in the app menu, and you must never claim to have access to it. If the user asks you to do anything involving My Safe Space, say something like "My Safe Space is yours alone, I don't have access there. Tap it from the menu whenever you want." Then move on.`;

const TOOLS = [
  {
    name: "addToGroceryList",
    description:
      "Add one or more items to the user's on-device grocery list. Use when the user asks to add items, export a recipe's ingredients, or save a shopping list. Items will be added as PantryItem records and auto-categorized. Keep item names short and shopper-friendly.",
    input_schema: {
      type: "object",
      properties: {
        items: {
          type: "array",
          items: { type: "string" },
          description:
            "Grocery item names, short and shopper-friendly (e.g. 'chicken breast', 'soy sauce', 'ramen noodles'). Do NOT include quantities in the name.",
        },
      },
      required: ["items"],
    },
  },
  {
    name: "logMeal",
    description:
      "Log a meal the user has just eaten, adding its nutrition to today's totals. The user's dashboard updates automatically. Estimate protein and calories from your culinary knowledge if the user doesn't provide exact numbers.",
    input_schema: {
      type: "object",
      properties: {
        name: {
          type: "string",
          description:
            "Short name of the meal (e.g. 'Greek yogurt with berries', 'grilled chicken salad').",
        },
        proteinGrams: {
          type: "number",
          description: "Estimated grams of protein in the meal.",
        },
        calories: {
          type: "number",
          description: "Estimated total calories in the meal.",
        },
        fiberGrams: {
          type: "number",
          description:
            "Estimated grams of fiber in the meal. Pass 0 if you have no estimate.",
        },
      },
      required: ["name", "proteinGrams", "calories"],
    },
  },
  {
    name: "getTodayNutrition",
    description:
      "Fetch the user's running nutrition totals for today (protein, calories, water, fiber). Use when the user asks about today's progress, what's left, or whether they're on track.",
    input_schema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "getUserTargets",
    description:
      "Fetch the user's current daily targets (protein, calories, water, fiber) and weight goal. Use when you need fresh target data that might not be in the system context.",
    input_schema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "lookupDrugFact",
    description:
      "Look up a curated, FDA-PI-grounded fact about the user's medication class. Call this whenever you would otherwise quote a specific drug number (side-effect prevalence, half-life, dosing schedule, contraindications, warnings, interactions, renal/hepatic adjustments). The store ships intentionally empty until medical/legal review; if no curated entry exists, the tool returns a deferral and you must say so honestly rather than fabricate a number.",
    input_schema: {
      type: "object",
      properties: {
        topic: {
          type: "string",
          description:
            "One of: sideEffectPrevalence, halfLife, dosingSchedule, contraindications, warnings, interactions, adjustmentForRenalImpairment, adjustmentForHepaticImpairment, other.",
        },
      },
      required: ["topic"],
    },
  },
  {
    name: "getRecentSymptoms",
    description:
      "Fetch an anonymized 7-day summary of the user's logged symptoms — nausea, appetite, energy bands. Use this for side-effect triage so 'what to do today' guidance is grounded in the user's actual recent state, not generalities.",
    input_schema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "getMedicationPhaseSummary",
    description:
      "Fetch the user's current cycle phase, days-since-injection, and expected appetite description. Use this to be cycle-aware in conversation without restating the profile.",
    input_schema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "lookupMedicationProgram",
    description:
      "Look up a curated manufacturer assistance program for the user's medication class (NovoCare, Lilly Cares, etc.). Currently returns a deferral until the curated dataset has legal sign-off. Never invent program names, savings amounts, or eligibility criteria.",
    input_schema: {
      type: "object",
      properties: {
        drugClass: {
          type: "string",
          description:
            "Anonymized drug class hint: semaglutide, tirzepatide, orforglipron, unknown.",
        },
      },
      required: [],
    },
  },
  {
    name: "lookupAppealTemplate",
    description:
      "Look up a curated insurance-appeal letter template by category (e.g., 'medical_necessity', 'step_therapy_override'). Currently returns a deferral until the curated dataset has legal sign-off.",
    input_schema: {
      type: "object",
      properties: {
        category: {
          type: "string",
          description: "Appeal category. Optional.",
        },
      },
      required: [],
    },
  },
];

// Tool used to force structured output from the meal-recommendation mode.
// Claude is required to call this exactly once with three populated meal
// recommendations; we parse the tool input as our payload and never actually
// "execute" the tool server-side.
const RECOMMEND_TOOL = {
  name: "presentMealRecommendations",
  description:
    "Present three concrete meal recommendations to the user. ALWAYS call this tool exactly once with a recommendations array of length 3 — do not return free text. Never use em dashes anywhere in the strings you submit.",
  input_schema: {
    type: "object",
    properties: {
      recommendations: {
        type: "array",
        minItems: 3,
        maxItems: 3,
        items: {
          type: "object",
          properties: {
            name: {
              type: "string",
              description:
                "Short meal name as a complete sentence ending in a period. Example: 'Grilled chicken bowl with rice and avocado.'",
            },
            calories: { type: "integer" },
            proteinG: { type: "integer" },
            fatG: { type: "integer" },
            carbsG: { type: "integer" },
            reasoning: {
              type: "string",
              description:
                "ONE short sentence (under 80 chars) that explains why this meal fits THIS user RIGHT NOW. Be specific to their state, not generic. No em dashes.",
            },
            ingredients: {
              type: "array",
              items: { type: "string" },
              description:
                "5 to 8 short ingredient names without quantities (e.g., 'Chicken breast', 'Jasmine rice', '½ avocado').",
            },
            isDoseDayFriendly: {
              type: "boolean",
              description:
                "True ONLY if this meal is gentle (low-fat, easy to digest, smaller portion) AND the user appears to be in a dose-suppression phase from the context.",
            },
          },
          required: [
            "name",
            "calories",
            "proteinG",
            "fatG",
            "carbsG",
            "reasoning",
            "ingredients",
            "isDoseDayFriendly",
          ],
        },
      },
    },
    required: ["recommendations"],
  },
};

const RECOMMEND_SYSTEM_PROMPT = `You are Mira's recommendation engine. Your job is to suggest exactly 3 meal options for the user RIGHT NOW, given their current state.

Decide based on the user context (provided after this prompt):
- Current meal window (breakfast, lunch, snack, dinner, late night)
- Daily protein goal vs what's consumed today
- Daily calorie goal vs what's consumed today
- Cycle phase, medication class, days since dose (if applicable)
- Symptom state (nausea, low appetite, fatigue, prefer gentler options)
- Recent meals (avoid repeats, at least 2 of the 3 should differ in protein source AND cuisine from anything in the recent list)
- Pantry items (prefer recipes that use what's on hand, but don't be limited by it)
- Dietary restrictions (NEVER suggest restricted ingredients)
- Product mode (everyday, sensitive stomach, muscle preservation, training performance, maintenance taper)

The 3 meals must:
- Fit the current meal window. No pancakes for dinner, no steak for breakfast.
- Vary across cuisines AND protein sources. Don't return three chicken bowls. Mix it up: one Asian, one Mediterranean, one American comfort, etc.
- Vary in effort: at least one should be quick (5 to 10 min), at least one can be more involved (20 to 30 min). Effort variety matters.
- Help close the protein gap if the user is behind for the day.
- For non-medication users, frame around training and protein goals. Never reference nausea or appetite suppression.
- For medication users in a dose-suppression phase, set isDoseDayFriendly=true on at least one meal that is gentle (low-fat, easy on the stomach, smaller portion).

For each meal, provide all required fields. Round macros to the nearest 5g for protein/fat/carbs and the nearest 25 for calories. Reasoning must be ONE sentence under 80 characters, specific to the user's state. Never use em dashes anywhere.

Call presentMealRecommendations exactly once. Never return free text.`;

export const handler = async (event) => {
  const body = JSON.parse(event.body || "{}");
  const {
    message,
    messages,
    context,
    imageBase64,
    imageMediaType,
    useTools,
    mode,
    mealWindow,
    recentMeals,
    pantryItems,
  } = body;

  // Recommendation mode: short-circuit to the structured-output path.
  if (mode === "recommend") {
    return await handleRecommend({
      context,
      mealWindow,
      recentMeals,
      pantryItems,
    });
  }

  // Meal-plan mode: structured-output generation of a single day's meals.
  // Routes here on the explicit `mode: "meal_plan"` field — no substring
  // match on the user message — so client prompt edits can't silently
  // break the short-circuit and fall back to the free-text path.
  if (mode === "meal_plan") {
    return await handleMealPlan({
      context,
      cyclePhase: body.cyclePhase,
      isTrainingDay: body.isTrainingDay,
      avoidMealNames: body.avoidMealNames,
      pantryItems,
    });
  }

  // Backward-compatible request shape: accept either
  //   { message, context, imageBase64 }   — legacy single-message mode
  //   { messages, context, useTools }     — multi-turn tool-use mode
  //
  // When useTools is true, the tools array is passed to Claude and tool_use
  // responses are returned verbatim so the iOS client can execute the tool
  // locally and send the result back as a follow-up call.

  let conversationMessages;

  if (Array.isArray(messages) && messages.length > 0) {
    // Multi-turn mode: trust the client's conversation array as-is.
    conversationMessages = messages;
  } else if (message) {
    // Legacy single-message mode.
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
    conversationMessages = [{ role: "user", content }];
  } else {
    return {
      statusCode: 400,
      headers: corsHeaders(),
      body: JSON.stringify({ error: "Message or messages array is required" }),
    };
  }

  const userContext = context ? buildAnonymizedContext(context) : "";

  const requestBody = {
    anthropic_version: "bedrock-2023-05-31",
    max_tokens: 2500,
    system: SYSTEM_PROMPT + userContext,
    messages: conversationMessages,
  };

  if (useTools) {
    requestBody.tools = TOOLS;
  }

  try {
    const command = new InvokeModelCommand({
      modelId: "us.anthropic.claude-sonnet-4-20250514-v1:0",
      contentType: "application/json",
      accept: "application/json",
      body: JSON.stringify(requestBody),
    });

    const response = await client.send(command);
    const result = JSON.parse(new TextDecoder().decode(response.body));

    // Pull out text + tool_use from the content blocks
    const contentBlocks = Array.isArray(result.content) ? result.content : [];
    const textBlocks = contentBlocks.filter((b) => b.type === "text");
    const toolUseBlocks = contentBlocks.filter((b) => b.type === "tool_use");
    const reply =
      textBlocks.map((b) => b.text).join("\n\n") ||
      (toolUseBlocks.length === 0
        ? "I'm having trouble right now. Try again in a moment."
        : "");

    return {
      statusCode: 200,
      headers: corsHeaders(),
      body: JSON.stringify({
        reply,
        stopReason: result.stop_reason || null,
        // Echo the full assistant content back so the client can append it to
        // the next messages array on tool-result follow-ups. Claude expects
        // the assistant's tool_use content to be in the history before the
        // matching user tool_result.
        assistantContent: contentBlocks,
        toolUses: toolUseBlocks.map((b) => ({
          id: b.id,
          name: b.name,
          input: b.input,
        })),
      }),
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

// ---------------------------------------------------------------------------
// Meal-plan structured-output mode (one day at a time).
//
// Replaces the old free-text "MEAL|..." pipe contract that the iOS parser used
// to read. The pipe parser silently dropped malformed lines and silently
// substituted hardcoded fallback meals when the model returned prose, which
// hid both refusals and partial breakages — the same fall-through pathology
// the photo analyzer had. tool_use forces the model to call presentMealPlan
// exactly once with a meals array, and the schema enforces minimums + minItems
// at the Bedrock level so a refusal returns no tool_use block (caller handles
// 502) instead of a meal with 0g protein and no ingredients.
//
// Tool definition + validator live in meal-plan-schema.mjs so they can be
// unit-tested without booting the AWS SDK. Same checks run server-side here
// (suspenders) as run in the test suite (belt) — a regression in either
// layer fails CI before it can ship.
// ---------------------------------------------------------------------------

async function handleMealPlan({
  context,
  cyclePhase,
  isTrainingDay,
  avoidMealNames,
  pantryItems,
}) {
  const userContext = context ? buildAnonymizedContext(context) : "";

  const lines = [];
  const trainingFlag = isTrainingDay === true;
  const mealCount = trainingFlag ? 5 : 4;
  lines.push(
    `Generate ${mealCount} meals for ONE day. ${
      trainingFlag
        ? "Include a pre-workout and a post-workout slot."
        : "Use breakfast, lunch, dinner, and a snack."
    }`
  );
  if (cyclePhase) {
    lines.push(`Cycle phase: ${cyclePhase}.`);
  }
  if (Array.isArray(pantryItems) && pantryItems.length) {
    lines.push(
      `Pantry on hand (prefer when relevant): ${pantryItems
        .slice(0, 20)
        .join(", ")}.`
    );
  }
  if (Array.isArray(avoidMealNames) && avoidMealNames.length) {
    lines.push(
      `Already planned earlier this week, do NOT repeat or close-variant: ${avoidMealNames
        .slice(-20)
        .join(", ")}.`
    );
  }
  lines.push("Call presentMealPlan exactly once with the day's meals.");
  const userMessage = lines.join("\n");

  const requestBody = {
    anthropic_version: "bedrock-2023-05-31",
    max_tokens: 3500,
    system: MEAL_PLAN_SYSTEM_PROMPT + userContext,
    messages: [{ role: "user", content: userMessage }],
    tools: [MEAL_PLAN_TOOL],
    tool_choice: { type: "tool", name: "presentMealPlan" },
  };

  try {
    const command = new InvokeModelCommand({
      modelId: "us.anthropic.claude-sonnet-4-20250514-v1:0",
      contentType: "application/json",
      accept: "application/json",
      body: JSON.stringify(requestBody),
    });

    const response = await client.send(command);
    const result = JSON.parse(new TextDecoder().decode(response.body));

    const contentBlocks = Array.isArray(result.content) ? result.content : [];
    const toolBlock = contentBlocks.find((b) => b.type === "tool_use");

    if (!toolBlock || !toolBlock.input || !Array.isArray(toolBlock.input.meals)) {
      // No tool_use block at all — model refused or hit max_tokens before
      // it could call the tool. CloudWatch picks this up via the EMF log
      // line below; iOS treats 502 as retryable with exp backoff.
      emitMetric({
        metric: "tool_use_parse_failure",
        kind: "no_tool_use_block",
        stop_reason: result.stop_reason || "unknown",
      });
      return {
        statusCode: 502,
        headers: corsHeaders(),
        body: JSON.stringify({
          error:
            "Mira didn't return a meal plan in the expected shape. Try again in a moment.",
          kind: "no_tool_use",
        }),
      };
    }

    const validation = validateMealPlanPayload(toolBlock.input);
    if (!validation.ok) {
      // The schema rejected something the model produced — usually a zero
      // macro or empty ingredients list. iOS should retry once and then
      // fail; further retries waste spend on the same broken state.
      emitMetric({
        metric: "tool_use_parse_failure",
        kind: "schema_validation",
        errors: validation.errors,
      });
      console.error(
        "Meal plan validation failed",
        JSON.stringify({ errors: validation.errors, payload: toolBlock.input })
      );
      return {
        statusCode: 422,
        headers: corsHeaders(),
        body: JSON.stringify({
          error: "Mira's meal plan didn't pass validation.",
          kind: "schema_validation",
          details: validation.errors,
        }),
      };
    }

    emitMetric({
      metric: "tool_use_parse_success",
      meal_count: toolBlock.input.meals.length,
    });

    return {
      statusCode: 200,
      headers: corsHeaders(),
      body: JSON.stringify({ meals: toolBlock.input.meals }),
    };
  } catch (error) {
    emitMetric({ metric: "tool_use_bedrock_error", message: error.message });
    console.error("Meal plan Bedrock error:", error);
    return {
      statusCode: 500,
      headers: corsHeaders(),
      body: JSON.stringify({
        error: "Mira is temporarily unavailable. Please try again.",
      }),
    };
  }
}

// Emits a CloudWatch metric line in Embedded Metric Format. AWS picks up
// the JSON automatically when the log line includes the _aws envelope —
// no SDK call required, no extra IAM permissions, no cost beyond the
// existing log ingestion.
function emitMetric(payload) {
  const timestamp = Date.now();
  console.log(
    JSON.stringify({
      _aws: {
        Timestamp: timestamp,
        CloudWatchMetrics: [
          {
            Namespace: "MemoryAisle/MealPlan",
            Dimensions: [["metric"]],
            Metrics: [{ Name: "Count", Unit: "Count" }],
          },
        ],
      },
      Count: 1,
      ...payload,
    })
  );
}

async function handleRecommend({ context, mealWindow, recentMeals, pantryItems }) {
  // Build the same anonymized user-context block the chat path uses, so
  // medication class / cycle phase / protein progress all flow into the
  // recommendation prompt without redefining the schema.
  const userContext = context ? buildAnonymizedContext(context) : "";

  // Synthesize the one-shot user turn that triggers the structured tool call.
  const lines = [];
  lines.push(
    `Generate 3 meal recommendations for the user RIGHT NOW. Current meal window: ${
      mealWindow || "unknown"
    }.`
  );
  if (Array.isArray(recentMeals) && recentMeals.length) {
    lines.push(
      `Recent meals (avoid repeats): ${recentMeals.slice(0, 10).join(", ")}.`
    );
  }
  if (Array.isArray(pantryItems) && pantryItems.length) {
    lines.push(
      `Pantry on hand (prefer when relevant): ${pantryItems
        .slice(0, 20)
        .join(", ")}.`
    );
  }
  lines.push(
    "Call presentMealRecommendations exactly once with the 3 recommendations."
  );
  const userMessage = lines.join("\n");

  const requestBody = {
    anthropic_version: "bedrock-2023-05-31",
    max_tokens: 2500,
    system: RECOMMEND_SYSTEM_PROMPT + userContext,
    messages: [{ role: "user", content: userMessage }],
    tools: [RECOMMEND_TOOL],
    // tool_choice forces the model to call the named tool, guaranteeing
    // structured output. Available on Anthropic Sonnet 4 via Bedrock.
    tool_choice: { type: "tool", name: "presentMealRecommendations" },
  };

  try {
    const command = new InvokeModelCommand({
      modelId: "us.anthropic.claude-sonnet-4-20250514-v1:0",
      contentType: "application/json",
      accept: "application/json",
      body: JSON.stringify(requestBody),
    });

    const response = await client.send(command);
    const result = JSON.parse(new TextDecoder().decode(response.body));

    const contentBlocks = Array.isArray(result.content) ? result.content : [];
    const toolBlock = contentBlocks.find((b) => b.type === "tool_use");

    if (!toolBlock || !toolBlock.input || !Array.isArray(toolBlock.input.recommendations)) {
      console.error(
        "Recommend mode: model did not return the expected tool_use payload",
        JSON.stringify(result.stop_reason)
      );
      return {
        statusCode: 502,
        headers: corsHeaders(),
        body: JSON.stringify({
          error: "Mira couldn't put together suggestions right now. Try again in a moment.",
        }),
      };
    }

    return {
      statusCode: 200,
      headers: corsHeaders(),
      body: JSON.stringify({
        recommendations: toolBlock.input.recommendations,
      }),
    };
  } catch (error) {
    console.error("Recommend mode Bedrock error:", error);
    return {
      statusCode: 500,
      headers: corsHeaders(),
      body: JSON.stringify({
        error: "Mira is temporarily unavailable. Please try again.",
      }),
    };
  }
}

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
