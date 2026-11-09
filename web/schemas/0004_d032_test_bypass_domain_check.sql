-- 0004_d032_test_bypass_domain_check.sql  (TEMPORARY, reverted by 0005)
-- Purpose: let ONE reserved test address pass the @jnu.ac.bd check so the D-032
-- verification (Supabase Auth email behaviour / sign-in gating) can run without
-- touching any real university mailbox. Applied 2026-11-09, user-approved.
-- Everything except the extra allowed address is identical to the applied function.

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
  if v_email !~ '^[^@]+@jnu\.ac\.bd$' and v_email <> 'd032-test@invalid.example' then
    raise exception 'Only @jnu.ac.bd email addresses are allowed'
      using errcode = 'check_violation';
  end if;

  insert into public.profiles (id, full_name, student_id, university_email)
  values (new.id, v_full_name, v_student_id, v_email);

  return new;
end;
$function$;
