# Desperation Index

The Desperation Index is calculated in Supabase by `public.get_budget_snapshot(date)` and returned to Flutter as `desperation_index`.

## Inputs

- `disposable_budget = max(monthly_budget - fixed_monthly_expenses, 0)`
- `spent_this_period = sum(expense_items.amount)` in the current budget period
- `remaining_budget = disposable_budget - spent_this_period`
- `days_left = days through the reset date, including today`
- `daily_limit = remaining_budget / max(days_left, 1)`
- `ideal_daily = disposable_budget / total_days_in_budget_period`
- `expected_remaining = ideal_daily * max(days_left, 1)`

## Formula

```text
daily_pressure = clamp((ideal_daily - daily_limit) / ideal_daily, 0, 1)
schedule_pressure = clamp((expected_remaining - remaining_budget) / disposable_budget, 0, 1)
over_budget_pressure = max(-remaining_budget / disposable_budget, 0)

desperation_index = clamp(
  round(
    daily_pressure * 30 +
    schedule_pressure * 60 +
    over_budget_pressure * 70
  ),
  0,
  100
)
```

If `disposable_budget` is `0`, the index is `0` unless spending has already made `remaining_budget` negative, then it is `100`.

## Behavior

Having exactly `0` left is no longer always the same score. It now depends on how many days remain.

Examples for a 30-day budget period with exactly `0` remaining:

- 1 day left: about `32/100`
- 10 days left: about `50/100`
- 15 days left: about `60/100`
- 20 days left: about `70/100`
- 30 days left: about `90/100`

Going negative adds an extra over-budget penalty, so the same remaining-days situation becomes more severe once `remaining_budget < 0`.
