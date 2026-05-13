import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const recipeSchema = {
  type: "OBJECT",
  properties: {
    recipes: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          name: { type: "STRING" },
          ingredients_used: { type: "ARRAY", items: { type: "STRING" } },
          steps: { type: "ARRAY", items: { type: "STRING" } },
          estimated_cost: { type: "NUMBER", nullable: true },
          calories: { type: "NUMBER", nullable: true },
          note: { type: "STRING", nullable: true },
        },
        required: [
          "name",
          "ingredients_used",
          "steps",
          "estimated_cost",
          "calories",
          "note",
        ],
      },
    },
  },
  required: ["recipes"],
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) {
      return json({ error: "Function environment is not configured" }, 500);
    }

    const payload = await req.json();
    const ingredients = Array.isArray(payload?.ingredients)
      ? payload.ingredients.map((item: unknown) => `${item}`.trim()).filter(Boolean)
      : [];
    const desperationIndex = typeof payload?.desperationIndex === "number"
      ? payload.desperationIndex
      : 0;

    if (ingredients.length < 2) {
      return json({ error: "At least two ingredients are required" }, 400);
    }

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${
        Deno.env.get("GEMINI_RECIPE_MODEL") ??
        Deno.env.get("GEMINI_MODEL") ??
        "gemini-1.5-flash"
      }:generateContent?key=${geminiKey}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          systemInstruction: {
            parts: [
              {
                text:
                  "You are a student chef with 10 years of dorm-room experience. Produce 3 recipes using ONLY the provided ingredients and common pantry staples like salt, pepper, oil, or water. Keep the tone honest and slightly funny but useful. Return JSON only.",
              },
            ],
          },
          contents: [
            {
              role: "user",
              parts: [
                {
                  text:
                    `Ingredients: ${ingredients.join(", ")}. Desperation Index: ${desperationIndex}/100.`,
                },
              ],
            },
          ],
          generationConfig: {
            temperature: 0.6,
            responseMimeType: "application/json",
            responseSchema: recipeSchema,
          },
        }),
      },
    );

    if (!response.ok) {
      const body = await response.text();
      return json({ error: `Gemini recipe generation failed: ${body}` }, 500);
    }

    const data = await response.json();
    const outputText = extractGeminiText(data);
    if (!outputText) {
      return json({ error: "Gemini response did not contain text output" }, 500);
    }

    const parsed = JSON.parse(outputText);
    return json({ recipes: normalizeRecipes(parsed.recipes) });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : `${error}` }, 500);
  }
});

function extractGeminiText(payload: any): string | null {
  const candidate = payload?.candidates?.[0];
  const parts = candidate?.content?.parts;
  if (!Array.isArray(parts)) return null;
  for (const part of parts) {
    if (typeof part?.text === "string") return part.text;
  }
  return null;
}

function normalizeRecipes(value: any) {
  if (!Array.isArray(value)) return [];

  return value
    .map((recipe) => ({
      name: `${recipe?.name ?? ""}`.trim(),
      ingredients_used: Array.isArray(recipe?.ingredients_used)
        ? recipe.ingredients_used.map((item: unknown) => `${item}`.trim()).filter(Boolean)
        : [],
      steps: Array.isArray(recipe?.steps)
        ? recipe.steps.map((item: unknown) => `${item}`.trim()).filter(Boolean)
        : [],
      estimated_cost: typeof recipe?.estimated_cost === "number"
        ? Math.round(recipe.estimated_cost * 100) / 100
        : null,
      calories: typeof recipe?.calories === "number" ? Math.round(recipe.calories) : null,
      note: recipe?.note ? `${recipe.note}`.trim() : null,
    }))
    .filter((recipe) => recipe.name.length > 0)
    .slice(0, 3);
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
