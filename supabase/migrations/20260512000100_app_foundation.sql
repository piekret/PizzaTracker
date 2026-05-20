create extension if not exists pgcrypto;

do $$
begin
  create type public.expense_category as enum (
    'food',
    'alcohol',
    'hygiene',
    'fun',
    'other'
  );
exception
  when duplicate_object then null;
end;
$$;

create table if not exists public.users_profiles(
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  monthly_budget numeric(10,2) not null default 0,
  budget_reset_day integer not null default 1,
  currency text not null default 'USD',
  timezone text not null default 'Europe/Warsaw',
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint users_profiles_monthly_budget_check check (monthly_budget >= 0),
  constraint users_profiles_budget_reset_day_check check (budget_reset_day between 1 and 28),
  constraint users_profiles_currency_check check (char_length(currency) between 3 and 8)
);

create table if not exists public.fixed_expenses(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users_profiles(id) on delete cascade,
  name text not null,
  amount numeric(10,2) not null,
  billing_day integer not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fixed_expenses_amount_check check (amount >= 0),
  constraint fixed_expenses_billing_day_check check (billing_day between 1 and 28),
  constraint fixed_expenses_name_check check (length(trim(name)) > 0)
);

create table if not exists public.income_events(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users_profiles(id) on delete cascade,
  name text not null,
  amount numeric(10,2) not null,
  expected_day integer not null,
  is_recurring boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint income_events_amount_check check (amount >= 0),
  constraint income_events_expected_day_check check (expected_day between 1 and 28),
  constraint income_events_name_check check (length(trim(name)) > 0)
);

create table if not exists public.receipts(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users_profiles(id) on delete cascade,
  store_name text,
  total_amount numeric(10,2) not null default 0,
  raw_ocr_text text,
  analysis_json jsonb,
  scanned_at timestamptz not null default now(),
  image_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint receipts_total_amount_check check (total_amount >= 0)
);

create table if not exists public.expense_items(
  id uuid primary key default gen_random_uuid(),
  receipt_id uuid references public.receipts(id) on delete set null,
  user_id uuid not null references public.users_profiles(id) on delete cascade,
  name text not null,
  amount numeric(10,2) not null,
  category public.expense_category not null default 'other',
  ai_categorized boolean not null default false,
  expense_date date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expense_items_amount_check check (amount >= 0),
  constraint expense_items_name_check check (length(trim(name)) > 0)
);

create table if not exists public.device_tokens(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users_profiles(id) on delete cascade,
  token text not null unique,
  platform text not null,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint device_tokens_platform_check check (platform in ('android', 'ios', 'web')),
  constraint device_tokens_token_check check (length(trim(token)) > 0)
);

create table if not exists public.recipe_generations(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users_profiles(id) on delete cascade,
  ingredients text[] not null default '{}',
  desperation_index integer,
  response_json jsonb not null,
  created_at timestamptz not null default now(),
  constraint recipe_generations_desperation_index_check check (
    desperation_index is null or desperation_index between 0 and 100
  )
);

alter table public.receipts
  add column if not exists raw_ocr_text text,
  add column if not exists analysis_json jsonb;

alter table public.users_profiles
  add column if not exists onboarding_completed boolean not null default false;

alter table public.expense_items
  add column if not exists receipt_id uuid references public.receipts(id) on delete set null;

create index if not exists fixed_expenses_user_id_is_active_idx
  on public.fixed_expenses(user_id, is_active);

create index if not exists income_events_user_id_is_recurring_idx
  on public.income_events(user_id, is_recurring);

create index if not exists receipts_user_id_scanned_at_idx
  on public.receipts(user_id, scanned_at desc);

create index if not exists expense_items_user_id_expense_date_idx
  on public.expense_items(user_id, expense_date desc);

create index if not exists expense_items_user_id_category_expense_date_idx
  on public.expense_items(user_id, category, expense_date desc);

create index if not exists expense_items_receipt_id_idx
  on public.expense_items(receipt_id);

create index if not exists device_tokens_user_id_is_active_idx
  on public.device_tokens(user_id, is_active);

