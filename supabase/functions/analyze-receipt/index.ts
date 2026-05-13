import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.48.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const receiptSchema = {
  type: "OBJECT",
  properties: {
    storeName: { type: "STRING", nullable: true },
    totalAmount: { type: "NUMBER", nullable: true },
    expenseDate: {
      type: "STRING",
      nullable: true,
      description: "Receipt date in YYYY-MM-DD format when visible.",
    },
    category: {
      type: "STRING",
      nullable: true,
      enum: ["food", "alcohol", "hygiene", "fun", "other"],
    },
    description: {
      type: "STRING",
      nullable: true,
      description: "Short expense name suitable for the app form.",
    },
    rawText: {
      type: "STRING",
      nullable: true,
      description: "Visible receipt text, compacted when possible.",
    },
    confidence: {
      type: "NUMBER",
      minimum: 0,
      maximum: 1,
    },
    items: {
      type: "ARRAY",
      description: "Visible receipt line items that should become expense rows.",
      items: {
        type: "OBJECT",
        properties: {
          name: { type: "STRING" },
          amount: { type: "NUMBER" },
          category: {
            type: "STRING",
            enum: ["food", "alcohol", "hygiene", "fun", "other"],
          },
        },
        required: ["name", "amount", "category"],
      },
    },
  },
  required: [
    "storeName",
    "totalAmount",
    "expenseDate",
    "category",
    "description",
    "rawText",
    "confidence",
    "items",
  ],
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

    const { receiptId, rawText } = await req.json();
    if (typeof receiptId !== "string" || receiptId.length === 0) {
      return json({ error: "receiptId is required" }, 400);
    }
    const localOcrText = typeof rawText === "string" ? rawText.trim() : "";

    const { data: receipt, error: receiptError } = await admin
      .from("receipts")
      .select("id, user_id, image_path")
      .eq("id", receiptId)
      .eq("user_id", user.id)
      .single();

    if (receiptError || !receipt) {
      return json({ error: "Receipt not found" }, 404);
    }
    let imageUrl: string | null = null;
    if (!localOcrText) {
      if (!receipt.image_path) {
        return json({ error: "Receipt has no OCR text or image" }, 400);
      }

      const { data: signed, error: signedError } = await admin.storage
        .from("receipt-images")
        .createSignedUrl(receipt.image_path, 60 * 10);

      if (signedError || !signed?.signedUrl) {
        return json({ error: "Could not create receipt image URL" }, 500);
      }
      imageUrl = signed.signedUrl;
    }

    const extracted = await analyzeWithGemini({
      apiKey: geminiKey,
      rawText: localOcrText,
      imageUrl,
    });

    await admin
      .from("receipts")
      .update({
        store_name: extracted.storeName,
        total_amount: extracted.totalAmount ?? 0,
        raw_ocr_text: (extracted.rawText ?? localOcrText) || null,
        analysis_json: extracted,
      })
      .eq("id", receipt.id)
      .eq("user_id", user.id);

    return json(extracted);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : `${error}` }, 500);
  }
});

