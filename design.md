# ComfartZone — Visual Design and Interaction System

**Status:** Approved direction expressed as an implementation specification.  
**Companion:** `README.md` defines behavior, data, security and release gates.  
**Design goal:** Cozy, sharp, slightly ridiculous, and unmistakably a real community—not a generic SaaS template or a childish game.

## 1. Art direction

Blend two qualities: (1) warm, expressive, slightly cartoonish personality and (2) clean, dense, readable social-feed utility. The result should be playful but disciplined. Posts—not illustrations—are the main attraction.

**Visual adjectives:** warm, witty, compact, friendly, mischievous, tactile, readable.  
**Avoid:** glassmorphism, neon, gradient-heavy hero blocks, excessive whitespace, corporate stock illustrations, giant typography, fake activity metrics, overly rounded pill-everything design, and an AI-generated dashboard appearance.

### Brand character

A small grumpy potato-like mascot, with simple dark outlines, tiny expressive eyes, and flexible irritated/amused expressions. Use it in empty states, success/error moments, 404, and rare accents—not every card. Prefer an original lightweight SVG illustration; do not use copyrighted characters or downloaded stock mascots. Mascot is optional decoration, never a replacement for accessible labels.

### Voice and copy

- Default: brief, conversational, dryly funny, human.
- Functional controls: explicit and clear (`Report`, `Delete`, `Cancel`, `Sort`, `Reply`).
- Homepage prompt: **“What ruined your day today?”**
- Post action: **“Spill it”**
- Avoid generic lines such as “Welcome to your safe space” and forced references to hustle, productivity or laziness.
- Humor belongs in prompts, empty states and occasional feedback—not every button or error.
- Error text always explains what happened and what to do next. Never mock a user reporting harm.

## 2. Design tokens

Initial values; implement as CSS variables and use consistently. Minor refinements allowed after visual testing, but avoid arbitrary per-component colors.

| Token | Light | Dark (if implemented) | Purpose |
|---|---|---|---|
| `--bg` | `#FAF7F2` | `#1F1C1A` | Page background |
| `--surface` | `#FFFFFF` | `#2B2623` | Cards/dialogs |
| `--surface-muted` | `#F5EFE9` | `#352F2B` | Secondary panels |
| `--text` | `#302A28` | `#F6F0EA` | Main copy |
| `--text-muted` | `#756D68` | `#BFB4AC` | Metadata |
| `--accent` | `#EF7868` | `#F18B7B` | Primary actions |
| `--accent-hover` | `#DE6556` | `#F49A8D` | Hover/active |
| `--accent-soft` | `#FFF0E8` | `#49312D` | Selected backgrounds |
| `--border` | `#E9E2DB` | `#4C433D` | Dividers |
| `--focus` | `#9B4539` | `#FFB2A5` | Focus indicator |
| `--danger` | `#B64242` | `#FF8F8F` | Destructive action |

**Contrast:** check all combinations against WCAG AA. Do not use coral for small body text on white without sufficient contrast. Accent is primarily for filled controls, icons and highlights; main reading text remains dark.

### Shape and spacing

- Spacing scale: 4, 8, 12, 16, 20, 24, 32 px. Prefer 12–16 px within cards; 8–12 px between compact elements.
- Card radius: 14–16 px; dialog radius: 18–20 px; input radius: 10–12 px; pill tags fully rounded where useful.
- Border: 1 px subtle warm gray; shadows minimal and reserved for floating surfaces.
- Buttons: ~40–44 px high for primary controls; touch targets at least 44×44 px where practical.
- Content text: 15–16 px, line height 1.45–1.6; metadata 12–13 px; headings compact and clear.
- Avoid large 48–72 px decorative headings on feed pages.

### Typography

Prefer a legible system sans stack initially (`system-ui`, `-apple-system`, `Segoe UI`, `Roboto`, sans-serif). Optional brand display face only if lightweight and visibly improves identity. Body must render Unicode reliably. Limit font weights and avoid excessive font downloads.