create index if not exists recipe_generations_user_id_created_at_idx
  on public.recipe_generations(user_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

drop trigger if exists set_users_profiles_updated_at on public.users_profiles;
create trigger set_users_profiles_updated_at
  before update on public.users_profiles
  for each row execute function public.set_updated_at();

drop trigger if exists set_fixed_expenses_updated_at on public.fixed_expenses;
create trigger set_fixed_expenses_updated_at
  before update on public.fixed_expenses
  for each row execute function public.set_updated_at();

drop trigger if exists set_income_events_updated_at on public.income_events;
create trigger set_income_events_updated_at
  before update on public.income_events
  for each row execute function public.set_updated_at();

drop trigger if exists set_receipts_updated_at on public.receipts;
create trigger set_receipts_updated_at
  before update on public.receipts
  for each row execute function public.set_updated_at();

drop trigger if exists set_expense_items_updated_at on public.expense_items;
create trigger set_expense_items_updated_at
  before update on public.expense_items
  for each row execute function public.set_updated_at();

drop trigger if exists set_device_tokens_updated_at on public.device_tokens;
create trigger set_device_tokens_updated_at
  before update on public.device_tokens
  for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to public
as $function$
begin
  insert into public.users_profiles(id, display_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'name',
      new.raw_user_meta_data->>'full_name',
      split_part(new.email, '@', 1)
    )
  )
  on conflict (id) do nothing;

  return new;
end;
$function$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

drop view if exists public.v_category_monthly_summary;
drop view if exists public.v_daily_spending;
drop view if exists public.v_monthly_summary;

create or replace view public.v_monthly_summary
with (security_invoker = true)
as
select
  ei.user_id,
  date_trunc('month', ei.expense_date)::date as month,
  coalesce(sum(ei.amount), 0)::numeric(10,2) as total_spent,
  coalesce(sum(ei.amount) filter (where ei.category = 'food'), 0)::numeric(10,2) as food_spent,
  coalesce(sum(ei.amount) filter (where ei.category = 'alcohol'), 0)::numeric(10,2) as alcohol_spent,
  coalesce(sum(ei.amount) filter (where ei.category = 'hygiene'), 0)::numeric(10,2) as hygiene_spent,
  coalesce(sum(ei.amount) filter (where ei.category = 'fun'), 0)::numeric(10,2) as fun_spent,
  coalesce(sum(ei.amount) filter (where ei.category = 'other'), 0)::numeric(10,2) as other_spent,
  count(distinct ei.receipt_id)::integer as receipt_count,
  count(*)::integer as item_count
from public.expense_items ei
group by ei.user_id, date_trunc('month', ei.expense_date)::date;

create or replace view public.v_daily_spending
with (security_invoker = true)
as
select
  ei.user_id,
  ei.expense_date,
  coalesce(sum(ei.amount), 0)::numeric(10,2) as total_spent,
  count(*)::integer as item_count
from public.expense_items ei
group by ei.user_id, ei.expense_date;

create or replace view public.v_category_monthly_summary
with (security_invoker = true)
as
select
  ei.user_id,
  date_trunc('month', ei.expense_date)::date as month,
  ei.category,
  coalesce(sum(ei.amount), 0)::numeric(10,2) as total_spent,
  count(*)::integer as item_count
from public.expense_items ei
group by ei.user_id, date_trunc('month', ei.expense_date)::date, ei.category;

create or replace function public.get_budget_snapshot(
  p_on_date date default current_date
)
returns table(
  user_id uuid,
  monthly_budget numeric,
  fixed_monthly_expenses numeric,
  disposable_budget numeric,
  spent_this_period numeric,
  remaining_budget numeric,
  days_left integer,
  daily_limit numeric,
  desperation_index integer
)
language plpgsql
stable
security definer
set search_path to public
as $function$
declare
  v_auth_uid uuid := auth.uid();
  v_reset_day integer;
  v_period_start date;
  v_next_reset date;
  v_period_end date;
  v_days_left integer;
  v_daily_limit numeric(10,2);
  v_disposable_budget numeric(10,2);
  v_fixed_monthly_expenses numeric(10,2);
  v_spent_this_period numeric(10,2);
  v_remaining_budget numeric(10,2);
  v_monthly_budget numeric(10,2);
  v_total_days integer;
  v_ideal_daily numeric(10,2);
  v_expected_remaining numeric;
  v_daily_pressure numeric;
  v_spent_pressure numeric;
  v_schedule_pressure numeric;
  v_over_budget_pressure numeric;
  v_desperation integer;
  v_period_month date;
