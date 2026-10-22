## Next.js rules

- **NX1** Server-only code (secrets, DB clients) imported into a `"use client"` module, or env vars without
  `NEXT_PUBLIC_` read on the client → **blocker**.
- **NX2** A Server Action or route handler without auth/ownership checks on the resource it mutates →
  **blocker**.
- **NX3** `fetch` caching/revalidation left at the default where data must be fresh (or must not be) →
  **major** with a scenario.
- **NX4** A `redirect()`/`notFound()` inside `try/catch` that swallows the thrown control-flow error →
  **major**.
