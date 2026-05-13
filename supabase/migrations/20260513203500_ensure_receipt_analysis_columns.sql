alter table public.receipts
  add column if not exists raw_ocr_text text,
  add column if not exists analysis_json jsonb;
