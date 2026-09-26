-- Access-plan lookup used a variable and a column with the same name.
-- Unpaid accounts, including Business, failed my_billing with 42702.
create or replace function public.my_billing()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  uid uuid := auth.uid();
  account public.account_type;
  sub jsonb;
  paid boolean;
  entitlements jsonb;
  refund_deadline timestamptz;
begin
  if uid is null then raise exception 'Not signed in'; end if;
  perform private.sync_billing(uid);
  select profiles.account_type into account from public.profiles where id = uid;
  select to_jsonb(s) || jsonb_build_object('tier', p.tier, 'entitlements', p.entitlements) into sub
  from public.subscriptions s join public.plans p on p.id = s.plan_id
  where s.profile_id = uid and s.status in ('trialing','active','past_due','grace_period','cancel_at_period_end')
  order by s.created_at desc limit 1;
  paid := sub is not null and (sub ->> 'status') in ('trialing','active','past_due','grace_period','cancel_at_period_end');
  if paid then entitlements := sub -> 'entitlements';
  else
    select plans.entitlements into entitlements
    from public.plans
    where plans.account_type = account and plans.tier = 'access';
  end if;
  select subscriptions.activated_at + interval '168 hours' into refund_deadline
  from public.subscriptions
  where subscriptions.profile_id = uid and subscriptions.activated_at is not null
  order by subscriptions.activated_at asc limit 1;
  return jsonb_build_object(
    'account_type', account,
    'subscription', sub,
    'entitlements', coalesce(entitlements, '{}'::jsonb),
    'refund_deadline', refund_deadline,
    'protected_payments_enabled', (select settings.enabled from public.protected_payment_settings settings limit 1),
    'founding_eligible', exists (
      select 1 from public.founding_programs program
      where program.account_type = account and now() < program.ends_at and program.claimed_slots < program.total_slots
        and not exists (select 1 from public.subscriptions s where s.profile_id = uid and s.is_founding)
    )
  );
end;
$function$;
