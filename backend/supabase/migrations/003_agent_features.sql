-- =====================================================================
-- 003_agent_features.sql  (part 1 of 2)
--   Adds the 'held' enum value. Postgres requires this be COMMITTED before
--   any other statement can REFERENCE it, so the rest of the schema work
--   lives in 004_agent_features_part2.sql — run 003 first, then 004.
-- =====================================================================

do $$ begin
  alter type booking_status add value if not exists 'held';
exception when others then null; end $$;
