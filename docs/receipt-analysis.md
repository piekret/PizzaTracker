# Receipt Analysis

Receipt OCR starts locally with ML Kit. Categorization and line-item cleanup run in the Supabase Edge Function at `supabase/functions/analyze-receipt`.

## Flow

1. Flutter picks a receipt image from camera or gallery.
2. Flutter runs local ML Kit text recognition and keeps the extracted OCR text on-device.
3. Flutter uploads the receipt image to the private `receipt-images` bucket for in-app preview.
4. Flutter creates a `receipts` row and calls `analyze-receipt` with the receipt id plus OCR text.
5. The Edge Function verifies the caller and sends the OCR text to OpenAI for categorization and line-item extraction.
6. If local OCR is unavailable, the function falls back to a short-lived signed image URL and OpenAI vision.
7. The function returns suggested expense fields/items and stores basic receipt metadata.
8. Flutter opens a receipt review sheet for line items, or the manual expense form if line items are unavailable.

If the function is not deployed or OpenAI fails, the app falls back to the manual receipt-attached expense form.

Receipt images are currently kept in private Supabase Storage so users can reopen the receipt from expense history. Deleting the final expense linked to a receipt attempts to remove the orphaned receipt row and stored image.

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
