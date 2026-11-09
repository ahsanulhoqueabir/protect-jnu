# Admin provisioning runbook (D-017, PRD 5.1)

Runbook, not a migration. There is no public admin signup. An admin is a normal student account (jnu.ac.bd email, student ID, verified by OTP) that the project team promotes.

## Promote
1. The person registers in the student app and verifies their email by OTP. Check `email_verified_at` is set.
2. A project-team member runs, through the Supabase MCP `execute_sql` (or the SQL editor), replacing the email:

```sql
update public.profiles
set role = 'admin'
where university_email = 'name@jnu.ac.bd'
  and email_verified_at is not null
returning id, university_email, role;
```

3. Expect exactly one row. Zero rows means the email is wrong or not verified; do not drop the `email_verified_at` condition.

## Demote
```sql
update public.profiles set role = 'user' where university_email = 'name@jnu.ac.bd' returning id, university_email, role;
```

## Notes
- Students cannot do this themselves: `authenticated` may update only `full_name` and `phone` on `profiles` (0008), and the policy pins `role`.
- Run these only with the project team's database access (MCP or SQL editor), never from client code or a public API route.
- Existing test profiles created before 2026-11-09 have a non-conforming `student_id`. The `profiles_student_id_format` check was added `NOT VALID`, so an UPDATE of such a row fails until its `student_id` is fixed.
- The dashboard must still reject non-admin accounts (PRD 5.1); that is enforced in Phase 3 web code, not here.
