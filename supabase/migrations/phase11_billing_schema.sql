-- Phase 11 billing schema. Clients cannot write financial rows.

create type public.plan_tier as enum ('access', 'pro', 'premium', 'enterprise');
create type public.billing_interval as enum ('month', 'year');
create type public.subscription_status as enum (
  'trialing', 'active', 'past_due', 'grace_period', 'cancel_at_period_end', 'cancelled', 'expired', 'suspended'
);
create type public.payment_status as enum (
  'pending', 'processing', 'successful', 'failed', 'cancelled', 'refunded', 'partially_refunded', 'disputed', 'reversed'
);
create type public.payment_purpose as enum (
  'subscription', 'verification', 'boost', 'promotion', 'xid', 'protected_payment_fee'
);
create type public.boost_target as enum (
  'worker_profile', 'project_manager_profile', 'job', 'project', 'business_listing'
);
create type public.xid_service as enum ('professional', 'digital_card', 'business', 'company');
create type public.promotion_package as enum ('starter', 'growth', 'business', 'campaign_30');

create table public.currencies (
  code text primary key,
  symbol text not null,
  decimal_places integer not null default 2 check (decimal_places between 0 and 4),
  checkout_enabled boolean not null default false
);

create table public.plans (
  id uuid primary key default gen_random_uuid(),
  account_type public.account_type not null,
  tier public.plan_tier not null,
  currency_code text not null references public.currencies (code),
  monthly_amount integer,
  annual_amount integer,
  founding_monthly_amount integer,
  founding_annual_amount integer,
  is_active boolean not null default true,
  entitlements jsonb not null default '{}'::jsonb,
  unique (account_type, tier),
  check (monthly_amount is null or monthly_amount >= 0),
  check (annual_amount is null or annual_amount >= 0)
);