async function analyzeWithGemini({
  apiKey,
  rawText,
  imageUrl,
}: {
  apiKey: string;
  rawText: string;
  imageUrl: string | null;
}) {
  const model = Deno.env.get("GEMINI_RECEIPT_MODEL") ??
    Deno.env.get("GEMINI_MODEL") ??
    "gemini-1.5-flash";
  const parts: Array<Record<string, unknown>> = [
    {
      text: rawText
        ? `Categorize this locally extracted receipt OCR text. Prefer real purchasable line items; ignore receipt metadata, payment lines, loyalty messages, taxes, and change due unless they are the only usable amount.\n\nReceipt OCR text:\n${clipText(rawText, 14000)}`
        : "Extract this receipt into line items and app-ready expense fields.",
    },
  ];
  if (imageUrl) {
    parts.push(await imagePartFromUrl(imageUrl));
  }

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
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
                "You extract receipt details for a student budgeting app. Return only fields allowed by the schema. Use the visible grand total, not subtotal. For items, return purchasable line items with prices and categories from food, alcohol, hygiene, fun, other. If line items are unclear, return an empty items array and still provide the best single expense fields.",
            },
          ],
        },
        contents: [
          {
            role: "user",
            parts,
          },
        ],
        generationConfig: {
          temperature: 0.2,
          responseMimeType: "application/json",
          responseSchema: receiptSchema,
        },
      }),
    },
  );

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Gemini receipt analysis failed: ${body}`);
  }

  const payload = await response.json();
  const outputText = extractGeminiText(payload);
  if (!outputText) {
    throw new Error("Gemini response did not contain text output");
  }

  const parsed = JSON.parse(outputText);
  return normalizeReceipt(parsed, rawText);
}

function extractGeminiText(payload: any): string | null {
  const candidate = payload?.candidates?.[0];
  const parts = candidate?.content?.parts;
  if (!Array.isArray(parts)) return null;
  for (const part of parts) {
    if (typeof part?.text === "string") return part.text;
  }
  return null;
}

async function imagePartFromUrl(url: string) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error("Failed to download receipt image for Gemini");
  }
  const mimeType = response.headers.get("content-type") ?? "image/jpeg";
  const buffer = new Uint8Array(await response.arrayBuffer());

  return {
    inlineData: {
      mimeType,
      data: bufferToBase64(buffer),
    },
  };
}

function bufferToBase64(buffer: Uint8Array): string {
  const chunkSize = 0x8000;
  let binary = "";
  for (let i = 0; i < buffer.length; i += chunkSize) {
    binary += String.fromCharCode(...buffer.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

function normalizeReceipt(value: any, fallbackRawText: string) {
  const items = normalizeItems(value.items);
  const category = normalizeCategory(value.category) ?? dominantCategory(items) ?? "other";
  const itemTotal = items.reduce((sum, item) => sum + item.amount, 0);
  const totalAmount = typeof value.totalAmount === "number" && value.totalAmount > 0
    ? Math.round(value.totalAmount * 100) / 100
    : itemTotal > 0
    ? Math.round(itemTotal * 100) / 100
    : null;

  return {
    storeName: blankToNull(value.storeName),
    totalAmount,
    expenseDate: dateOrNull(value.expenseDate),
    category,
    description: blankToNull(value.description) ?? blankToNull(value.storeName) ??
      (items.length === 1 ? items[0].name : "Receipt purchase"),
    rawText: blankToNull(value.rawText) ?? blankToNull(fallbackRawText),
    confidence: clampNumber(value.confidence, 0, 1),
    items,
  };
}

function normalizeItems(value: unknown) {
  if (!Array.isArray(value)) return [];

  return value
    .map((item) => {
      return {
        name: blankToNull(item?.name) ?? "",
        amount: typeof item?.amount === "number" && item.amount > 0
          ? Math.round(item.amount * 100) / 100
          : 0,
        category: normalizeCategory(item?.category) ?? "other",
      };
    })
    .filter((item) => item.name.length > 0 && item.amount > 0)
    .slice(0, 80);
}

function normalizeCategory(value: unknown): string | null {
  if (typeof value !== "string") return null;
  return ["food", "alcohol", "hygiene", "fun", "other"].includes(value) ? value : null;
}

function dominantCategory(items: Array<{ category: string; amount: number }>): string | null {
  const totals = new Map<string, number>();
  for (const item of items) {
    totals.set(item.category, (totals.get(item.category) ?? 0) + item.amount);
  }

  let category: string | null = null;
  let amount = 0;
  for (const [key, value] of totals.entries()) {
    if (value > amount) {
      category = key;
      amount = value;
    }
  }
  return category;
}

function clipText(value: string, maxLength: number): string {
  return value.length <= maxLength ? value : value.slice(0, maxLength);
}

function blankToNull(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text.length === 0 ? null : text;
}

function dateOrNull(value: unknown): string | null {
  if (typeof value !== "string") return null;
  return /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : null;
}

function clampNumber(value: unknown, min: number, max: number): number {
  if (typeof value !== "number" || Number.isNaN(value)) return min;
  return Math.min(max, Math.max(min, value));
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
