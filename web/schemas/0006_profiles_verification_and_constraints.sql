-- 0006_profiles_verification_and_constraints.sql
-- Phase 1, approved in docs/phases/phase-1-schema.md (D-043, D-044, D-020).
-- Adds verification state and format/uniqueness constraints to profiles.

-- 1. Verification state (set by trusted server code after OTP; not client-writable, see 0008).
alter table public.profiles add column if not exists email_verified_at timestamptz;

-- 2. Existing rows are NOT modified (user decision 2026-11-09). The student-ID format check
--    is added NOT VALID: it is enforced for new rows and for any UPDATE of a row, but old rows
--    are not scanned. The 3 pre-existing test profiles hold non-conforming IDs, so updating
--    them fails until their student_id is fixed; `validate constraint` can run afterwards.

-- 3. Constraints (guarded so the file can be re-run).
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_student_id_format') then
    alter table public.profiles
      add constraint profiles_student_id_format check (student_id ~ '^B[0-9]{9}$') not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_student_id_key') then
    alter table public.profiles add constraint profiles_student_id_key unique (student_id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_university_email_domain') then
    alter table public.profiles
      add constraint profiles_university_email_domain
      check (university_email = lower(university_email) and university_email ~ '^[^@]+@jnu\.ac\.bd$');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_phone_format') then
    alter table public.profiles
      add constraint profiles_phone_format
      check (phone is null or phone ~ '^(\+880)?[0-9]{10,11}$');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'emergency_contacts_phone_format') then
    alter table public.emergency_contacts
      add constraint emergency_contacts_phone_format
      check (phone ~ '^(\+880)?[0-9]{10,11}$');
  end if;
end $$;

-- The unique constraint above supersedes the plain index.
drop index if exists public.idx_profiles_student_id;

-- 4. handle_new_user() is intentionally NOT changed here (user declined, 2026-11-09).
--    Normalising student_id (trim, uppercase) moves to the server code in Phase 2;
--    the CHECK above still rejects anything that is not exactly B + 9 digits.
