-- Aurelia Care, part 4 (public website booking requests). Run AFTER schema.sql, schema_v2.sql and schema_v3.sql.
-- Lets visitors to the public website send an appointment request. Only the front desk and admins can read them.

create table public.appointment_requests (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (char_length(full_name) between 2 and 120),
  phone text not null check (char_length(phone) between 6 and 30),
  email text check (email is null or char_length(email) <= 160),
  department text check (department is null or char_length(department) <= 80),
  preferred_date date,
  message text check (message is null or char_length(message) <= 1000),
  status text not null default 'new' check (status in ('new','contacted','booked','declined')),
  created_at timestamptz not null default now()
);
create index on public.appointment_requests(created_at desc);

alter table public.appointment_requests enable row level security;

-- Anyone (including people who are not signed in) can add a new request, and nothing else.
create policy "public sends request" on public.appointment_requests for insert to anon, authenticated with check (status = 'new');
create policy "front desk reads requests" on public.appointment_requests for select using (public.my_role() in ('admin','receptionist'));
create policy "front desk updates requests" on public.appointment_requests for update using (public.my_role() in ('admin','receptionist'));
create policy "admin deletes requests" on public.appointment_requests for delete using (public.my_role() = 'admin');
