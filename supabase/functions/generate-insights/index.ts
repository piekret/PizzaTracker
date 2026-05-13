import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.48.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const insightsSchema = {
  type: "OBJECT",
  properties: {
    summary: { type: "STRING" },
    absurd_purchases: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          name: { type: "STRING" },
          amount: { type: "NUMBER" },
          category: { type: "STRING" },
          date: { type: "STRING" },
          note: { type: "STRING", nullable: true },
        },
        required: ["name", "amount", "category", "date", "note"],
      },
    },
    category_callouts: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          category: { type: "STRING" },
          amount: { type: "NUMBER" },
          note: { type: "STRING" },
        },
        required: ["category", "amount", "note"],
      },
    },
  },
  required: ["summary", "absurd_purchases", "category_callouts"],
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
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!geminiKey || !supabaseUrl || !serviceRoleKey) {
      return json({ error: "Function environment is not configured" }, 500);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "").trim();
    if (!token) {
      return json({ error: "Missing authorization token" }, 401);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: userData, error: userError } = await admin.auth.getUser(token);
    const user = userData.user;
    if (userError || !user) {
      return json({ error: "Invalid authorization token" }, 401);
    }

    const payload = await req.json();
    const month = normalizeMonth(payload?.month);
    const force = payload?.force === true;
    if (!month) {
      return json({ error: "Invalid month format. Use YYYY-MM." }, 400);
    }
    const monthStart = `${month}-01`;
    const nextMonthStart = addOneMonth(monthStart);

    const cached = await admin
      .from("insights_monthly")
      .select("payload_json")
      .eq("user_id", user.id)
      .eq("month", monthStart)
      .maybeSingle();

    if (!force && cached.data?.payload_json) {
      return json({
        cached: true,
        month,
        insights: cached.data.payload_json,
      });
    }

    const { data: expenses } = await admin
      .from("expense_items")
      .select("name, amount, category, expense_date")
      .eq("user_id", user.id)
      .gte("expense_date", monthStart)
      .lt("expense_date", nextMonthStart)
      .order("expense_date", { ascending: false })
      .limit(250);

    if (!expenses || expenses.length == 0) {
      const emptyInsights = buildEmptyInsights();
      await admin.from("insights_monthly").upsert({
        user_id: user.id,
        month: monthStart,
        payload_json: emptyInsights,
        updated_at: new Date().toISOString(),
      });

      return json({ cached: false, month, insights: emptyInsights });
    }

    const inputSummary = summarizeExpenses(expenses ?? []);
    const model = Deno.env.get("GEMINI_INSIGHTS_MODEL") ??
      Deno.env.get("GEMINI_MODEL") ??
      "gemini-2.5-flash";

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          systemInstruction: {
            parts: [
              {
                text:
                  "You are a brutally honest student budget analyst. Return insights in JSON only. Keep summary to 1-2 short sentences. Absurd purchases should be humorous but grounded in the data.",
              },
            ],
          },
          contents: [
            {
              role: "user",
              parts: [
                {
                  text:
                    `Month: ${month}. Expense stats: ${inputSummary}. Use only these expenses for your analysis: ${JSON.stringify(expenses)}.`,
                },
              ],
            },
          ],
          generationConfig: {
            temperature: 0.6,
            responseMimeType: "application/json",
            responseSchema: insightsSchema,
          },
        }),
      },
    );

    if (!response.ok) {
      const body = await response.text();
      return json({ error: `Gemini insights failed: ${body}` }, 500);
    }

    const data = await response.json();
    const outputText = extractGeminiText(data);
    if (!outputText) {
      return json({ error: "Gemini response did not contain text output" }, 500);
    }

    const insights = JSON.parse(outputText);

    await admin.from("insights_monthly").upsert({
      user_id: user.id,
      month: monthStart,
      payload_json: insights,
      updated_at: new Date().toISOString(),
    });

    return json({ cached: false, month, insights });
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

function normalizeMonth(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  if (/^\d{4}-\d{2}$/.test(trimmed)) {
    return trimmed;
  }
  return null;
}

function addOneMonth(monthStart: string): string {
  const [yearText, monthText] = monthStart.split("-");
  const year = Number(yearText);
  const month = Number(monthText);
  const nextMonth = month === 12 ? 1 : month + 1;
  const nextYear = month === 12 ? year + 1 : year;
  return `${nextYear.toString().padStart(4, "0")}-${
    nextMonth.toString().padStart(2, "0")
  }-01`;
}

function summarizeExpenses(expenses: Array<Record<string, unknown>>) {
  if (expenses.length === 0) {
    return "No expenses recorded.";
  }
  const total = expenses.reduce((sum, expense) => {
    const amount = typeof expense.amount === "number" ? expense.amount : 0;
    return sum + amount;
  }, 0);
  const categories = new Map<string, number>();
  for (const expense of expenses) {
    const category = typeof expense.category === "string"
      ? expense.category
      : "other";
    const amount = typeof expense.amount === "number" ? expense.amount : 0;
    categories.set(category, (categories.get(category) ?? 0) + amount);
  }
  const topCategory = [...categories.entries()].sort((a, b) => b[1] - a[1])[0];
  return `Total spend ${total.toFixed(2)} across ${expenses.length} items. Top category: ${topCategory?.[0] ?? "other"}.`;
}

function buildEmptyInsights() {
  return {
    summary: "No expenses recorded this month yet.",
    absurd_purchases: [],
    category_callouts: [],
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
