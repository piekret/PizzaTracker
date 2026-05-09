# Supabase AI Prompt

Paste the prompt below into Supabase SQL Editor AI and ask it to generate a migration. It should return SQL only.

```text
Create a complete Supabase Postgres schema for a Flutter student budget app called PizzaTracker.

Return one SQL migration only. Do not include explanations. The SQL must be safe to run in Supabase SQL Editor. Use the public schema. Use auth.users for authentication; do not create a custom users table.

Requirements:

1. Enable required extensions.
- Enable pgcrypto for gen_random_uuid().

2. Create an enum named expense_category with exactly these values:
- food
- alcohol
- hygiene
- fun
- other

3. Create these tables.

users_profiles:
- id uuid primary key references auth.users(id) on delete cascade
- display_name text
- monthly_budget numeric(10,2) not null default 0
- budget_reset_day integer not null default 1, checked between 1 and 28
- currency text not null default 'USD'
- timezone text not null default 'Europe/Warsaw'
- created_at timestamptz not null default now()
- updated_at timestamptz not null default now()
- Constraints: monthly_budget >= 0, currency length between 3 and 8

fixed_expenses:
- id uuid primary key default gen_random_uuid()
- user_id uuid not null references users_profiles(id) on delete cascade
- name text not null
- amount numeric(10,2) not null
- billing_day integer not null checked between 1 and 28
- is_active boolean not null default true
- created_at timestamptz not null default now()
- updated_at timestamptz not null default now()
- Constraints: amount >= 0, trimmed name is not empty

income_events:
- id uuid primary key default gen_random_uuid()
- user_id uuid not null references users_profiles(id) on delete cascade
- name text not null
- amount numeric(10,2) not null
- expected_day integer not null checked between 1 and 28
- is_recurring boolean not null default true
- created_at timestamptz not null default now()
- updated_at timestamptz not null default now()
- Constraints: amount >= 0, trimmed name is not empty

receipts:
- id uuid primary key default gen_random_uuid()
- user_id uuid not null references users_profiles(id) on delete cascade
- store_name text
- total_amount numeric(10,2) not null
- raw_ocr_text text
- scanned_at timestamptz not null default now()
- image_path text
- created_at timestamptz not null default now()
- updated_at timestamptz not null default now()
- Constraints: total_amount >= 0

expense_items:
- id uuid primary key default gen_random_uuid()
- receipt_id uuid references receipts(id) on delete set null
- user_id uuid not null references users_profiles(id) on delete cascade
- name text not null
- amount numeric(10,2) not null
- category expense_category not null default 'other'
- ai_categorized boolean not null default false
- expense_date date not null default current_date
- created_at timestamptz not null default now()
- updated_at timestamptz not null default now()
- Constraints: amount >= 0, trimmed name is not empty
- This table must support manual expenses, so receipt_id must be nullable.

device_tokens:
- id uuid primary key default gen_random_uuid()
- user_id uuid not null references users_profiles(id) on delete cascade
- token text not null unique
- platform text not null checked in ('android', 'ios', 'web')
- is_active boolean not null default true
- last_seen_at timestamptz not null default now()
- created_at timestamptz not null default now()
- updated_at timestamptz not null default now()

recipe_generations:
- id uuid primary key default gen_random_uuid()
- user_id uuid not null references users_profiles(id) on delete cascade
- ingredients text[] not null default '{}'
- desperation_index integer checked between 0 and 100
- response_json jsonb not null
- created_at timestamptz not null default now()

4. Add helpful indexes.
- fixed_expenses(user_id, is_active)
- income_events(user_id, is_recurring)
- receipts(user_id, scanned_at desc)
- expense_items(user_id, expense_date desc)
- expense_items(user_id, category, expense_date desc)
- expense_items(receipt_id)
- device_tokens(user_id, is_active)
- recipe_generations(user_id, created_at desc)

5. Add updated_at automation.
- Create or replace a public.set_updated_at() trigger function.
- Add updated_at triggers to users_profiles, fixed_expenses, income_events, receipts, expense_items, and device_tokens.
- Make the script idempotent by dropping triggers before recreating them.

6. Add profile creation automation.
- Create or replace public.handle_new_user() as a security definer function with search_path set to public.
- It should insert a users_profiles row when a new auth.users row is created.
- display_name should use raw_user_meta_data->>'name' first, then raw_user_meta_data->>'full_name', then split_part(email, '@', 1).
- Use on conflict (id) do nothing.
- Add an after insert trigger on auth.users named on_auth_user_created. Drop it first if it already exists.

7. Create views for the app dashboard and stats.

v_monthly_summary:
- Use with (security_invoker = true).
- Group by user_id and date_trunc('month', expense_date).
- Include month, total_spent, food_spent, alcohol_spent, hygiene_spent, fun_spent, other_spent, receipt_count, item_count.

v_daily_spending:
- Use with (security_invoker = true).
- Group by user_id and expense_date.
- Include user_id, expense_date, total_spent, item_count.

v_category_monthly_summary:
- Use with (security_invoker = true).
- Group by user_id, month, category.
- Include user_id, month, category, total_spent, item_count.

8. Add a budget helper RPC.
- Create or replace public.get_budget_snapshot(p_on_date date default current_date).
- It should return one row for auth.uid() with:
  - user_id uuid
  - monthly_budget numeric
  - fixed_monthly_expenses numeric
  - disposable_budget numeric
  - spent_this_period numeric
  - remaining_budget numeric
  - days_left integer
  - daily_limit numeric
  - desperation_index integer
- Use users_profiles.budget_reset_day to calculate the current budget period.
- The period starts on budget_reset_day in the current month unless p_on_date is before that day, then it starts in the previous month.
- The period ends the day before the next reset date.
- fixed_monthly_expenses is the sum of active fixed_expenses.
- spent_this_period is the sum of expense_items.amount in the current period.
- disposable_budget = greatest(monthly_budget - fixed_monthly_expenses, 0).
- remaining_budget = disposable_budget - spent_this_period.
- daily_limit = remaining_budget / greatest(days_left, 1), rounded to 2 decimals.
- desperation_index should be an integer from 0 to 100 based on budget pressure. Use a simple deterministic formula that increases as daily_limit drops below ideal daily budget and as remaining_budget becomes negative.
- Mark it stable if possible, otherwise leave default volatility.
- Do not use service role assumptions; it must rely on auth.uid().

9. Enable Row Level Security.
- Enable RLS on users_profiles, fixed_expenses, income_events, receipts, expense_items, device_tokens, and recipe_generations.
- users_profiles policies:
  - users can select their own profile where auth.uid() = id
  - users can insert their own profile where auth.uid() = id
  - users can update their own profile where auth.uid() = id
- All other user-owned tables policies:
  - users can select rows where auth.uid() = user_id
  - users can insert rows where auth.uid() = user_id
  - users can update rows where auth.uid() = user_id
  - users can delete rows where auth.uid() = user_id
- Drop policies before recreating them so the migration is rerunnable.

10. Create a private Supabase Storage bucket.
- Bucket id/name: receipt-images
- public: false
- File paths should be expected as {user_id}/{receipt_id}/filename.
- Add storage.objects policies for authenticated users:
  - select own objects in receipt-images where first folder equals auth.uid()::text
  - insert own objects in receipt-images where first folder equals auth.uid()::text
  - update own objects in receipt-images where first folder equals auth.uid()::text
  - delete own objects in receipt-images where first folder equals auth.uid()::text
- Drop storage policies first if they exist.

11. Grants.
- Grant usage on schema public to anon and authenticated if needed.
- Grant select/insert/update/delete on the app tables to authenticated.
- Grant select on the views to authenticated.
- Grant execute on get_budget_snapshot(date) to authenticated.

Important implementation details:
- Use numeric(10,2) for money.
- Use timestamptz for timestamps.
- Do not add tables that are not listed above.
- Do not disable RLS.
- Do not create permissive policies for anon users.
- Make the SQL as idempotent as Supabase allows.
- Return SQL only.
```
