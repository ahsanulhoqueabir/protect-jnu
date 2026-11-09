-- 0005_d032_test_restore_domain_check.sql
-- Restores public.handle_new_user() to the exact definition that was applied
-- before 0004 (pg_get_functiondef md5 8c5930f7b95a6a5b2cd9f8a5b7df613e).

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
  if v_email !~ '^[^@]+@jnu\.ac\.bd$' then
    raise exception 'Only @jnu.ac.bd email addresses are allowed'
      using errcode = 'check_violation';
  end if;

  insert into public.profiles (id, full_name, student_id, university_email)
  values (new.id, v_full_name, v_student_id, v_email);

  return new;
end;
$function$;
