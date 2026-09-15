-- 0001_extensions.sql
-- Required Postgres extensions for the Celo-HaiTi Supabase foundation.

create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "pg_trgm";    -- text search on wallet addresses / titles
