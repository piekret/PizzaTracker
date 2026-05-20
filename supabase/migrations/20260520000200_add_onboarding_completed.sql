alter table public.users_profiles
  add column if not exists onboarding_completed boolean not null default false;

update public.users_profiles
set onboarding_completed = true
where monthly_budget > 0
  and onboarding_completed = false;
