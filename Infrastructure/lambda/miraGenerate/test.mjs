import { test } from "node:test";
import assert from "node:assert/strict";
import {
  validateMealPlanPayload,
  MEAL_PLAN_TOOL,
} from "./meal-plan-schema.mjs";

// Schema-level + validator-level regression gate for Task 1. The Bedrock
// schema (MEAL_PLAN_TOOL) and validateMealPlanPayload are belt + suspenders;
// these tests pin the suspenders. If either changes and starts admitting a
// 0g protein meal or an empty ingredients list, this suite fails — and
// that's the bug the iOS Meals tab has been hiding behind fallbackMeals.

const validMeal = (overrides = {}) => ({
  type: "breakfast",
  name: "Greek yogurt parfait with berries.",
  protein_g: 28,
  calories: 320,
  carbs_g: 30,
  fat_g: 10,
  fiber_g: 5,
  prep_minutes: 4,
  nausea_safe: true,
  ingredients: ["1 cup Greek yogurt", "1/2 cup mixed berries", "1 tbsp honey"],
  cooking_instructions: [
    "Spoon yogurt into a bowl.",
    "Top with berries.",
    "Drizzle with honey.",
  ],
  ...overrides,
});

const validPayload = (overrides = {}) => ({
  meals: [
    validMeal({ type: "breakfast", name: "A." }),
    validMeal({ type: "lunch", name: "B." }),
    validMeal({ type: "dinner", name: "C." }),
    validMeal({ type: "snack", name: "D." }),
  ],
  ...overrides,
});

// ----- happy path ------------------------------------------------------------

test("valid 4-meal payload passes validation", () => {
  const result = validateMealPlanPayload(validPayload());
  assert.equal(result.ok, true);
});

// ----- structural failures ---------------------------------------------------

test("missing meals array fails", () => {
  const result = validateMealPlanPayload({});
  assert.equal(result.ok, false);
  assert.match(result.errors[0], /meals/);
});

test("non-array meals fails", () => {
  const result = validateMealPlanPayload({ meals: "not an array" });
  assert.equal(result.ok, false);
});

test("fewer than 3 meals fails", () => {
  const result = validateMealPlanPayload({ meals: [validMeal()] });
  assert.equal(result.ok, false);
  assert.ok(result.errors.some((e) => e.includes("at least 3")));
});

// ----- per-meal failures the Bedrock schema and our validator both reject ----

test("zero protein_g fails (this is the headline regression we're guarding)", () => {
  const payload = validPayload();
  payload.meals[0].protein_g = 0;
  const result = validateMealPlanPayload(payload);
  assert.equal(result.ok, false);
  assert.ok(result.errors.some((e) => e.includes("protein_g")));
});

test("negative protein_g fails", () => {
  const payload = validPayload();
  payload.meals[1].protein_g = -5;
  const result = validateMealPlanPayload(payload);
  assert.equal(result.ok, false);
});

test("missing protein_g fails", () => {
  const payload = validPayload();
  delete payload.meals[2].protein_g;
  const result = validateMealPlanPayload(payload);
  assert.equal(result.ok, false);
});

test("zero calories fails", () => {
  const payload = validPayload();
  payload.meals[0].calories = 0;
  const result = validateMealPlanPayload(payload);
  assert.equal(result.ok, false);
});

test("empty ingredients array fails", () => {
  const payload = validPayload();
  payload.meals[0].ingredients = [];
  const result = validateMealPlanPayload(payload);
  assert.equal(result.ok, false);
  assert.ok(result.errors.some((e) => e.includes("ingredients")));
});

test("ingredients with empty string entry fails", () => {
  const payload = validPayload();
  payload.meals[0].ingredients = ["1 cup oats", "  ", "2 eggs"];
  const result = validateMealPlanPayload(payload);
  assert.equal(result.ok, false);
});

test("empty cooking_instructions fails", () => {
  const payload = validPayload();
  payload.meals[0].cooking_instructions = [];
  const result = validateMealPlanPayload(payload);
  assert.equal(result.ok, false);
  assert.ok(result.errors.some((e) => e.includes("cooking_instructions")));
});

test("empty meal name fails", () => {
  const payload = validPayload();
  payload.meals[0].name = "  ";
  const result = validateMealPlanPayload(payload);
  assert.equal(result.ok, false);
});

// ----- multiple errors are reported, not just the first ----------------------

test("multiple bad meals all surface in errors", () => {
  const payload = validPayload();
  payload.meals[0].protein_g = 0;
  payload.meals[1].calories = 0;
  payload.meals[2].ingredients = [];
  const result = validateMealPlanPayload(payload);
  assert.equal(result.ok, false);
  assert.ok(result.errors.length >= 3);
});

// ----- schema shape: pin the contract iOS reads ------------------------------

test("MEAL_PLAN_TOOL schema requires every iOS-consumed field", () => {
  const required = MEAL_PLAN_TOOL.input_schema.properties.meals.items.required;
  const expected = [
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
  ];
  for (const key of expected) {
    assert.ok(required.includes(key), `schema missing required field: ${key}`);
  }
});

test("MEAL_PLAN_TOOL schema enforces minimum > 0 on protein_g and calories", () => {
  const props =
    MEAL_PLAN_TOOL.input_schema.properties.meals.items.properties;
  assert.ok(props.protein_g.minimum >= 1, "protein_g minimum must be >= 1");
  assert.ok(props.calories.minimum >= 1, "calories minimum must be >= 1");
});

test("MEAL_PLAN_TOOL schema enforces minItems on ingredients and cooking_instructions", () => {
  const props =
    MEAL_PLAN_TOOL.input_schema.properties.meals.items.properties;
  assert.equal(props.ingredients.minItems, 1);
  assert.equal(props.cooking_instructions.minItems, 1);
});