### Iconography

Lucide outline icons with consistent stroke (~1.8–2 px), typically 18–20 px. Icons need accessible labels when standalone. Do not use emoji as the only way to identify a control. Emojis may appear in type labels or expressive microcopy sparingly.

## 3. Responsive shell

### Mobile: 320–767 px

- Top bar 52–60 px: compact wordmark/logo, optional actions, no huge hero.
- Main feed width 100%, with 12–16 px horizontal gutter.
- Composer at top of feed: one-line prompt card and visible `Spill it` action.
- Horizontal post-type filter strip if necessary, with visible selected state and scroll affordance; avoid hidden navigation traps.
- Topic and sort controls compact, accessible, not stacked into a tall toolbar.
- Bottom nav fixed/sticky: Home, Confessions, Petty Court, Am I Weird?, Hot Takes. Labels must remain readable on narrow screens; if five items are cramped, use compact icons + short labels or a clearly labeled More navigation without hiding core destinations.
- Add bottom safe-area padding so last content and floating actions are not obscured.
- Composer modal becomes full-height sheet on narrow screens, accounting for keyboard and viewport changes.

### Tablet: 768–1023 px

- Feed centered at ~620–700 px max; navigation may be top or compact left rail depending on available width.
- Avoid a large empty right column merely for symmetry.

### Desktop: 1024+ px

- Max page shell ~1240 px centered.
- Left navigation ~200–240 px, central feed ~580–680 px, optional right rail ~240–280 px only if useful.
- Right rail may contain compact community rules, type explanations or topic shortcuts; **never** fabricate trending statistics or active user counts.
- Sticky left navigation; central content remains primary. At medium desktop widths, omit right rail before shrinking feed below comfortable reading width.

### Breakpoints

Test at 320, 360, 390, 430, 768, 1024 and 1440 px. Design for fluid behavior, not only these exact widths. No horizontal overflow, clipped text or unreachable controls.

## 4. Page-by-page specification

### A. Home (`/`)

**Visual hierarchy:** compact header → composer → filters/sort → post feed. No marketing hero. Show actual posts, not fabricated examples in production.

- Header: recognizable ComfartZone wordmark and small mascot mark; optional settings/about link.
- Composer: text “What ruined your day today?” with `Spill it` button. Tap opens composer.
- Type tabs: All, Confessions, Petty Court, Am I Weird?, Hot Takes; on dedicated routes, current type selected.
- Topic selector: optional topic filter; default All topics.
- Sort: Fresh (default), Popular, Controversial. Controversial eligibility follows README ranking rules.
- Feed: 20 initial posts, server-rendered, pagination/incremental load with stable cursor. Avoid infinite spinner with no recovery.
- Empty feed: potato mascot, brief witty message, clear `Spill it` action. No false claims about community size.

### B. Post card (shared)

Structure:
1. Top row: colored but subtle type chip, optional topic chip, relative time, overflow menu.
2. Body: full text with comfortable line height; preserve user line breaks safely. For exceptionally long feed posts, show a controlled preview with `Read more` linking to post page.
3. Interaction row: poll choices **or** confession reactions, comments count/link, share control.
4. Optional compact vote result bars only on poll posts, never giant charts.

**No public usernames or avatars**. Do not expose internal author IDs. Author-owned controls appear only when viewer has the matching authenticated session. Use consistent separators and 12–16 px card padding.

#### Type styling

- Confessions: coral or warm blush accent; reactions `Same`, `Ouch`, `Wild`.
- Petty Court: muted amber accent; `Guilty` / `Not Guilty`.
- Am I Weird?: soft lavender accent; `Me Too` / `Just You`.
- Hot Takes: muted teal accent; `Agree` / `Disagree`.

Type accents must not reduce contrast or make the page look like four unrelated products. Keep one card anatomy.

#### Poll result UI

