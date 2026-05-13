# 🍕 PizzaTracker — "Can I Actually Afford This?"

> A smart student budget manager with receipt OCR, AI-generated recipes, and a brutally honest analysis of what you did with your scholarship money.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Core Features](#2-core-features)
3. [Application Architecture](#3-application-architecture)
4. [Tech Stack](#4-tech-stack)
5. [Database Schema](#5-database-schema)
6. [Data Flow](#6-data-flow)
7. [External Integrations](#7-external-integrations)
8. [App Screens](#8-app-screens)
9. [Non-Functional Requirements](#9-non-functional-requirements)
10. [Development Roadmap](#10-development-roadmap)

---

## 1. Project Overview

**PizzaTracker** is a Flutter mobile application targeting students who regularly lose track of their budget halfway through the month. Instead of yet another boring expense tracker, the app acts like an honest friend — it scans receipts with the camera, automatically categorizes spending, and answers one fundamental question: **can I order pizza tonight, or is it pasta again?**

The central UX element is the **Desperation Index** — a number from 0 to 100 calculated in real time based on the remaining budget, days left until the end of the month, and the user's spending history. The higher the index, the more the app switches into "crisis mode" and starts serving recipes with 4 ingredients.

The project is built as a mobile application (Android + iOS) using **Flutter**, with a backend powered by **Supabase** and integrations with **Google ML Kit** and the **Gemini API**.

---

## 2. Core Features

### 2.1 Receipt Scanner (OCR)

The user takes a photo of any store receipt (supermarket, fast food, convenience store). The app then:

- Processes the image **locally** using Google ML Kit Text Recognition (offline, zero API cost)
- Extracts line items, prices, and the total amount
- Sends the extracted text to the **Gemini API**, which categorizes each item (`food`, `alcohol`, `hygiene`, `fun`, `other`)
- Shows the user a list of items with the option to manually correct categories before saving
- Persists the expense to **Supabase Postgres**

Supported input formats: camera photo, gallery photo, PDF (e.g. an e-receipt).

### 2.2 Desperation Index 📊

The app's headline metric, computed in real time:

```
Desperation Index = f(remaining_budget, days_until_reset, avg_daily_from_history)
```

| Level | Range | What it means | UI Color |
|-------|-------|---------------|----------|
| All good | 0–20 | Order pizza with delivery and tip the driver | 🟢 Green |
| Watch out | 21–45 | Pizza yes, but cook your own breakfast | 🟡 Yellow |
| Economy mode | 46–70 | Cook at home, skip the coffee shops | 🟠 Orange |
| SOS | 71–90 | Pasta with ketchup, maybe call your parents | 🔴 Red |
| Apocalypse | 91–100 | Check what's in the freezer. Good luck. | ☠️ Black |

The index updates automatically after every recorded expense and at midnight each night (as the day counter ticks down).

### 2.3 AI Fridge Recipes 🤖

In "End of Month" mode (Desperation Index > 60) a **What to Cook** section unlocks. The user types in or selects from a list whatever they have in the fridge/cupboards — the Gemini API generates:

- 3 meal suggestions using exactly those ingredients
- Estimated cost per meal
- A short step-by-step recipe
- Calorie count (at least something positive comes out of this)

The system prompt instructs the model to act as a "student chef who has seen it all" — recipes are written with humor but are genuinely useful.

### 2.4 Financial Stupidity Charts 📈

A statistics section powered by fl_chart:

- **Daily spending** — bar chart with a daily budget guideline
- **Where the money went** — pie chart by category
- **"When the money ran out" vs "when I planned"** — comparison across previous months
- **Top 3 most absurd purchases of the month** — surfaced by AI from transaction history

### 2.5 Push Notifications (FCM)

| Notification Type | Trigger | Example Content |
|------------------|---------|-----------------|
| Morning reminder | Daily 9:00 AM | "You can spend $34 today. Don't beat Tuesday's record." |
| Budget alert | Index > 70 | "$47 left, 11 days to go. Start cooking." |
| End of month | 3 days remaining | "48h until next transfer. Count your instant noodles." |
| Monthly win | 1st of new month | "You survived! Spent $120 less than last month." |
| Spending anomaly | Outlier detected | "Hey, $45 at 7-Eleven at 2am? Everything ok?" |

### 2.6 Budget Setup & Income Calendar

The user configures:

- Total monthly budget
- Expected income dates (scholarship, bank transfer from parents, part-time job paycheck)
- Fixed monthly expenses (rent, internet, subscriptions) — deducted automatically from the disposable budget

The app operates exclusively on **disposable budget** (after fixed costs), so the Desperation Index is actually meaningful.

---

## 3. Application Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Flutter App                          │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │  Camera  │  │  Budget  │  │  Charts  │  │Recipes │  │
│  │  + OCR   │  │  Screens │  │ fl_chart │  │   AI   │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───┬────┘  │
│       │              │              │             │       │
│  ┌────▼──────────────▼──────────────▼─────────────▼───┐  │
│  │               Riverpod State Layer                  │  │
│  └────┬──────────────────────────────────────────┬────┘  │
└───────┼──────────────────────────────────────────┼───────┘
        │                                          │
        ▼                                          ▼
┌───────────────┐                      ┌───────────────────┐
│  Google ML    │                      │   Supabase        │
│  Kit (OCR)    │                      │   - Postgres DB   │
│  (on-device)  │                      │   - Auth          │
└───────┬───────┘                      │   - Edge Functions│
        │                              └─────────┬─────────┘
        ▼                                        │
┌───────────────┐                                ▼
│   Gemini      │◄───────────────── Edge Function (proxy)
│  API          │   (categorization,
│               │    recipes, analysis)
└───────────────┘
        ▲
        │
┌───────────────┐
│  Firebase     │
│  Cloud Msg.   │
│  (FCM)        │
└───────────────┘
```

**Key architectural decisions:**

- The Gemini API is called **exclusively through a Supabase Edge Function** (Deno) — the API key never reaches the mobile client
- OCR runs **offline on-device** via ML Kit — no cost per scan
- Supabase Row Level Security (RLS) ensures users only ever see their own data
- App state is managed with **Riverpod** (or BLoC — interchangeable)

---

## 4. Tech Stack

### Frontend

| Technology | Version | Purpose |
|-----------|---------|---------|
| Flutter | 3.x | Mobile framework (Android + iOS) |
| Dart | 3.x | Programming language |
| Riverpod | 2.x | State management |
| fl_chart | 0.68+ | Statistics charts |
| google_mlkit_text_recognition | latest | Receipt OCR (offline) |
| image_picker | latest | Camera / gallery input |
| flutter_local_notifications | latest | Local push notifications |
| intl | latest | Date and currency formatting |
| go_router | latest | Navigation |

### Backend

| Technology | Purpose |
|-----------|---------|
| Supabase (Postgres) | Primary database — expenses, categories, budgets |
| Supabase Auth | Authentication (email/password + Google OAuth) |
| Supabase Edge Functions (Deno) | Gemini API proxy, server-side logic, cron jobs |
| Supabase Realtime | Cross-device sync (optional) |
| Firebase Cloud Messaging | Push notifications |

### External APIs

| API | Purpose | Cost Model |
|-----|---------|------------|
| Google ML Kit Text Recognition | Receipt OCR | **Free** (on-device) |
| Gemini API (Gemini model) | Categorization, recipes, analysis | Pay-per-token |
| Firebase Cloud Messaging | Push notifications | **Free** up to quota |

---

## 5. Database Schema

### Table: `users_profiles`
```sql
CREATE TABLE users_profiles (
  id                UUID PRIMARY KEY REFERENCES auth.users(id),
  display_name      TEXT,
  monthly_budget    NUMERIC(10,2) NOT NULL DEFAULT 0,
  budget_reset_day  INTEGER DEFAULT 1,   -- day of month budget resets
  currency          TEXT DEFAULT 'USD',
  created_at        TIMESTAMPTZ DEFAULT NOW()
);
```

### Table: `fixed_expenses`
```sql
CREATE TABLE fixed_expenses (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users_profiles(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,             -- e.g. "Rent", "Spotify"
  amount      NUMERIC(10,2) NOT NULL,
  billing_day INTEGER,                   -- day of month charged
  is_active   BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

### Table: `receipts`
```sql
CREATE TABLE receipts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES users_profiles(id) ON DELETE CASCADE,
  store_name    TEXT,                    -- extracted by AI from OCR text
  total_amount  NUMERIC(10,2) NOT NULL,
  raw_ocr_text  TEXT,                    -- raw ML Kit output
  scanned_at    TIMESTAMPTZ DEFAULT NOW(),
  image_path    TEXT                     -- Supabase Storage (optional)
);
```

### Table: `expense_items`
```sql
CREATE TABLE expense_items (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_id     UUID REFERENCES receipts(id) ON DELETE CASCADE,
  user_id        UUID REFERENCES users_profiles(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,
  amount         NUMERIC(10,2) NOT NULL,
  category       TEXT NOT NULL,          -- enum: food, alcohol, hygiene, fun, other
  ai_categorized BOOLEAN DEFAULT TRUE,   -- whether AI assigned the category
  expense_date   DATE NOT NULL,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);
```

### Table: `income_events`
```sql
CREATE TABLE income_events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES users_profiles(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,           -- e.g. "Scholarship", "Parents", "Work"
  amount        NUMERIC(10,2) NOT NULL,
  expected_day  INTEGER NOT NULL,        -- day of month
  is_recurring  BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
```

### View: `v_monthly_summary`
```sql
CREATE VIEW v_monthly_summary AS
SELECT
  ei.user_id,
  DATE_TRUNC('month', ei.expense_date)                                  AS month,
  SUM(ei.amount)                                                         AS total_spent,
  SUM(CASE WHEN ei.category = 'food'    THEN ei.amount ELSE 0 END)      AS food_spent,
  SUM(CASE WHEN ei.category = 'alcohol' THEN ei.amount ELSE 0 END)      AS alcohol_spent,
  COUNT(DISTINCT ei.receipt_id)                                          AS receipt_count
FROM expense_items ei
GROUP BY ei.user_id, DATE_TRUNC('month', ei.expense_date);
```

**Row Level Security:**
```sql
ALTER TABLE expense_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own data only" ON expense_items
  USING (auth.uid() = user_id);
-- applied to all tables identically
```

---

## 6. Data Flow

### Flow 1: Scanning a Receipt

```
User opens the camera
        │
        ▼
Takes a photo of a receipt
        │
        ▼
ML Kit Text Recognition (on-device)
  → raw OCR text
        │
        ▼
Supabase Edge Function: POST /categorize-receipt
  payload: { raw_text: "..." }
        │
        ▼
Edge Function → Gemini API
  prompt: "Extract line items from this receipt and assign categories..."
  response: JSON with items + categories + store name
        │
        ▼
App displays item list for user review
  (user can correct categories before saving)
        │
        ▼
Save to Supabase: receipts + expense_items
        │
        ▼
Recalculate Desperation Index
        │
        ▼
UI update via Riverpod provider
```

### Flow 2: Generating Recipes

```
User opens "What to Cook"
        │
        ▼
Enters available ingredients (typed or selected from a list)
        │
        ▼
Supabase Edge Function: POST /generate-recipes
  payload: { ingredients: [...], desperation_index: 78 }
        │
        ▼
Edge Function → Gemini API
  system: "You are a student chef with 10 years of dorm-room experience..."
  user: "I have: pasta, eggs, soy sauce, onion. Desperation Index: 78/100."
        │
        ▼
Response: 3 recipes as JSON
  { name, ingredients_used, steps[], estimated_cost, calories }
        │
        ▼
Recipes displayed in the app
```

---

## 7. External Integrations

### Google ML Kit — Text Recognition

```dart
// pubspec.yaml dependency:
// google_mlkit_text_recognition: ^0.11.0

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<String> extractTextFromImage(String imagePath) async {
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final inputImage = InputImage.fromFilePath(imagePath);
  final recognizedText = await textRecognizer.processImage(inputImage);
  await textRecognizer.close();
  return recognizedText.text;
}
```

**Why ML Kit and not Cloud Vision API?**
- Cloud Vision costs ~$1.50 / 1,000 images
- ML Kit runs fully offline, is free, and is accurate enough for printed receipts
- No receipt image is ever transmitted to an external server (privacy win)

### Supabase Edge Function — Gemini API Proxy

```typescript
// supabase/functions/categorize-receipt/index.ts
Deno.serve(async (req) => {
  const { raw_text } = await req.json();
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{
          role: "user",
          parts: [{ text: `Analyze this receipt text and return a JSON object with fields:
          - store_name (string)
          - items: array of { name, amount (float), category }
          Categories: food, alcohol, hygiene, fun, other.
          Reply with ONLY valid JSON, no surrounding text.
          
          Receipt text:
          ${raw_text}` }],
        }],
        generationConfig: { responseMimeType: "application/json" },
      }),
    },
  );

  const data = await response.json();
  const content = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
  const parsed = JSON.parse(content);

  return new Response(JSON.stringify(parsed), {
    headers: { "Content-Type": "application/json" },
  });
});
```

### Firebase Cloud Messaging — Push Notifications

FCM handles remote notifications (server → device). The FCM token is saved to Supabase on login. A Supabase Edge Function runs as a daily cron job, iterates over users, and sends personalized notifications via the FCM Admin SDK.

```typescript
// supabase/functions/daily-notification/index.ts
// Triggered by pg_cron every day at 9:00 AM

const { data: users } = await supabase
  .from("users_profiles")
  .select("*, fcm_token");

for (const user of users) {
  const budget = await calculateRemainingBudget(user.id);
  const message = buildDailyMessage(budget);
  await sendFCMNotification(user.fcm_token, message);
}
```

---

## 8. App Screens

### Screen 1: Dashboard (Home)

```
┌─────────────────────────────┐
│  🍕 PizzaTracker            │
│                             │
│  ┌─────────────────────┐    │
│  │  DESPERATION INDEX  │    │
│  │                     │    │
│  │      🟠  64/100     │    │
│  │                     │    │
│  │    Economy Mode     │    │
│  │  Cook at home.      │    │
│  │  Skip the coffee.   │    │
│  └─────────────────────┘    │
│                             │
│  Remaining:    $187.00      │
│  Days left:    14           │
│  Daily limit:  $13.36       │
│                             │
│  [ + Add Expense ]          │
│  [ 🍳 What to Cook? ]       │
│                             │
│  Recent expenses:           │
│  • Walmart     $43.20  🟡   │
│  • 7-Eleven    $12.80  🔴   │
│  • Kebab place $18.00  🟡   │
└─────────────────────────────┘
```

### Screen 2: Receipt Scanner

```
┌─────────────────────────────┐
│  ← Scan Receipt             │
│                             │
│  ┌─────────────────────┐    │
│  │                     │    │
│  │   [CAMERA PREVIEW]  │    │
│  │                     │    │
│  │  [ 📷 Take Photo ]  │    │
│  └─────────────────────┘    │
│                             │
│  or  [ 🖼 From Gallery ]    │
│                             │
│  ── After scanning ──       │
│                             │
│  Walmart  •  $43.20         │
│  ┌──────────────────────┐   │
│  │ Pasta      $1.49 🍝  │   │
│  │ Beer       $4.99 🍺  │   │
│  │ Shampoo    $8.99 🧴  │   │
│  │ Chips      $3.79 🍟  │   │
│  └──────────────────────┘   │
│                             │
│  [ ✅ Save ]                │
└─────────────────────────────┘
```

### Screen 3: Statistics

```
┌─────────────────────────────┐
│  📊 Stats — November        │
│                             │
│  [daily bar chart]          │
│  █▄█▄▄█████▄█▄▄▄▄▄▄         │
│  1  5  10  15  20  25       │
│                             │
│  Total spent:    $823       │
│  Budget:       $1,000       │
│  Remaining:      $177 ✅    │
│                             │
│  [category pie chart]       │
│      🍝 Food       52%      │
│      🍺 Alcohol    18%      │
│      🧴 Hygiene    11%      │
│      🎮 Fun        19%      │
│                             │
│  🏆 Most absurd purchase:   │
│  7-Eleven at 2:47 AM        │
│  $23.40 🤡                  │
└─────────────────────────────┘
```

### Screen 4: What to Cook

```
┌─────────────────────────────┐
│  🍳 What to Cook?           │
│  Desperation Index: 78 🔴   │
│                             │
│  What's in your fridge?     │
│  ┌──────────────────────┐   │
│  │ pasta  ✅            │   │
│  │ eggs   ✅            │   │
│  │ onion  ✅            │   │
│  │ [+ add ingredient]   │   │
│  └──────────────────────┘   │
│                             │
│  [ 🤖 Generate Recipes ]    │
│                             │
│  ── Results ──              │
│                             │
│  1. Pasta Aglio e Uova      │
│     ~$1.20 • 480 kcal       │
│     "A classic. You've      │
│      made this 6 times      │
│      this month." 👀        │
│                             │
│  2. Egg Fried Rice (no rice)│
│     ~$0.90 • 390 kcal       │
│  3. French Onion... pasta   │
│     ~$1.10 • 520 kcal       │
└─────────────────────────────┘
```

---

## 9. Non-Functional Requirements

### Performance
- On-device OCR: < 2 seconds for a standard A5 receipt
- Gemini API response (categorization): < 4 seconds
- Dashboard load (cached): < 500ms
- Dashboard load (cold start, from network): < 2 seconds

### Offline Support
- Dashboard and expense history available offline (Supabase local cache / Hive)
- Receipt OCR works offline (ML Kit on-device)
- AI categorization requires internet — the app notifies the user and allows manual category assignment as a fallback

### Security
- Gemini API key stored exclusively in Supabase Edge Function environment variables — never shipped in the app binary
- Supabase RLS — users cannot access other users' data under any circumstances
- FCM tokens refreshed on every app launch
- Financial data never leaves Supabase (receipt images are optional and stored only in Supabase Storage)

### Privacy
- Receipt photos are **not stored** by default — only the extracted OCR text is saved
- Photo storage can be enabled in settings (Supabase Storage)
- No behavioral analytics with personal financial data

---

*Course project — Mobile Applications | Flutter + Supabase + Gemini API*
