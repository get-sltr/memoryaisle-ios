// Meal-plan tool definition and validator. Lives in its own module so tests
// can exercise the contract without pulling in the AWS SDK (which would
// require node_modules at test time — the lambda is deployed as a zip,
// node_modules is gitignored, and CI shouldn't depend on `npm install`
// to gate a regression test).

export const MEAL_PLAN_TOOL = {
  name: "presentMealPlan",
  description:
    "Present a complete one-day meal plan for the user. ALWAYS call this tool exactly once with a meals array — do not return free text. Each meal must have positive protein and calories, at least one ingredient with quantity, and at least one cooking step. Never use em dashes anywhere in the strings you submit.",
  input_schema: {
    type: "object",
    properties: {
      meals: {
        type: "array",
        minItems: 3,
        maxItems: 6,
        items: {
          type: "object",
          properties: {
            type: {
              type: "string",
              enum: [
                "breakfast",
                "lunch",
                "dinner",
                "snack",
                "pre-workout",
                "post-workout",
              ],
              description:
                "Meal slot. Use pre-workout / post-workout only on training days.",
            },
            name: {
              type: "string",
              description:
                "Concrete dish name as a complete phrase. Example: 'Grilled chicken bowl with jasmine rice and broccoli.'",
            },
            protein_g: {
              type: "number",
              minimum: 1,
              description:
                "Realistic protein content in grams for this meal. Breakfasts and snacks typically 15 to 35g; lunches and dinners 30 to 50g; pre-workout 15 to 25g; post-workout 25 to 40g. Never zero.",
            },
            calories: {
              type: "number",
              minimum: 50,
              description:
                "Total calories for the meal as cooked. Breakfasts 300 to 500; lunches and dinners 400 to 700; snacks 100 to 300; pre/post workout 150 to 400. Never zero.",
            },
            carbs_g: {
              type: "number",
              minimum: 0,
              description: "Carbohydrates in grams.",
            },
            fat_g: {
              type: "number",
              minimum: 0,
              description: "Fat in grams.",
            },
            fiber_g: {
              type: "number",
              minimum: 0,
              description: "Dietary fiber in grams.",
            },
            prep_minutes: {
              type: "integer",
              minimum: 0,
              maximum: 240,
              description:
                "Total active prep + cook time in minutes. Use 0 for no-cook items (e.g., yogurt parfait).",
            },
            nausea_safe: {
              type: "boolean",
              description:
                "True only if low-fat, easy on the stomach, and small enough to tolerate in a dose-suppression phase. Otherwise false.",
            },
            ingredients: {
              type: "array",
              minItems: 1,
              items: {
                type: "string",
                description:
                  "One ingredient line including quantity. Example: '6oz boneless skinless chicken breast'.",
              },
              description:
                "Full ingredient list with quantities, ready to copy into a grocery list or recipe.",
            },
            cooking_instructions: {
              type: "array",
              minItems: 1,
              items: {
                type: "string",
                description: "One step of the recipe.",
              },
              description:
                "Numbered cooking steps as separate strings. Each step is a single instruction; do not combine multiple steps into one string.",
            },
          },
          required: [
            "type",
            "name",
            "protein_g",
            "calories",
            "carbs_g",
            "fat_g",
            "fiber_g",
            "prep_minutes",
            "nausea_safe",
            "ingredients",
            "cooking_instructions",
          ],
        },
      },
    },
    required: ["meals"],
  },
};

export const MEAL_PLAN_SYSTEM_PROMPT = `You are Mira, planning ONE day of meals for the user.

You will be given the user's anonymized profile (medication class if any, cycle phase, mode, protein and calorie targets, dietary restrictions, pantry hints, GI triggers, and meals already planned earlier in the week).

Your job: generate a coherent day of meals that hits the user's protein and calorie targets, varies cuisine and protein source from the avoid list, and respects every dietary restriction.

Output rules:
- Call the presentMealPlan tool exactly once. Never return free text.
- Provide protein_g and calories for every meal. Never zero. Never null. The schema rejects them and the call fails.
- Provide a real ingredient list with quantities, not placeholders. "1 cup spinach" not "spinach to taste."
- Provide real cooking steps, not "see recipe online." If a meal needs no cooking, write the assembly step (e.g., "Layer yogurt, granola, and berries in a bowl").
- Use only meal types from the schema enum. pre-workout and post-workout are valid only on training days.
- Vary cuisines and protein sources across the day; never the same protein twice.
- Avoid every meal name in the avoid list, including close variants.

Tone:
- Concrete, specific, no em dashes anywhere.
- Reasoning lives in the schema fields (nausea_safe, prep_minutes, ingredients), not in narrative.

If the user is on a medication and in a dose-suppression phase, set nausea_safe=true on at least one meal that is gentle (low-fat, easy on the stomach, smaller portion). For non-medication users, frame around training and protein goals.`;

// Validates a presentMealPlan tool input. Belt to the schema's suspenders —
// re-runs the same checks server-side so a regression in Bedrock's schema
// enforcement gets caught here before the iOS client sees a corrupt plan.
export function validateMealPlanPayload(payload) {
  const errors = [];
  if (!payload || !Array.isArray(payload.meals)) {
    return { ok: false, errors: ["meals: missing or not an array"] };
  }
  if (payload.meals.length < 3) {
    errors.push(`meals: expected at least 3, got ${payload.meals.length}`);
  }
  payload.meals.forEach((meal, i) => {
    const prefix = `meals[${i}]`;
    if (typeof meal.name !== "string" || meal.name.trim().length === 0) {
      errors.push(`${prefix}.name: missing or empty`);
    }
    if (typeof meal.type !== "string" || meal.type.trim().length === 0) {
      errors.push(`${prefix}.type: missing or empty`);
    }
    if (typeof meal.protein_g !== "number" || meal.protein_g <= 0) {
      errors.push(`${prefix}.protein_g: must be > 0, got ${meal.protein_g}`);
    }
    if (typeof meal.calories !== "number" || meal.calories <= 0) {
      errors.push(`${prefix}.calories: must be > 0, got ${meal.calories}`);
    }
    if (!Array.isArray(meal.ingredients) || meal.ingredients.length === 0) {
      errors.push(`${prefix}.ingredients: must have at least 1 entry`);
    } else if (
      meal.ingredients.some((s) => typeof s !== "string" || s.trim().length === 0)
    ) {
      errors.push(`${prefix}.ingredients: contains an empty entry`);
    }
    if (
      !Array.isArray(meal.cooking_instructions) ||
      meal.cooking_instructions.length === 0
    ) {
      errors.push(`${prefix}.cooking_instructions: must have at least 1 step`);
    } else if (
      meal.cooking_instructions.some(
        (s) => typeof s !== "string" || s.trim().length === 0
      )
    ) {
      errors.push(`${prefix}.cooking_instructions: contains an empty step`);
    }
  });
  return errors.length === 0 ? { ok: true } : { ok: false, errors };
}
