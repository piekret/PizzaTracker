alter table public.receipts
  add column if not exists currency text not null default 'USD',
  add column if not exists original_total_amount numeric(10,2),
  add column if not exists exchange_rate_to_profile numeric(12,6);

alter table public.expense_items
  add column if not exists currency text not null default 'USD',
  add column if not exists original_amount numeric(10,2),
  add column if not exists original_currency text,
  add column if not exists exchange_rate_to_profile numeric(12,6);

update public.receipts
set original_total_amount = total_amount
where original_total_amount is null;

update public.expense_items
set
  original_amount = amount,
  original_currency = currency,
  exchange_rate_to_profile = 1
where original_amount is null;

alter table public.receipts
  drop constraint if exists receipts_currency_check,
  add constraint receipts_currency_check check (char_length(currency) between 3 and 8),
  drop constraint if exists receipts_original_total_amount_check,
  add constraint receipts_original_total_amount_check check (
    original_total_amount is null or original_total_amount >= 0
  ),
  drop constraint if exists receipts_exchange_rate_to_profile_check,
  add constraint receipts_exchange_rate_to_profile_check check (
    exchange_rate_to_profile is null or exchange_rate_to_profile > 0
  );

alter table public.expense_items
  drop constraint if exists expense_items_currency_check,
  add constraint expense_items_currency_check check (char_length(currency) between 3 and 8),
  drop constraint if exists expense_items_original_amount_check,
  add constraint expense_items_original_amount_check check (
    original_amount is null or original_amount >= 0
  ),
  drop constraint if exists expense_items_original_currency_check,
  add constraint expense_items_original_currency_check check (
    original_currency is null or char_length(original_currency) between 3 and 8
  ),
  drop constraint if exists expense_items_exchange_rate_to_profile_check,
  add constraint expense_items_exchange_rate_to_profile_check check (
    exchange_rate_to_profile is null or exchange_rate_to_profile > 0
  );
