create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  student_id text unique,
  display_name text,
  role text not null default 'student' check (role in ('student', 'admin')),
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_app_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  current_chapter_id integer,
  current_chapter_index integer not null default 0,
  progress jsonb not null default '{}'::jsonb,
  output_progress jsonb not null default '{}'::jsonb,
  reminder jsonb not null default '{}'::jsonb,
  quick_question jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.daily_learning_records (
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

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists touch_profiles_updated_at on public.profiles;
create trigger touch_profiles_updated_at
before update on public.profiles
for each row execute function public.touch_updated_at();

drop trigger if exists touch_user_app_state_updated_at on public.user_app_state;
create trigger touch_user_app_state_updated_at
before update on public.user_app_state
for each row execute function public.touch_updated_at();

drop trigger if exists touch_daily_learning_records_updated_at on public.daily_learning_records;
create trigger touch_daily_learning_records_updated_at
before update on public.daily_learning_records
for each row execute function public.touch_updated_at();

create or replace function public.normalize_student_id(raw_value text, fallback_email text)
returns text
language sql
immutable
as $$
  select lower(
    regexp_replace(
      coalesce(nullif(raw_value, ''), split_part(coalesce(fallback_email, ''), '@', 1), 'student'),
      '[^a-zA-Z0-9_-]',
      '_',
      'g'
    )
  );
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, student_id, display_name, role, status)
  values (
    new.id,
    coalesce(new.email, ''),
    public.normalize_student_id(new.raw_user_meta_data ->> 'student_id', new.email),
    coalesce(new.raw_user_meta_data ->> 'display_name', new.raw_user_meta_data ->> 'name'),
    coalesce(new.raw_app_meta_data ->> 'role', 'student'),
    'active'
  )
  on conflict (id) do update
    set email = excluded.email,
        student_id = coalesce(public.profiles.student_id, excluded.student_id),
        display_name = coalesce(public.profiles.display_name, excluded.display_name),
        updated_at = now();

  insert into public.user_app_state (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

insert into public.profiles (id, email, student_id, display_name, role, status)
select
  users.id,
  coalesce(users.email, ''),
  public.normalize_student_id(users.raw_user_meta_data ->> 'student_id', users.email),
  coalesce(users.raw_user_meta_data ->> 'display_name', users.raw_user_meta_data ->> 'name'),
  coalesce(users.raw_app_meta_data ->> 'role', 'student'),
  'active'
from auth.users
on conflict (id) do nothing;

insert into public.user_app_state (user_id)
select users.id
from auth.users
on conflict (user_id) do nothing;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'admin'
      and status = 'active'
  );
$$;

alter table public.profiles enable row level security;
alter table public.user_app_state enable row level security;
alter table public.daily_learning_records enable row level security;

drop policy if exists "profiles_select_own_or_admin" on public.profiles;
create policy "profiles_select_own_or_admin"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id or public.is_admin());

drop policy if exists "profiles_update_own_or_admin" on public.profiles;
drop policy if exists "profiles_update_admin_only" on public.profiles;
create policy "profiles_update_admin_only"
on public.profiles
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "user_app_state_select_own_or_admin" on public.user_app_state;
create policy "user_app_state_select_own_or_admin"
on public.user_app_state
for select
to authenticated
using ((select auth.uid()) = user_id or public.is_admin());

drop policy if exists "user_app_state_insert_own_or_admin" on public.user_app_state;
create policy "user_app_state_insert_own_or_admin"
on public.user_app_state
for insert
to authenticated
with check ((select auth.uid()) = user_id or public.is_admin());

drop policy if exists "user_app_state_update_own_or_admin" on public.user_app_state;
create policy "user_app_state_update_own_or_admin"
on public.user_app_state
for update
to authenticated
using ((select auth.uid()) = user_id or public.is_admin())
with check ((select auth.uid()) = user_id or public.is_admin());

drop policy if exists "daily_learning_records_select_own_or_admin" on public.daily_learning_records;
create policy "daily_learning_records_select_own_or_admin"
on public.daily_learning_records
for select
to authenticated
using ((select auth.uid()) = user_id or public.is_admin());

drop policy if exists "daily_learning_records_insert_own_or_admin" on public.daily_learning_records;
create policy "daily_learning_records_insert_own_or_admin"
on public.daily_learning_records
for insert
to authenticated
with check ((select auth.uid()) = user_id or public.is_admin());

drop policy if exists "daily_learning_records_update_own_or_admin" on public.daily_learning_records;
create policy "daily_learning_records_update_own_or_admin"
on public.daily_learning_records
for update
to authenticated
using ((select auth.uid()) = user_id or public.is_admin())
with check ((select auth.uid()) = user_id or public.is_admin());

grant usage on schema public to authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert, update on public.user_app_state to authenticated;
grant select, insert, update on public.daily_learning_records to authenticated;
grant execute on function public.is_admin() to authenticated;
