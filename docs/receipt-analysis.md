# Receipt Analysis

Receipt OCR/categorization runs in the Supabase Edge Function at `supabase/functions/analyze-receipt`.

## Flow

1. Flutter uploads a receipt image to the private `receipt-images` bucket.
2. Flutter creates a `receipts` row and calls `analyze-receipt` with the receipt id.
3. The Edge Function verifies the caller, creates a short-lived signed image URL, and sends it to OpenAI vision.
4. The function returns suggested expense fields and stores basic receipt metadata.
5. Flutter opens the expense form with those suggestions prefilled.

If the function is not deployed or OpenAI fails, the app falls back to the manual receipt-attached expense form.

## Required Secrets

Set these for the Supabase function:

```bash
supabase secrets set OPENAI_API_KEY=...
supabase secrets set OPENAI_RECEIPT_MODEL=gpt-4.1-mini
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided by Supabase in Edge Functions.

## Deploy

```bash
supabase functions deploy analyze-receipt
```

The local environment currently may not have the Supabase CLI installed, so deployment can be done from a machine or CI job that has it.
