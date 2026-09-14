#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/.." && pwd)
cd "$repo_root"

container_name="celoht-supabase-verify-$$"
cleanup() {
  docker rm -f "$container_name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --name "$container_name" \
  --health-cmd='pg_isready -U postgres' \
  --health-interval=1s --health-timeout=1s --health-retries=60 \
  -e POSTGRES_PASSWORD=postgres -d postgres:16 >/dev/null

ready=0
for attempt in $(seq 1 12000); do
  status=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null || true)
  if [[ "$status" == "healthy" ]]; then
    ready=1
    break
  fi
done
[[ "$ready" == 1 ]]

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 <<'SQL'
create schema auth;
create schema storage;
create table auth.users (id uuid primary key);
create table storage.buckets (id text primary key, name text not null, public boolean not null);
create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text not null, name text not null);
create function auth.uid() returns uuid language sql stable as 'select null::uuid';
create function auth.role() returns text language sql stable as 'select ''anon''::text';
create function storage.foldername(path text) returns text[] language sql immutable as 'select string_to_array(path, ''/'')';
SQL

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c 'create role authenticated; create role anon;'

while IFS= read -r migration; do
  docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
    -f - < "$migration"
done < <(find . -maxdepth 1 -type f -name '[0-9]*.sql' -printf '%f\n' | sort)

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f - < tests/database.sql

echo 'Disposable PostgreSQL verification passed.'
