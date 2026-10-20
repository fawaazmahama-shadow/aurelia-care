-- Aurelia Care, part 2. Run AFTER schema.sql.
-- Creates invoices, medicines (pharmacy stock) and lab tests.

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  amount numeric(12,2) not null check (amount >= 0),
  description text not null,
  status text not null default 'unpaid' check (status in ('unpaid','paid','void')),
  payment_method text,
  paid_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.medicines (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  unit text not null default 'tablets',
  stock integer not null default 0 check (stock >= 0),
  reorder_level integer not null default 10 check (reorder_level >= 0),
  unit_price numeric(12,2) not null default 0 check (unit_price >= 0),
  created_at timestamptz not null default now()
);

create table public.lab_tests (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  test_name text not null,
  status text not null default 'ordered' check (status in ('ordered','completed')),
  result text,
  ordered_by uuid references public.profiles(id) on delete set null,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.invoices enable row level security;
alter table public.medicines enable row level security;
alter table public.lab_tests enable row level security;

-- invoices: admin and receptionist only
create policy "billing read" on public.invoices for select using (public.my_role() in ('admin','receptionist'));
create policy "billing add" on public.invoices for insert with check (public.my_role() in ('admin','receptionist'));
create policy "billing update" on public.invoices for update using (public.my_role() in ('admin','receptionist'));
create policy "admin deletes invoices" on public.invoices for delete using (public.my_role() = 'admin');

-- medicines: clinical staff view; admin and nurse change stock
create policy "clinical read medicines" on public.medicines for select using (public.my_role() in ('admin','doctor','nurse'));
create policy "stock add" on public.medicines for insert with check (public.my_role() in ('admin','nurse'));
create policy "stock update" on public.medicines for update using (public.my_role() in ('admin','nurse'));
create policy "admin deletes medicines" on public.medicines for delete using (public.my_role() = 'admin');

-- lab tests: clinical staff only; admin and doctor order, all clinical staff record results
create policy "clinical read lab" on public.lab_tests for select using (public.my_role() in ('admin','doctor','nurse'));
create policy "doctor orders lab" on public.lab_tests for insert with check (public.my_role() in ('admin','doctor') and ordered_by = auth.uid());
create policy "clinical records result" on public.lab_tests for update using (public.my_role() in ('admin','doctor','nurse'));
create policy "admin deletes lab" on public.lab_tests for delete using (public.my_role() = 'admin');
