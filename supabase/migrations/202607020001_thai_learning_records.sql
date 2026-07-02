create table if not exists public.thai_user_app_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  current_chapter_id integer,
  current_chapter_index integer not null default 0,
  progress jsonb not null default '{}'::jsonb,
  output_progress jsonb not null default '{}'::jsonb,
  reminder jsonb not null default '{}'::jsonb,
  quick_question jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.thai_daily_learning_records (
  user_id uuid not null references auth.users(id) on delete cascade,
  record_date date not null,
  time_ms integer not null default 0 check (time_ms >= 0),
  answered integer not null default 0 check (answered >= 0),
  correct integer not null default 0 check (correct >= 0),
  chapters_completed integer not null default 0 check (chapters_completed >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, record_date),
  check (correct <= answered)
);

drop trigger if exists touch_thai_user_app_state_updated_at on public.thai_user_app_state;
create trigger touch_thai_user_app_state_updated_at
before update on public.thai_user_app_state
for each row execute function public.touch_updated_at();

drop trigger if exists touch_thai_daily_learning_records_updated_at on public.thai_daily_learning_records;
create trigger touch_thai_daily_learning_records_updated_at
before update on public.thai_daily_learning_records
for each row execute function public.touch_updated_at();

create or replace function public.handle_new_thai_user_state()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.thai_user_app_state (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_thai_state on auth.users;
create trigger on_auth_user_created_thai_state
after insert on auth.users
for each row execute function public.handle_new_thai_user_state();

insert into public.thai_user_app_state (user_id)
select id from auth.users
on conflict (user_id) do nothing;

alter table public.thai_user_app_state enable row level security;
alter table public.thai_daily_learning_records enable row level security;

drop policy if exists "thai_user_app_state_select_own_or_admin" on public.thai_user_app_state;
create policy "thai_user_app_state_select_own_or_admin"
on public.thai_user_app_state for select to authenticated
using ((select auth.uid()) = user_id or public.is_admin());

drop policy if exists "thai_user_app_state_insert_own_or_admin" on public.thai_user_app_state;
create policy "thai_user_app_state_insert_own_or_admin"
on public.thai_user_app_state for insert to authenticated
with check ((select auth.uid()) = user_id or public.is_admin());

drop policy if exists "thai_user_app_state_update_own_or_admin" on public.thai_user_app_state;
create policy "thai_user_app_state_update_own_or_admin"
on public.thai_user_app_state for update to authenticated
using ((select auth.uid()) = user_id or public.is_admin())
with check ((select auth.uid()) = user_id or public.is_admin());

drop policy if exists "thai_daily_records_select_own_or_admin" on public.thai_daily_learning_records;
create policy "thai_daily_records_select_own_or_admin"
on public.thai_daily_learning_records for select to authenticated
using ((select auth.uid()) = user_id or public.is_admin());

drop policy if exists "thai_daily_records_insert_own_or_admin" on public.thai_daily_learning_records;
create policy "thai_daily_records_insert_own_or_admin"
on public.thai_daily_learning_records for insert to authenticated
with check ((select auth.uid()) = user_id or public.is_admin());

drop policy if exists "thai_daily_records_update_own_or_admin" on public.thai_daily_learning_records;
create policy "thai_daily_records_update_own_or_admin"
on public.thai_daily_learning_records for update to authenticated
using ((select auth.uid()) = user_id or public.is_admin())
with check ((select auth.uid()) = user_id or public.is_admin());

grant select, insert, update on public.thai_user_app_state to authenticated;
grant select, insert, update on public.thai_daily_learning_records to authenticated;
