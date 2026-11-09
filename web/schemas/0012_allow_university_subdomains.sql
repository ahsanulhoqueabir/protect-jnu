-- 0012_allow_university_subdomains.sql
-- Decision D-052 (2026-11-09, project owner): accept `name@jnu.ac.bd` AND `name@<dept>.jnu.ac.bd`
-- (for example cse.jnu.ac.bd). PRD 5.1 amended. Look-alikes (jnu.ac.bd.evil.com, xjnu.ac.bd,
-- a@b@jnu.ac.bd) stay rejected. Same pattern as web/schema/auth.schema.ts.
--
-- Only the domain test changes. handle_new_user() is otherwise exactly the function that is live
-- (it still does NOT trim/uppercase student_id: that change was declined, server code does it).

-- 1. Table constraint. Existing rows all end in @jnu.ac.bd, so they still satisfy it.
alter table public.profiles drop constraint if exists profiles_university_email_domain;
alter table public.profiles
  add constraint profiles_university_email_domain
  check (
    university_email = lower(university_email)
    and university_email ~ '^[^@\s]+@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)*jnu\.ac\.bd$'
  );

-- 2. Signup trigger (security definer, runs on auth.users insert). Privileges are kept by REPLACE.
create or replace function public.handle_new_user()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_email text := lower(trim(coalesce(new.email, '')));
  v_full_name text := coalesce(new.raw_user_meta_data ->> 'full_name', '');
  v_student_id text := coalesce(new.raw_user_meta_data ->> 'student_id', '');
begin
  if v_email !~ '^[^@\s]+@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)*jnu\.ac\.bd$' then
    raise exception 'Only university email addresses (jnu.ac.bd and its subdomains) are allowed'
      using errcode = 'check_violation';
  end if;

  insert into public.profiles (id, full_name, student_id, university_email)
  values (new.id, v_full_name, v_student_id, v_email);

  return new;
end;
$function$;
