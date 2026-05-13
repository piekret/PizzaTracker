create table if not exists public.insights_monthly (
  user_id uuid not null references public.users_profiles(id) on delete cascade,
  month date not null,
  payload_json jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, month)
);

create index if not exists insights_monthly_month_idx on public.insights_monthly (month);

alter table public.insights_monthly enable row level security;

create policy "insights owner read" on public.insights_monthly
  for select
  using (auth.uid() = user_id);

create policy "insights owner insert" on public.insights_monthly
  for insert
  with check (auth.uid() = user_id);

create policy "insights owner update" on public.insights_monthly
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
