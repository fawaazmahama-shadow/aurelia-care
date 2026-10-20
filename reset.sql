-- Aurelia Care: START OVER. Deletes every Aurelia Care table and all its data.
-- Only use this if the Supabase project is used for Aurelia Care alone.
-- After it succeeds, run schema.sql, schema_v2.sql, schema_v3.sql again, in order.

drop trigger if exists on_auth_user_created on auth.users;

drop table if exists public.audit_log, public.insurance_claims, public.prescriptions, public.admissions,
  public.beds, public.wards, public.lab_tests, public.medicines, public.invoices,
  public.visit_notes, public.appointments, public.patients, public.profiles cascade;

drop function if exists public.dispense_prescription(uuid);
drop function if exists public.log_change() cascade;
drop function if exists public.protect_role() cascade;
drop function if exists public.handle_new_user() cascade;
drop function if exists public.my_role() cascade;
