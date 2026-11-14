# ComfartZone implementation roadmap

## Phase 1A — Foundation

- [x] Add Astro project configuration with strict TypeScript.
- [x] Register React and Tailwind CSS v4 integrations.
- [x] Add design tokens and responsive application shell.
- [x] Add minimal semantic homepage without fabricated content or dead controls.
- [x] Add environment and ignore templates.
- [x] Install dependencies in the project environment.
- [x] Verify type checks and production build.
- [x] Verify the development server starts and serves the homepage.

## Phase 1B — Homepage and unified feed UI

- [x] Replace the foundation state with the responsive community homepage.
- [x] Add desktop and mobile post-type navigation.
- [x] Add a unified feed for all four post types using isolated development fixtures.
- [x] Add reusable post cards with local-only poll and reaction controls.
- [x] Add functional type, topic and sort filters with shareable query state.
- [x] Add a clearly labelled non-persistent composer entry point.
- [x] Add loading, empty and error-state components.
- [x] Verify type checks, production build and homepage response.

## Phase 1C — Post creation and post detail UI

- [x] Add an accessible local-only composer with type, topic and content validation.
- [x] Add local post previews without implying persistence.
- [x] Add static fixture-backed post detail routes for all mock posts.
- [x] Reuse interactive voting and reaction controls on feed and detail views.
- [x] Add local-only comments, one-level replies and deletion of local entries.
- [x] Link feed cards and comment counts to canonical prototype detail routes.
- [x] Add detail navigation, copy-link feedback and prototype limitations.
- [x] Verify type checks, production build, homepage and representative detail routes.

## Phase 1D — Visual design refinement

- [x] Compare the existing interface against both approved reference images.
- [x] Refine mobile and desktop shells with compact navigation and balanced rails.
- [x] Strengthen the ComfartZone wordmark, CZ details and existing mascot treatment.
- [x] Restyle the composer, filters, feed cards, interactions and prototype states.
- [x] Apply consistent visual hierarchy to post details and comments.
- [x] Preserve Phase 1B and 1C filtering, posting, voting and comment behavior.
- [x] Verify type checks, production build and representative routes.
- [x] Remove duplicate mobile/tablet type navigation and compact the mobile feed header.
- [x] Synchronize query state, navigation, direct URLs and browser history in static output.
- [x] Consolidate development notices while preserving local-only interaction clarity.
- [x] Refine compact cards and the keyboard-safe composer sheet.
- [ ] Complete screenshot-based browser review at 360, 390, 768 and 1440 px on a browser-capable environment.

## Next phases

Follow the phase gates in `README.md`. No later-phase feature should be represented as complete until its implementation and verification are recorded here.
