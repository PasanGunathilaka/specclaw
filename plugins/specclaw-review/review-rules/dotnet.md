## .NET rules

- **DN1** `async void` outside event handlers, or `.Result`/`.Wait()` on tasks (deadlock risk) → **major**.
- **DN2** `catch (Exception)` that logs and continues where the caller needs to know (B3) → **major**.
- **DN3** EF Core: a query inside a loop (N+1) on a request path, or tracking queries used for read-only
  lists → **minor**. A missing `SaveChanges` in a transaction scope, or a partial save → **major**.
- **DN4** An inner Clean Architecture layer referencing an outer one (Domain → Infrastructure) → **major**.
- **DN5** String-concatenated SQL or `FromSqlRaw` with interpolated input → **blocker** (B8).
- **DN6** `IDisposable`/`HttpClient` created per call without `using` or a factory → **major**.
