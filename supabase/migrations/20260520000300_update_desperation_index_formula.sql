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

grant execute on function public.get_budget_snapshot(date) to authenticated;