begin
  if v_auth_uid is null then
    raise exception 'Not authenticated';
  end if;

  select up.budget_reset_day, up.monthly_budget
    into v_reset_day, v_monthly_budget
  from public.users_profiles up
  where up.id = v_auth_uid;

  if v_reset_day is null then
    raise exception 'Profile not found for current user';
  end if;

  v_period_month := date_trunc('month', p_on_date)::date;

  if extract(day from p_on_date) < v_reset_day then
    v_period_month := (v_period_month - interval '1 month')::date;
  end if;

  v_period_start := v_period_month + (v_reset_day - 1);
  v_next_reset := (v_period_month + interval '1 month')::date + (v_reset_day - 1);
  v_period_end := v_next_reset - 1;

  select coalesce(sum(fe.amount), 0)::numeric(10,2)
    into v_fixed_monthly_expenses
  from public.fixed_expenses fe
  where fe.user_id = v_auth_uid
    and fe.is_active = true;

  v_disposable_budget := greatest(
    v_monthly_budget - v_fixed_monthly_expenses,
    0
  )::numeric(10,2);

  select coalesce(sum(ei.amount), 0)::numeric(10,2)
    into v_spent_this_period
  from public.expense_items ei
  where ei.user_id = v_auth_uid
    and ei.expense_date between v_period_start and v_period_end;

  v_remaining_budget := (v_disposable_budget - v_spent_this_period)::numeric(10,2);

  v_days_left := (v_period_end - p_on_date)::integer + 1;
  if v_days_left < 0 then v_days_left := 0; end if;

  v_total_days := greatest((v_period_end - v_period_start + 1), 1);
  v_daily_limit := round((v_remaining_budget / greatest(v_days_left, 1))::numeric, 2);
  if v_daily_limit is null then v_daily_limit := 0; end if;

  v_ideal_daily := round((v_disposable_budget / v_total_days)::numeric, 2);
  v_expected_remaining := v_ideal_daily * greatest(v_days_left, 1);

  v_daily_pressure := 0;
  v_spent_pressure := 0;
  v_schedule_pressure := 0;
  v_over_budget_pressure := 0;

  if v_disposable_budget > 0 and v_ideal_daily > 0 then
    v_spent_pressure := greatest(
      least((v_spent_this_period / v_disposable_budget), 1),
      0
    );

    v_daily_pressure := greatest(
      least(((v_ideal_daily - v_daily_limit) / v_ideal_daily), 1),
      0
    );

    v_schedule_pressure := greatest(
      least(((v_expected_remaining - v_remaining_budget) / v_disposable_budget), 1),
      0
    );

    if v_remaining_budget < 0 then
      v_over_budget_pressure := greatest((-v_remaining_budget) / v_disposable_budget, 0);
    end if;

    v_desperation := greatest(
      0,
      least(
        100,
        round(
          (v_spent_pressure * 45) +
          (v_schedule_pressure * 35) +
          (v_daily_pressure * 20) +
          (v_over_budget_pressure * 70)
        )::int
      )
    );
  else
    if v_remaining_budget < 0 then
      v_desperation := 100;
    else
      v_desperation := 0;
    end if;
  end if;

  user_id := v_auth_uid;
  monthly_budget := v_monthly_budget;
  fixed_monthly_expenses := v_fixed_monthly_expenses;
  disposable_budget := v_disposable_budget;
  spent_this_period := v_spent_this_period;
  remaining_budget := v_remaining_budget;
  days_left := v_days_left;
  daily_limit := v_daily_limit;
  desperation_index := v_desperation;

  return next;
end;
$function$;

