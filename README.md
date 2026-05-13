# PizzaTracker

Flutter student budget tracker with Supabase auth/database integration.

Receipts are read with local ML Kit OCR first, then categorized through a Supabase Edge Function so OpenAI keys never ship with the app.
Recipe suggestions are generated through a separate Supabase Edge Function using the OpenAI API.

## Local Setup

Fill `.env` in the project root. For plain Flutter runs, the app reads client-safe Supabase values from generated `assets/env/client.env`.

The scripts keep local setup repeatable: Flutter does not load the root `.env` automatically, and the full `.env` can contain server-only secrets. The scripts copy or pass only `SUPABASE_URL` and `SUPABASE_ANON_KEY`, which are safe for the client app when Supabase RLS policies are configured correctly.

If you changed Supabase values in `.env`, sync the generated client asset once:

```bash
./scripts/sync_client_env.sh
```

On Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync_client_env.ps1
```

Then run:

```bash
flutter run
```

Keep `OPENAI_API_KEY`, service-role keys, Firebase admin credentials, and database passwords in `.env` only. Do not put them in `.env.client` or `assets/env/client.env`; the generated asset file is bundled into the Flutter app.

For recipe generation, set the following secrets on Supabase:

```bash
supabase secrets set GEMINI_API_KEY=...
supabase secrets set GEMINI_RECIPE_MODEL=gemini-2.5-flash
```

You can still run with explicit dart defines if needed:

```bash
./scripts/flutter_run_from_env.sh
```

On Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\flutter_run_from_env.ps1
```

## Checks

```bash
flutter analyze
flutter test
```

## Database

The database schema is tracked in `supabase/migrations`. Apply it with the Supabase CLI from the project root:

```bash
supabase db push
```

The migration creates the app tables, RLS policies, receipt image bucket policies, dashboard views, and the `get_budget_snapshot` RPC. `docs/supabase-ai-prompt.md` remains a reference for the intended schema.

## Edge Functions

```bash
supabase functions deploy analyze-receipt
supabase functions deploy generate-recipes
```
