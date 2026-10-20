-- Aurelia Care, part 3. Run AFTER schema.sql and schema_v2.sql.

-- Wards, beds, admissions
create table public.wards (id uuid primary key default gen_random_uuid(), name text not null unique, created_at timestamptz not null default now());
create table public.beds (id uuid primary key default gen_random_uuid(), ward_id uuid not null references public.wards(id) on delete cascade, label text not null, created_at timestamptz not null default now(), unique (ward_id, label));
create table public.admissions (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  bed_id uuid not null references public.beds(id),
  reason text,
  admitted_at timestamptz not null default now(),
  discharged_at timestamptz,
  discharge_note text,
  admitted_by uuid references public.profiles(id)
);
create unique index one_open_admission_per_bed on public.admissions(bed_id) where discharged_at is null;
create unique index one_open_admission_per_patient on public.admissions(patient_id) where discharged_at is null;

-- Prescriptions
create table public.prescriptions (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  medicine_id uuid not null references public.medicines(id),
  dosage text not null,
  quantity integer not null check (quantity > 0),
  status text not null default 'pending' check (status in ('pending','dispensed','cancelled')),
  prescribed_by uuid references public.profiles(id),
  dispensed_by uuid references public.profiles(id),
  dispensed_at timestamptz,
  created_at timestamptz not null default now()
);

-- Insurance claims
create table public.insurance_claims (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  patient_id uuid not null references public.patients(id) on delete cascade,
  provider text not null,
  policy_number text,
  amount_claimed numeric(12,2) not null check (amount_claimed >= 0),
  status text not null default 'submitted' check (status in ('submitted','approved','rejected','paid')),
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Audit log (written only by triggers, readable only by admins)
create table public.audit_log (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete set null,
  action text not null,
  table_name text not null,
  record_id text,
  details jsonb,
  created_at timestamptz not null default now()
);
create index on public.audit_log(created_at desc);

create or replace function public.log_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare rid text; det jsonb;
begin
  rid := (case when tg_op = 'DELETE' then old.id else new.id end)::text;
  if tg_table_name = 'profiles' and tg_op = 'UPDATE' then
    if old.role is distinct from new.role then
      det := jsonb_build_object('old_role', old.role, 'new_role', new.role);
    end if;
  end if;
  insert into public.audit_log (user_id, action, table_name, record_id, details)
  values (auth.uid(), tg_op, tg_table_name, rid, det);
  return null;
end $$;

do $$ declare t text; begin
  foreach t in array array['patients','appointments','visit_notes','invoices','medicines','lab_tests','prescriptions','admissions','insurance_claims','profiles','wards','beds'] loop
    execute format('create trigger audit_%1$s after insert or update or delete on public.%1$s for each row execute function public.log_change()', t);
  end loop;
end $$;

-- Dispense in one safe step: checks stock, reduces it, marks the prescription dispensed
create or replace function public.dispense_prescription(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare rx public.prescriptions;
begin
  if public.my_role() not in ('admin','nurse') then raise exception 'Only a nurse or admin can dispense medicine.'; end if;
  select * into rx from public.prescriptions where id = p_id for update;
  if not found then raise exception 'Prescription not found.'; end if;
  if rx.status <> 'pending' then raise exception 'This prescription is not pending.'; end if;
  update public.medicines set stock = stock - rx.quantity where id = rx.medicine_id and stock >= rx.quantity;
  if not found then raise exception 'Not enough stock to dispense this prescription.'; end if;
  update public.prescriptions set status = 'dispensed', dispensed_by = auth.uid(), dispensed_at = now() where id = p_id;
end $$;

alter table public.wards enable row level security;
alter table public.beds enable row level security;
alter table public.admissions enable row level security;
alter table public.prescriptions enable row level security;
alter table public.insurance_claims enable row level security;
alter table public.audit_log enable row level security;

create policy "staff read wards" on public.wards for select using (public.my_role() in ('admin','doctor','nurse','receptionist'));
create policy "admin manage wards" on public.wards for all using (public.my_role() = 'admin') with check (public.my_role() = 'admin');
create policy "staff read beds" on public.beds for select using (public.my_role() in ('admin','doctor','nurse','receptionist'));
create policy "admin manage beds" on public.beds for all using (public.my_role() = 'admin') with check (public.my_role() = 'admin');

create policy "staff read admissions" on public.admissions for select using (public.my_role() in ('admin','doctor','nurse','receptionist'));
create policy "clinical admit" on public.admissions for insert with check (public.my_role() in ('admin','doctor','nurse'));
create policy "clinical discharge" on public.admissions for update using (public.my_role() in ('admin','doctor','nurse'));
create policy "admin deletes admissions" on public.admissions for delete using (public.my_role() = 'admin');

create policy "clinical read rx" on public.prescriptions for select using (public.my_role() in ('admin','doctor','nurse'));
create policy "doctor prescribes" on public.prescriptions for insert with check (public.my_role() in ('admin','doctor') and prescribed_by = auth.uid());
create policy "doctor cancels rx" on public.prescriptions for update using (public.my_role() in ('admin','doctor'));
create policy "admin deletes rx" on public.prescriptions for delete using (public.my_role() = 'admin');

create policy "claims read" on public.insurance_claims for select using (public.my_role() in ('admin','receptionist'));
create policy "claims add" on public.insurance_claims for insert with check (public.my_role() in ('admin','receptionist'));
create policy "claims update" on public.insurance_claims for update using (public.my_role() in ('admin','receptionist'));
create policy "admin deletes claims" on public.insurance_claims for delete using (public.my_role() = 'admin');

create policy "admin reads audit" on public.audit_log for select using (public.my_role() = 'admin');
