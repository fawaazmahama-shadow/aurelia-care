-- Aurelia Care, part 1. Run this FIRST in the Supabase SQL Editor.
-- Creates profiles (staff accounts and roles), patients, appointments, visit notes.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  role text not null default 'pending' check (role in ('admin','doctor','nurse','receptionist','pending')),
  created_at timestamptz not null default now()
);

-- Role of the signed-in user. security definer so policies can call it without recursion.
create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

-- Every new sign-up gets a profile with the role "pending" until an admin approves them.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', ''));
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

-- Only admins can change roles. (The SQL Editor has no signed-in user, so you can make the first admin there.)
create or replace function public.protect_role() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role and auth.uid() is not null and coalesce(public.my_role(), '') <> 'admin' then
    raise exception 'Only an admin can change roles.';
  end if;
  return new;
end $$;

create trigger profiles_protect_role before update on public.profiles
for each row execute function public.protect_role();

create table public.patients (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  dob date,
  gender text,
  phone text,
  address text,
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  doctor_id uuid references public.profiles(id) on delete set null,
  scheduled_at timestamptz not null,
  reason text,
  status text not null default 'scheduled' check (status in ('scheduled','completed','cancelled')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index on public.appointments(scheduled_at);

create table public.visit_notes (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  author_id uuid references public.profiles(id) on delete set null,
  diagnosis text,
  notes text not null,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.patients enable row level security;
alter table public.appointments enable row level security;
alter table public.visit_notes enable row level security;

-- profiles
create policy "read own profile" on public.profiles for select using (id = auth.uid());
create policy "staff read profiles" on public.profiles for select using (public.my_role() in ('admin','doctor','nurse','receptionist'));
create policy "update own profile" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
create policy "admin update profiles" on public.profiles for update using (public.my_role() = 'admin') with check (public.my_role() = 'admin');

-- patients
create policy "staff read patients" on public.patients for select using (public.my_role() in ('admin','doctor','nurse','receptionist'));
create policy "staff add patients" on public.patients for insert with check (public.my_role() in ('admin','doctor','nurse','receptionist'));
create policy "staff edit patients" on public.patients for update using (public.my_role() in ('admin','doctor','nurse','receptionist'));
create policy "admin deletes patients" on public.patients for delete using (public.my_role() = 'admin');

-- appointments
create policy "staff read appointments" on public.appointments for select using (public.my_role() in ('admin','doctor','nurse','receptionist'));
create policy "staff add appointments" on public.appointments for insert with check (public.my_role() in ('admin','doctor','nurse','receptionist'));
create policy "staff edit appointments" on public.appointments for update using (public.my_role() in ('admin','doctor','nurse','receptionist'));
create policy "admin deletes appointments" on public.appointments for delete using (public.my_role() = 'admin');

-- visit notes (hidden from receptionists)
create policy "clinical read notes" on public.visit_notes for select using (public.my_role() in ('admin','doctor','nurse'));
create policy "clinical add notes" on public.visit_notes for insert with check (public.my_role() in ('admin','doctor','nurse') and author_id = auth.uid());
create policy "admin deletes notes" on public.visit_notes for delete using (public.my_role() = 'admin');

-- Give a profile to any account that signed up before this script ran.
insert into public.profiles (id, email, full_name)
select id, email, coalesce(raw_user_meta_data->>'full_name', '') from auth.users
on conflict (id) do nothing;
