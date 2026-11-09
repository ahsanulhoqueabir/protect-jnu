-- 0003_handle_new_user.sql — atomic profile creation on signup
-- The profile insert runs in the SAME transaction as the auth.users insert:
-- if it fails, the auth user is not created. No compensating deletes needed.
-- Server passes name/username via auth.admin.createUser({ user_metadata }).

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles ("user", email, name, username)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    nullif(new.raw_user_meta_data ->> 'username', '')
  );
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
