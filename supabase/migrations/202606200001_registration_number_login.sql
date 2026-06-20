alter table public.profiles
  add column if not exists registration_number text unique,
  add column if not exists registered_order integer unique,
  add column if not exists registered_at timestamptz;

create sequence if not exists public.registration_number_seq
  as integer
  increment by 1
  minvalue 1
  start with 1
  owned by none;

create or replace function public.reserve_registration_number()
returns table (registration_number text, registered_order integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  next_order integer;
begin
  next_order := nextval('public.registration_number_seq');
  registration_number := lpad(next_order::text, 2, '0');
  registered_order := next_order;
  return next;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    email,
    student_id,
    display_name,
    registration_number,
    registered_order,
    registered_at,
    role,
    status
  )
  values (
    new.id,
    coalesce(new.email, ''),
    public.normalize_student_id(new.raw_user_meta_data ->> 'student_id', new.email),
    coalesce(new.raw_user_meta_data ->> 'display_name', new.raw_user_meta_data ->> 'name'),
    new.raw_user_meta_data ->> 'registration_number',
    nullif(new.raw_user_meta_data ->> 'registered_order', '')::integer,
    case
      when new.raw_user_meta_data ? 'registration_number' then now()
      else null
    end,
    coalesce(new.raw_app_meta_data ->> 'role', 'student'),
    'active'
  )
  on conflict (id) do update
    set email = excluded.email,
        student_id = coalesce(excluded.student_id, public.profiles.student_id),
        display_name = coalesce(public.profiles.display_name, excluded.display_name),
        registration_number = coalesce(public.profiles.registration_number, excluded.registration_number),
        registered_order = coalesce(public.profiles.registered_order, excluded.registered_order),
        registered_at = coalesce(public.profiles.registered_at, excluded.registered_at),
        updated_at = now();

  insert into public.user_app_state (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

update public.profiles
set
  registration_number = coalesce(registration_number, student_id),
  registered_at = coalesce(registered_at, created_at)
where student_id ~ '^[0-9]{2,4}$'
  and registration_number is null;

select setval(
  'public.registration_number_seq',
  greatest(
    1,
    coalesce((select max(registration_number::integer) from public.profiles where registration_number ~ '^[0-9]+$'), 0) + 1
  ),
  false
);

grant execute on function public.reserve_registration_number() to authenticated;
