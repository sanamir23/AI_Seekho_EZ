-- Migration 002: Booking conflict prevention
-- Run this in the Supabase SQL editor.

-- Prevent the same provider from being booked at the exact same timestamp twice.
-- Cancelled / completed bookings are excluded so they don't block future slots.
-- The 60-minute window overlap check is handled at the application level in find_providers.
create unique index if not exists bookings_provider_unique_slot
  on bookings (provider_id, scheduled_at)
  where status in ('confirmed', 'pending');

-- Partial index for fast conflict-check queries in find_providers.
create index if not exists bookings_provider_slot_idx
  on bookings (provider_id, scheduled_at)
  where status in ('confirmed', 'pending');