create table public.founding_programs (
  account_type public.account_type primary key,
  total_slots integer not null check (total_slots >= 0),
  claimed_slots integer not null default 0 check (claimed_slots >= 0 and claimed_slots <= total_slots),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  check (ends_at > starts_at)
);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  company_id uuid references public.companies (id) on delete cascade,
  plan_id uuid not null references public.plans (id),
  status public.subscription_status not null,
  billing_interval public.billing_interval not null,
  provider text not null default 'paystack',
  provider_subscription_ref text,
  amount_minor integer not null check (amount_minor >= 0),
  currency_code text not null references public.currencies (code),
  current_period_start timestamptz,
  current_period_end timestamptz,
  activated_at timestamptz,
  trial_end timestamptz,
  grace_ends_at timestamptz,
  cancel_at_period_end boolean not null default false,
  is_founding boolean not null default false,
  founding_price_lock_end timestamptz,
  scheduled_plan_id uuid references public.plans (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index subscriptions_one_open on public.subscriptions (profile_id)
  where status in ('trialing', 'active', 'past_due', 'grace_period', 'cancel_at_period_end');

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  company_id uuid references public.companies (id) on delete cascade,
  amount_minor integer not null check (amount_minor >= 0),
  currency_code text not null references public.currencies (code),
  provider text not null default 'paystack',
  provider_transaction_id text,
  provider_reference text not null unique,
  status public.payment_status not null default 'pending',
  purpose public.payment_purpose not null,
  subscription_id uuid references public.subscriptions (id),
  invoice_reference text,
  confirmed_at timestamptz,
  refunded_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create unique index payments_provider_transaction_unique on public.payments (provider, provider_transaction_id)
  where provider_transaction_id is not null;

create table public.payment_events (
  provider text not null,
  provider_event_id text not null,
  payment_id uuid references public.payments (id),
  created_at timestamptz not null default now(),
  primary key (provider, provider_event_id)
);

create table public.verification_products (
  id uuid primary key default gen_random_uuid(),
  account_type public.account_type not null,
  product_code text not null,
  verification_kind public.verification_kind not null,
  amount_minor integer not null check (amount_minor > 0),
  currency_code text not null references public.currencies (code),
  label text not null,
  unique (account_type, product_code)
);

create table public.boost_catalog (
  target_type public.boost_target not null,
  duration_key text not null,
  duration_hours integer not null check (duration_hours > 0),
  amount_minor integer not null check (amount_minor > 0),
  currency_code text not null references public.currencies (code),
  primary key (target_type, duration_key)
);

create table public.boosts (
  id uuid primary key default gen_random_uuid(),
  target_type public.boost_target not null,
  target_id uuid not null,
  purchaser_profile_id uuid not null references public.profiles (id) on delete cascade,
  duration_key text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  payment_id uuid not null unique references public.payments (id),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create table public.promotion_catalog (
  package public.promotion_package primary key,
  listing_limit integer not null check (listing_limit > 0),
  duration_hours integer not null check (duration_hours > 0),
  amount_minor integer not null check (amount_minor > 0),
  currency_code text not null references public.currencies (code),
  label text not null
);

create table public.promotions (
  id uuid primary key default gen_random_uuid(),
  business_profile_id uuid not null references public.profiles (id) on delete cascade,
  package public.promotion_package not null,
  listing_limit integer not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  payment_id uuid not null unique references public.payments (id),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create table public.promotion_listings (
  promotion_id uuid not null references public.promotions (id) on delete cascade,
  listing_id uuid not null references public.business_listings (id) on delete cascade,
  primary key (promotion_id, listing_id)
);

create table public.xid_catalog (
  service public.xid_service primary key,
  amount_minor integer not null check (amount_minor > 0),
  currency_code text not null references public.currencies (code),
  label text not null
);

create table public.xid_services (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  service public.xid_service not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  payment_id uuid not null unique references public.payments (id),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create table public.billing_audit (
  id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid references public.profiles (id),
  event_type text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.protected_payment_settings (
  id boolean primary key default true check (id),
  enabled boolean not null default false,
  fee_bps_min integer not null default 50 check (fee_bps_min >= 0),
  fee_bps_max integer not null default 100 check (fee_bps_max >= fee_bps_min)
);

alter table public.currencies enable row level security;
alter table public.plans enable row level security;
alter table public.founding_programs enable row level security;
alter table public.subscriptions enable row level security;
alter table public.payments enable row level security;
alter table public.payment_events enable row level security;
alter table public.verification_products enable row level security;
alter table public.boost_catalog enable row level security;
alter table public.boosts enable row level security;
alter table public.promotion_catalog enable row level security;
alter table public.promotions enable row level security;
alter table public.promotion_listings enable row level security;
alter table public.xid_catalog enable row level security;
alter table public.xid_services enable row level security;
alter table public.billing_audit enable row level security;
alter table public.protected_payment_settings enable row level security;

create policy currencies_read on public.currencies for select to anon, authenticated using (true);
create policy plans_read on public.plans for select to anon, authenticated using (is_active);
create policy verification_products_read on public.verification_products for select to anon, authenticated using (true);
create policy boost_catalog_read on public.boost_catalog for select to anon, authenticated using (true);
create policy promotion_catalog_read on public.promotion_catalog for select to anon, authenticated using (true);
create policy xid_catalog_read on public.xid_catalog for select to anon, authenticated using (true);
create policy protected_settings_read on public.protected_payment_settings for select to anon, authenticated using (true);

create policy subscriptions_read on public.subscriptions for select to authenticated using (
  profile_id = (select auth.uid())
  or (
    company_id is not null and exists (
      select 1 from public.company_members member
      where member.company_id = subscriptions.company_id
        and member.profile_id = (select auth.uid())
        and member.member_role = 'owner'
        and member.status = 'active'
    )
  )
);

create policy payments_read on public.payments for select to authenticated using (
  profile_id = (select auth.uid())
  or (
    company_id is not null and exists (
      select 1 from public.company_members member
      where member.company_id = payments.company_id
        and member.profile_id = (select auth.uid())
        and member.member_role = 'owner'
        and member.status = 'active'
    )
  )
);

create policy boosts_read on public.boosts for select to anon, authenticated using (
  purchaser_profile_id = (select auth.uid()) or ends_at > now()
);
create policy promotions_read on public.promotions for select to authenticated using (
  business_profile_id = (select auth.uid())
);
create policy promotion_listings_read on public.promotion_listings for select to anon, authenticated using (
  exists (
    select 1 from public.promotions promotion
    where promotion.id = promotion_listings.promotion_id and promotion.ends_at > now()
  )
);
create policy xid_read on public.xid_services for select to authenticated using (profile_id = (select auth.uid()));
create policy audit_read on public.billing_audit for select to authenticated using (actor_profile_id = (select auth.uid()));

grant select on public.currencies, public.plans, public.verification_products, public.boost_catalog,
  public.promotion_catalog, public.xid_catalog, public.protected_payment_settings to anon, authenticated;
grant select on public.subscriptions, public.payments, public.promotions, public.xid_services, public.billing_audit to authenticated;
grant select on public.boosts, public.promotion_listings to anon, authenticated;
revoke all on public.founding_programs from anon, authenticated;
revoke all on public.payment_events from anon, authenticated;
