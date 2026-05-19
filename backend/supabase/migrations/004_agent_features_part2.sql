-- =====================================================================
-- 004_agent_features_part2.sql
--   Run AFTER 003_agent_features.sql has been committed.
--   * held_until column on bookings + supporting index
--   * Waitlist for areas with no available providers
--   * User profile for personalisation
--   * Price ranges per category
--   * Idempotency keys on agent_traces
--   * Unique-slot index extended to include 'held'
-- =====================================================================

-- ---------- bookings: held_until + supporting index -----------------
alter table bookings
  add column if not exists held_until timestamptz;

create index if not exists bookings_held_idx
  on bookings (provider_id, scheduled_at)
  where status = 'held';

-- ---------- waitlist ------------------------------------------------
create table if not exists waitlist (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  category      provider_category not null,
  area          text not null,
  note          text,
  created_at    timestamptz not null default now()
);

create index if not exists waitlist_user_idx on waitlist(user_id, created_at desc);
create index if not exists waitlist_lookup_idx on waitlist(category, area);

alter table waitlist enable row level security;
drop policy if exists "own waitlist" on waitlist;
create policy "own waitlist"
  on waitlist for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- user_profile ---------------------------------------------
create table if not exists user_profile (
  user_id           uuid primary key references auth.users(id) on delete cascade,
  preferred_area    text,
  preferred_time    text,
  last_category     text,
  bookings_count    int not null default 0,
  updated_at        timestamptz not null default now()
);

alter table user_profile enable row level security;
drop policy if exists "own profile data" on user_profile;
create policy "own profile data"
  on user_profile for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- price_ranges --------------------------------------------
create table if not exists price_ranges (
  category      provider_category primary key,
  min_pkr       int not null,
  max_pkr       int not null,
  updated_at    timestamptz not null default now()
);

insert into price_ranges (category, min_pkr, max_pkr) values
  ('ac_technician', 1500, 4500),
  ('plumber',       800,  3000),
  ('electrician',   700,  2500),
  ('tutor',         1500, 6000),
  ('beautician',    1200, 5000)
on conflict (category) do nothing;

alter table price_ranges enable row level security;
drop policy if exists "prices public read" on price_ranges;
create policy "prices public read" on price_ranges for select using (true);

-- ---------- idempotency on agent_traces -----------------------------
alter table agent_traces
  add column if not exists idempotency_key text;

create unique index if not exists agent_traces_idemp_idx
  on agent_traces(user_id, idempotency_key)
  where idempotency_key is not null;

-- ---------- conflict-blocking unique index ---------------------------
drop index if exists bookings_provider_unique_slot;
create unique index if not exists bookings_provider_unique_slot
  on bookings (provider_id, scheduled_at)
  where status in ('confirmed', 'pending', 'held');