alter table public.users_profiles enable row level security;
alter table public.fixed_expenses enable row level security;
alter table public.income_events enable row level security;
alter table public.receipts enable row level security;
alter table public.expense_items enable row level security;
alter table public.device_tokens enable row level security;
alter table public.recipe_generations enable row level security;

drop policy if exists "Users can select own profile" on public.users_profiles;
create policy "Users can select own profile"
  on public.users_profiles for select
  to authenticated
  using (auth.uid() = id);

drop policy if exists "Users can insert own profile" on public.users_profiles;
create policy "Users can insert own profile"
  on public.users_profiles for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.users_profiles;
create policy "Users can update own profile"
  on public.users_profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "Users can select own fixed expenses" on public.fixed_expenses;
create policy "Users can select own fixed expenses"
  on public.fixed_expenses for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own fixed expenses" on public.fixed_expenses;
create policy "Users can insert own fixed expenses"
  on public.fixed_expenses for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own fixed expenses" on public.fixed_expenses;
create policy "Users can update own fixed expenses"
  on public.fixed_expenses for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own fixed expenses" on public.fixed_expenses;
create policy "Users can delete own fixed expenses"
  on public.fixed_expenses for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can select own income events" on public.income_events;
create policy "Users can select own income events"
  on public.income_events for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own income events" on public.income_events;
create policy "Users can insert own income events"
  on public.income_events for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own income events" on public.income_events;
create policy "Users can update own income events"
  on public.income_events for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own income events" on public.income_events;
create policy "Users can delete own income events"
  on public.income_events for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can select own receipts" on public.receipts;
create policy "Users can select own receipts"
  on public.receipts for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own receipts" on public.receipts;
create policy "Users can insert own receipts"
  on public.receipts for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own receipts" on public.receipts;
create policy "Users can update own receipts"
  on public.receipts for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own receipts" on public.receipts;
create policy "Users can delete own receipts"
  on public.receipts for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can select own expense items" on public.expense_items;
create policy "Users can select own expense items"
  on public.expense_items for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own expense items" on public.expense_items;
create policy "Users can insert own expense items"
  on public.expense_items for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own expense items" on public.expense_items;
create policy "Users can update own expense items"
  on public.expense_items for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own expense items" on public.expense_items;
create policy "Users can delete own expense items"
  on public.expense_items for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can select own device tokens" on public.device_tokens;
create policy "Users can select own device tokens"
  on public.device_tokens for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own device tokens" on public.device_tokens;
create policy "Users can insert own device tokens"
  on public.device_tokens for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own device tokens" on public.device_tokens;
create policy "Users can update own device tokens"
  on public.device_tokens for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own device tokens" on public.device_tokens;
create policy "Users can delete own device tokens"
  on public.device_tokens for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can select own recipe generations" on public.recipe_generations;
create policy "Users can select own recipe generations"
  on public.recipe_generations for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own recipe generations" on public.recipe_generations;
create policy "Users can insert own recipe generations"
  on public.recipe_generations for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own recipe generations" on public.recipe_generations;
create policy "Users can update own recipe generations"
  on public.recipe_generations for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own recipe generations" on public.recipe_generations;
create policy "Users can delete own recipe generations"
  on public.recipe_generations for delete
  to authenticated
  using (auth.uid() = user_id);

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values (
  'receipt-images',
  'receipt-images',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users can select own receipt images" on storage.objects;
create policy "Users can select own receipt images"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'receipt-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users can insert own receipt images" on storage.objects;
create policy "Users can insert own receipt images"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'receipt-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users can update own receipt images" on storage.objects;
create policy "Users can update own receipt images"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'receipt-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'receipt-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users can delete own receipt images" on storage.objects;
create policy "Users can delete own receipt images"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'receipt-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

grant usage on schema public to anon, authenticated;
grant usage on type public.expense_category to authenticated;
grant select, insert, update, delete on
  public.users_profiles,
  public.fixed_expenses,
  public.income_events,
  public.receipts,
  public.expense_items,
  public.device_tokens,
  public.recipe_generations
to authenticated;
grant select on
  public.v_monthly_summary,
  public.v_daily_spending,
  public.v_category_monthly_summary
to authenticated;
grant execute on function public.get_budget_snapshot(date) to authenticated;