Two clearly labeled buttons; selected state visible via fill/border/icon and `aria-pressed`. After voting, show each choice's percentage and total votes. Ensure rounding totals 100%. Use text plus subtle bars; color must not be the sole signal. If no votes, show `No votes yet` rather than fake 50/50 results. Voting failure reverts optimistic state and displays retry guidance.

### C. Post detail (`/post/[id]`)

- Back to feed navigation that works with browser history and direct links.
- Full post, vote/reaction controls, share/report actions, comments.
- Comments list with pagination, sorting and one reply level. Visually indent replies modestly; do not squeeze content on mobile.
- If deleted/hidden: show a neutral, informative unavailable state, not the original text.
- If locked: reading remains available if published, but composer/vote actions are disabled with explanation.

### D. Composer

- Full-height mobile sheet or centered desktop dialog (~520–620 px width).
- Heading: `Spill it` or `New post`.
- Post-type selector: four compact selectable cards or tabs with one-sentence explanations.
- Topic selector: optional single choice.
- Large plain-text textarea; no rich text toolbar; visible character counter `0 / 1000`.
- Inline validation; submit disabled while invalid/submitting.
- Buttons: `Cancel` and `Post` (or `Spill it`, consistently).
- Preserve text on recoverable errors and when switching type. Confirm before discarding a non-empty draft.
- On success: close, show toast/inline confirmation and navigate to the new post or prepend authoritative server result.

### E. Comments

- Input with `Write a comment…` placeholder, character count and submit.
- Each comment: body, relative time, Reply, Report, Delete if owner.
- One reply depth; nested replies appear under root, not recursive tree.
- Loading state per submission; no duplicate comments on rapid taps.
- Deleted root with live replies: minimal `Comment deleted` placeholder; otherwise remove from public view as appropriate.
- Empty: `No comments yet.` plus a subtle invitation to reply.

### F. Report dialog

- Neutral, respectful tone; no sarcasm when dealing with harassment or threats.
- Select one reason, optional details, Cancel/Submit.
- Confirmation without revealing internal moderator workflow.
- Prevent repeated submission and show understandable errors.

### G. Settings

- Explain anonymous browser-specific session and loss of ownership if cleared.
- Preferences such as reduced motion or theme only if implemented.
- Avoid misleading `Delete account` UI unless actual deletion and data-handling workflow exists.
- No conventional public profile, follower counts, badges or direct messages.

### H. Moderator dashboard

- Functional, restrained design distinct from playful public pages.
- Protected login, report queue with filters, target preview, report reason, actions, confirmation, audit history.
- Never expose private reports in public UI or index moderator routes.
- Keyboard-friendly tables/cards and mobile-safe controls.

### I. Rules / About / Privacy / Terms

- Readable narrow text column, clear headings, no wall of marketing copy.
- Privacy and terms must match actual implementation, especially anonymous sessions, logging, moderation, retention and reporting.
- No invented legal assurances.

### J. Error and system states

- 404: grumpy potato, concise playful message, Home action.
- 500/network failure: clear issue, Retry where possible.
- Empty feed: clear posting CTA.
- No comments: neutral message.
- No votes: no fabricated percentages.
- Deleted/hidden post: unavailable notice.
- Session expired: explain that prior ownership may be lost; avoid silently creating a replacement identity before informing user if it would cause confusion.
- Rate limit: clear wait/retry instruction, never shame user.
- Loading: restrained skeletons with stable dimensions; no endless blocking animation.

## 5. Interaction and motion rules

- Hover/focus/pressed/disabled/loading states for every actionable control.
- Primary buttons coral with readable foreground; destructive actions red and require confirmation where irreversible.
- Dialogs trap focus, close via Escape where safe, restore focus to trigger, and have visible titles.
- Toasts are brief, non-blocking, screen-reader announced; important errors also appear inline.
- Transitions ~120–200 ms for simple feedback, no gratuitous entrance animations. Respect `prefers-reduced-motion`.
- Voting feedback may animate bars subtly but must not delay authoritative updates.
- Avoid scroll jumps when loading next page, posting comments or switching filters.
- Show visible keyboard focus and avoid icon-only mystery controls.

