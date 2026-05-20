alter table public.insights_monthly
  add column if not exists language text not null default 'en';

update public.insights_monthly
set language = 'en'
where language is null or language = '';

alter table public.insights_monthly
  drop constraint if exists insights_monthly_pkey;

alter table public.insights_monthly
  add constraint insights_monthly_pkey primary key (user_id, month, language);

alter table public.insights_monthly
  drop constraint if exists insights_monthly_language_check;

alter table public.insights_monthly
  add constraint insights_monthly_language_check check (language in ('en', 'pl'));

create index if not exists insights_monthly_user_month_language_idx
  on public.insights_monthly (user_id, month, language);
