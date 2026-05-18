-- =====================================================================
-- 001_init.sql — schema for the agentic service-matching backend
-- Apply via Supabase SQL editor (or `supabase db push`)
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------- enums ----------------------------------------------------
do $$ begin
  create type provider_category as enum
    ('ac_technician', 'plumber', 'electrician', 'tutor', 'beautician');
exception when duplicate_object then null; end $$;

do $$ begin
  create type booking_status as enum
    ('pending', 'confirmed', 'cancelled', 'completed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type notification_kind as enum
    ('reminder', 'status_update', 'completion');
exception when duplicate_object then null; end $$;

do $$ begin
  create type conversation_status as enum
    ('active', 'awaiting_user', 'completed', 'abandoned');
exception when duplicate_object then null; end $$;

-- ---------- profiles -------------------------------------------------
create table if not exists profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  email         text unique not null,
  display_name  text,
  created_at    timestamptz not null default now()
);

-- Backfill: if the table was created with the old `phone` column, rename it.
do $$ begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='profiles' and column_name='phone')
     and not exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='profiles' and column_name='email')
  then
    alter table profiles rename column phone to email;
  end if;
end $$;

-- ---------- providers ------------------------------------------------
create table if not exists providers (
  id                  uuid primary key default gen_random_uuid(),
  place_id            text unique not null,
  name                text not null,
  category            provider_category not null,
  address             text,
  lat                 double precision not null,
  lng                 double precision not null,
  rating              numeric(2,1),
  user_ratings_total  int,
  phone               text,
  area                text,
  available_hours     jsonb not null default '{}'::jsonb,
  created_at          timestamptz not null default now()
);

create index if not exists providers_category_area_idx on providers(category, area);
create index if not exists providers_category_idx       on providers(category);

-- ---------- conversations -------------------------------------------
create table if not exists conversations (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  status         conversation_status not null default 'active',
  last_question  text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index if not exists conversations_user_status_idx on conversations(user_id, status);

-- ---------- agent_traces --------------------------------------------
create table if not exists agent_traces (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references auth.users(id) on delete cascade,
  conversation_id       uuid references conversations(id) on delete set null,
  input_text            text not null,
  parsed_intent         jsonb,
  candidate_providers   jsonb,
  selected_provider_id  uuid references providers(id),
  reasoning             text,
  steps                 jsonb not null default '[]'::jsonb,
  created_at            timestamptz not null default now()
);

create index if not exists agent_traces_user_idx on agent_traces(user_id, created_at desc);

-- ---------- bookings -------------------------------------------------
create table if not exists bookings (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  provider_id     uuid not null references providers(id),
  service_type    provider_category not null,
  location_text   text not null,
  scheduled_at    timestamptz not null,
  status          booking_status not null default 'confirmed',
  agent_trace_id  uuid references agent_traces(id),
  created_at      timestamptz not null default now()
);

create index if not exists bookings_user_idx     on bookings(user_id, scheduled_at desc);
create index if not exists bookings_provider_idx on bookings(provider_id, scheduled_at);

-- ---------- notifications -------------------------------------------
create table if not exists notifications (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid not null references bookings(id) on delete cascade,
  kind          notification_kind not null,
  scheduled_at  timestamptz not null,
  sent_at       timestamptz,
  payload       jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now()
);

create index if not exists notifications_due_idx
  on notifications(scheduled_at) where sent_at is null;

-- ---------- RLS ------------------------------------------------------
alter table profiles      enable row level security;
alter table bookings      enable row level security;
alter table notifications enable row level security;
alter table agent_traces  enable row level security;
alter table conversations enable row level security;
alter table providers     enable row level security;

drop policy if exists "own profile"        on profiles;
drop policy if exists "own bookings"       on bookings;
drop policy if exists "own notifications"  on notifications;
drop policy if exists "own traces"         on agent_traces;
drop policy if exists "own conversations"  on conversations;
drop policy if exists "providers public read" on providers;

create policy "own profile"
  on profiles for all
  using (id = auth.uid()) with check (id = auth.uid());

create policy "own bookings"
  on bookings for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "own notifications"
  on notifications for all
  using (exists (select 1 from bookings b
                 where b.id = notifications.booking_id
                   and b.user_id = auth.uid()))
  with check (exists (select 1 from bookings b
                      where b.id = notifications.booking_id
                        and b.user_id = auth.uid()));

create policy "own traces"
  on agent_traces for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "own conversations"
  on conversations for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "providers public read"
  on providers for select using (true);
