# Database behavior tests

Run locally against the disposable Supabase database:

```sh
supabase start
supabase db reset --no-seed
supabase test db
```

The pgTAP suite uses deterministic fake identities and rolls back every fixture. It never connects to hosted Supabase.

## Release-blocking TODO tests

TODO assertions are executable documentation, not successful acceptance tests. Convert them to mandatory assertions before deployment when the corresponding implementation exists:

- trusted SECURITY DEFINER write RPCs, including `create_post`;
- atomic enforcement of three posts per rolling 24-hour window.

All implemented constraints, permissions, RLS policy behavior, API projections, privacy boundaries, lifecycle rules, and interaction compatibility remain mandatory tests and fail CI on regressions. The suite temporarily grants base-table read access inside its rollback-only transaction so RLS is exercised independently of schema privilege denial.