## 6. Content and editorial presentation

- Use realistic, short, funny seed fixtures **only in development** and mark them as fixtures in code. Do not deploy fake posts or fake votes as real community activity.
- Humor examples must be varied and not dominated by productivity/laziness jokes.
- Do not write long explanatory subtitles on every page. The post type labels and buttons should be self-explanatory.
- Do not use AI-generated filler copy or random humorous phrases in security, moderation or privacy flows.
- No public author name/avatar; no public user leaderboard, karma, streaks, follower metrics or online counts.

## 7. Accessibility contract

- WCAG AA contrast target; test coral/white combinations, muted metadata, type chips and dark mode if present.
- Keyboard access for tabs, dialogs, voting, menus and comments.
- Screen-reader labels for icon buttons; selected tabs use appropriate roles/`aria-selected`; vote buttons announce choice and result.
- Minimum usable touch target 44×44 px where practical.
- Visible form labels, error descriptions, focus management and status announcements.
- Never use color or emoji as the only indicator of post type, vote selection or validation.
- Handle long unbroken strings, Unicode, zoom up to 200%, and OS font scaling without overflow.

## 8. Performance and asset rules

- Prefer CSS shapes, SVG icons and a single original SVG mascot; no large decorative images.
- No autoplay video, audio, parallax or heavy animation libraries.
- Use responsive SSR and selectively hydrate React islands; do not turn the whole page into a client-only React app.
- Avoid layout shift from fonts, result bars, loading skeletons or sticky navigation.
- Optimize for modest Android devices and slower mobile connections.

## 9. Component inventory

Core reusable components to implement as needed:

- `SiteHeader`, `DesktopSidebar`, `MobileBottomNav`, `RightRail` (optional)
- `ComposerPrompt`, `PostComposer`, `PostTypeSelector`, `TopicSelector`
- `FeedToolbar`, `PostFeed`, `PostCard`, `PostTypeBadge`, `TopicBadge`
- `BinaryVote`, `VoteResults`, `ConfessionReactions`, `PostActions`
- `CommentList`, `CommentItem`, `CommentComposer`, `ReplyThread`
- `ReportDialog`, `ConfirmDialog`, `Toast`, `LoadingSkeleton`
- `EmptyState`, `ErrorState`, `MascotIllustration`
- `ModeratorReportQueue`, `ModeratorActionDialog`

Reuse a single post-card design and shared interaction primitives. Do not create four incompatible card implementations.

## 10. Design quality gates

- [ ] Homepage shows real feed immediately; no marketing hero.
- [ ] UI has a consistent warm visual identity and compact feed density.
- [ ] All four types are recognizable but share one component system.
- [ ] Composer and bottom navigation work on narrow Android screens with keyboard open.
- [ ] Desktop layout uses space intelligently; optional right rail is genuinely useful.
- [ ] No horizontal overflow at target widths or enlarged text.
- [ ] No decorative control that appears clickable but does nothing.
- [ ] All interaction states are designed and implemented.
- [ ] Contrast, focus, touch size and screen-reader behavior are checked.
- [ ] Mascot is occasional, original, lightweight and non-obstructive.
- [ ] Humor feels natural and never interferes with moderation or error clarity.
- [ ] Production has no fake posts, votes, comments or engagement metrics.

## 11. Instructions for Codex

Read this file together with `README.md` before building UI. Do not replace these decisions with generic template styling. First implement design tokens and the responsive shell, then review mobile and desktop screenshots before expanding components. Keep implementation phase-specific; document visual changes when they materially depart from this specification. If an important visual or interaction decision is ambiguous, raise it explicitly rather than inventing a new product direction.
