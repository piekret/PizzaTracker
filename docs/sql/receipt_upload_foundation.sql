create table if not exists public.receipts(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users_profiles(id) on delete cascade,
  store_name text,
  total_amount numeric(10,2) not null default 0,
  raw_ocr_text text,
  scanned_at timestamptz not null default now(),
  image_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint receipts_total_amount_check check (total_amount >= 0)
);

alter table public.receipts
  alter column total_amount set default 0;

alter table public.expense_items
  add column if not exists receipt_id uuid references public.receipts(id) on delete set null;

create index if not exists receipts_user_id_scanned_at_idx
  on public.receipts(user_id, scanned_at desc);

create index if not exists expense_items_receipt_id_idx
  on public.expense_items(receipt_id);

alter table public.receipts enable row level security;

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

grant select, insert, update, delete on public.receipts to authenticated;
