# ComfartZone architecture

## Phase 0 foundation

ComfartZone uses Astro with strict TypeScript as the server-rendered application shell. React is registered for future interactive islands only; Phase 0 does not hydrate any client-side component. Tailwind CSS v4 is connected through its first-party Vite plugin and a single global stylesheet.

## Boundaries

- `src/pages`: route entry points and page composition.
- `src/layouts`: document structure, metadata and global style loading.
- `src/components`: reusable presentation grouped by feature or shell responsibility.
- `src/styles`: global design tokens, Tailwind theme mapping and foundational styles.
- `src/lib`: framework-agnostic constants and utilities.
- `public`: static files copied without transformation.

Future data access, validation, authentication and authorization belong in explicit server-only modules. They are intentionally absent from Phase 0.

## Rendering approach

Public pages will be server-rendered by Astro. React components should become islands only when interaction requires browser state. Static Astro components remain the default to minimize JavaScript.

## Styling approach

The approved values from `design.md` are CSS custom properties in `src/styles/global.css`. Tailwind theme variables reference those tokens so components can use utilities without duplicating brand values. Component-specific styles should stay local unless they are genuine shared primitives.

## Current limitations

Phase 0 contains no database, persisted feed, authentication, voting, comments, reporting or moderation. Deployment adapter selection is deferred until the hosting/runtime environment is verified.
