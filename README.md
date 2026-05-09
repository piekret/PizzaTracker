# PizzaTracker

Flutter student budget tracker with Supabase auth/database integration.

## Local Setup

Fill `.env` in the project root. For plain Flutter runs, the app reads client-safe Supabase values from generated `assets/env/client.env`.

If you changed Supabase values in `.env`, sync the generated client asset once:

```bash
./scripts/sync_client_env.sh
```

Then run:

```bash
flutter run
```

Keep `OPENAI_API_KEY`, service-role keys, Firebase admin credentials, and database passwords in `.env` only. Do not put them in `.env.client` or `assets/env/client.env`; the generated asset file is bundled into the Flutter app.

You can still run with explicit dart defines if needed:

```bash
./scripts/flutter_run_from_env.sh
```

## Checks

```bash
flutter analyze
flutter test
```

## Database

The current MVP expects the Supabase schema from `docs/supabase-ai-prompt.md`, including `users_profiles`, `expense_items`, and the `get_budget_snapshot` RPC.
