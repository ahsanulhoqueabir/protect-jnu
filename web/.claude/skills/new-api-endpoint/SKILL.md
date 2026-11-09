---
name: new-api-endpoint
description: Add a single API route handler to an existing domain using the template's route → schema → service layering. Use when adding or changing an endpoint.
---

Template (route stays thin; see `app/api/auth/login/route.ts`, `app/api/auth/me/route.ts`):

```ts
export const POST = withAuth(async ({ req, user }) => {
  const parsed = await parseBody(req, createXSchema);   // schema/x.schema.ts
  if (!parsed.ok) return parsed.response;

  const result = await XService.create(user.profile, parsed.data); // services/x.service.ts
  if (!result.success) return fail({ error: result.error, statusCode: 400 });

  return ok({ data: result.data, statusCode: 201 });
});
```

Checklist: schema exists in `schema/` (reuse, don't redefine) · service method returns `ServiceResult` · no Supabase import in the route · ownership/role check lives in the service · public endpoints live under `/api/auth/` (the axios client skips the auth guard for that prefix — add new public prefixes in `lib/api/api-client.ts` deliberately) · return projections, never raw rows · run `npx tsc --noEmit`.
