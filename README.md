# PizzaTracker

PizzaTracker is a Flutter budget tracker for students. It tracks day-to-day spending, scans receipts, calculates a live Desperation Index, and generates survival recipes when the budget starts looking grim.

The app uses Supabase for auth, Postgres data, storage, and Edge Functions. Receipt OCR starts locally with Google ML Kit, then Supabase Edge Functions call Gemini so AI keys never ship in the Flutter app.

## Features

- Email/password auth through Supabase.
- Per-account budget data with Row Level Security and client cache scoped to the signed-in user.
- Manual expense entry and receipt-based expense entry.
- Receipt scan flow with camera/gallery image picking, local OCR, Gemini receipt analysis, and editable line-item review.
- Dashboard with remaining budget, spent amount, daily limit, days left, spending mix, recent expenses, fixed costs, income schedule, and Desperation Index.
- Stats screen with spending summaries and AI monthly insights.
- Recipe generator powered by Gemini, unlocked by higher Desperation Index values.
- Client-side budget snapshot calculation from current user rows, so scanned receipt items update the dashboard immediately when saved for the current budget period.

## Tech Stack

- Flutter / Dart
- Riverpod for state management
- Supabase Auth, Postgres, Storage, and Edge Functions
- Google ML Kit Text Recognition for on-device OCR
- Gemini API behind Supabase Edge Functions
- `fl_chart` for charts

## Project Layout

```text
lib/
  main.dart
  src/
    app_data.dart              # providers, repository, models
    pizza_tracker_app.dart     # app shell and part imports
    auth/                      # auth gate and auth form
    dashboard/                 # dashboard, budget cards, stats
    expenses/                  # manual expenses, receipt scan/review/history
    planning/                  # budget/fixed expense/income sheets
    recipes/                   # recipe generation UI
supabase/
  migrations/                  # database schema, RLS, policies, RPCs
  functions/                   # Deno Edge Functions for AI features
scripts/                       # local env sync and run helpers
test/                          # widget and data model tests
```

## Requirements

- Flutter SDK compatible with Dart `^3.11.5`
- Supabase CLI for database/function deployment
- A Supabase project
- Gemini API key for AI receipt analysis, recipes, and insights

## Local Setup

1. Install dependencies:

```bash
flutter pub get
```

2. Copy the environment example and fill in local values:

```bash
cp .env.example .env
```

On Windows PowerShell:

```powershell
Copy-Item .env.example .env
```

3. Set at least these client values in `.env`:

```text
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

4. Sync the client-safe values into the Flutter asset used by normal `flutter run`:

```bash
./scripts/sync_client_env.sh
```

On Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync_client_env.ps1
```

5. Run the app:

```bash
flutter run
```

The generated `assets/env/client.env` is bundled into the Flutter app. Only put client-safe values there: `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

Do not put `GEMINI_API_KEY`, service-role keys, database passwords, Firebase admin credentials, or other secrets in `.env.client` or `assets/env/client.env`.

## Alternative Run From `.env`

If you want to pass client values as Dart defines instead of using the generated asset:

```bash
./scripts/flutter_run_from_env.sh
```

On Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\flutter_run_from_env.ps1
```

## Supabase Setup

Apply the database schema and policies from the project root:

```bash
supabase db push
```

The migrations create the core app tables, RLS policies, receipt image storage policies, dashboard views, AI insight storage, and supporting RPCs.

Set Edge Function secrets in Supabase:

```bash
supabase secrets set GEMINI_API_KEY=your-gemini-key
supabase secrets set GEMINI_RECEIPT_MODEL=gemini-2.5-flash
supabase secrets set GEMINI_RECIPE_MODEL=gemini-2.5-flash
supabase secrets set GEMINI_INSIGHTS_MODEL=gemini-2.5-flash
```

Deploy Edge Functions:

```bash
supabase functions deploy analyze-receipt
supabase functions deploy generate-recipes
supabase functions deploy generate-insights
```

## Checks

Run these before committing app changes:

```bash
flutter analyze
flutter test
```

## Important Data Notes

- All user-owned tables are scoped by `user_id` and protected with Supabase RLS.
- Riverpod account data is tied to the current Supabase user, so switching accounts invalidates cached account data.
- Recent Expenses shows the latest expenses regardless of budget period.
- Remaining budget, Spending Mix, and Desperation Index count expenses inside the current budget period.
- Receipt line-item review defaults the expense date to today. If you manually choose an older receipt date outside the current budget period, the items will still appear in Recent Expenses but will not affect the current Remaining/Spending Mix/Desperation Index.

## Receipt Flow

1. Pick camera or gallery.
2. ML Kit extracts local OCR text when possible.
3. The image is uploaded to Supabase Storage and a receipt row is created.
4. `analyze-receipt` calls Gemini through a Supabase Edge Function.
5. If line items are detected, the app opens a review screen where names, amounts, categories, and date can be edited.
6. Saving inserts one expense row per line item and refreshes dashboard budget/spending providers.

## Common Troubleshooting

If the app shows the setup screen:

- Check that `.env` has `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- Run the env sync script again.
- Fully restart the app instead of hot reload.

If receipt AI fails:

- Confirm the Supabase Edge Functions are deployed.
- Confirm `GEMINI_API_KEY` is set as a Supabase secret.
- Check Supabase function logs for the failing function.

If scanned receipt items show in Recent Expenses but not in Remaining or Spending Mix:

- Check the date selected in the receipt review screen.
- Only expenses inside the active budget period affect those dashboard cards.

If data appears shared between users:

- Fully restart the app and test sign-in again.
- Confirm the latest client code is running.
- Confirm Supabase RLS policies from `supabase/migrations` have been applied.

## Git Hygiene

Do not commit local secrets or generated build output. In particular, avoid committing:

- `.env`
- `assets/env/client.env` if it contains real project values
- `supabase/.temp/`
- `build/`
- `.dart_tool/`

Generated Flutter plugin registrant files may change after running on desktop platforms. Review them before committing and only include them when the plugin/platform change is intentional.
