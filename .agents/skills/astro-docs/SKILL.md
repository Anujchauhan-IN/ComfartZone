---
name: astro-docs
description: Find current, official Astro guidance for routing, server rendering, endpoints, middleware, sessions, React islands, TypeScript, Tailwind CSS v4, Supabase, and deployment. Use when planning, implementing, or reviewing Astro behavior and APIs.
metadata:
  source: https://docs.astro.build/
---

# Astro Documentation

Use the current official Astro documentation as the source of truth. Do not rely on remembered APIs when behavior may vary by Astro version, rendering mode, integration, adapter, or deployment platform.

## Workflow

1. Inspect the project's Astro version, configuration, integrations, rendering mode, and deployment target when relevant.
2. Open or fetch the narrowest applicable official page below.
3. Verify API names, version requirements, defaults, limitations, and adapter-specific behavior before recommending code.
4. Summarize only the guidance needed for the task; do not copy whole documentation pages.
5. Prefer existing project dependencies and patterns. Do not install packages or change configuration unless the user requests it.

If an API or implementation detail is uncertain, consult `https://docs.astro.build/` before answering or editing. Prefer current documentation over archived version sites, blogs, snippets, or model memory.

## Official references

- Routing and dynamic routes: https://docs.astro.build/en/guides/routing/
- On-demand rendering and SSR: https://docs.astro.build/en/guides/on-demand-rendering/
- Static and server endpoints: https://docs.astro.build/en/guides/endpoints/
- Middleware and `locals`: https://docs.astro.build/en/guides/middleware/
- Sessions: https://docs.astro.build/en/guides/sessions/
- Islands architecture: https://docs.astro.build/en/concepts/islands/
- React integration and hydration: https://docs.astro.build/en/guides/integrations-guide/react/
- TypeScript: https://docs.astro.build/en/guides/typescript/
- Styling and Tailwind CSS v4: https://docs.astro.build/en/guides/styling/
- Supabase integration: https://docs.astro.build/en/guides/backend/supabase/
- Deployment and adapters: https://docs.astro.build/en/guides/deploy/
- Configuration reference: https://docs.astro.build/en/reference/configuration-reference/
- Runtime API reference: https://docs.astro.build/en/reference/api-reference/

## Stack guidance

For Astro + React + Tailwind CSS v4 + Supabase:

- Keep pages and layouts server-first; use React islands only where client interactivity is required.
- Select `client:*` hydration directives deliberately and avoid hydrating static presentation.
- Distinguish build-time/static endpoints from request-time server endpoints. Confirm the project's output mode and adapter before using server-only APIs.
- Keep Supabase service-role credentials server-only. Expose only explicitly public environment variables to client code.
- Treat authentication, cookies, sessions, redirects, middleware, and row-level security as separate boundaries; verify each against the Astro and Supabase documentation.
- Follow current Tailwind CSS v4 setup in Astro's styling guide rather than older `@astrojs/tailwind` or Tailwind v3 instructions.
- Use strict TypeScript, typed `App.Locals`/environment access where applicable, and run Astro's type checker when available.
- Check the selected deployment adapter's official guide for runtime, environment, cookie, image, streaming, and edge limitations.

When Astro documentation delegates behavior to React, Tailwind CSS, Supabase, or a hosting provider, consult that project's official documentation as well.