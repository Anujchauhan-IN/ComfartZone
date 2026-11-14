# Supabase CLI

Use Supabase CLI **v3.1.0** for this repository:

```sh
npx supabase@3.1.0 <command>
```

The version is pinned in the command instead of adding a package dependency, so migration tooling does not change the application dependency graph. v3.1.0 was selected because it is the latest stable release; prerelease v4 builds are intentionally excluded. Release: https://github.com/supabase/cli/releases/tag/v3.1.0

`config.toml` exposes only the `api` schema through the Data API. `public` and `extensions` remain on PostgREST's extra search path for system and extension resolution, but are not exposed schemas.
