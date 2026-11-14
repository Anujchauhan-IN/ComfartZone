# ComfartZone — Agent Working Agreement

## Source of truth
Read only the documents relevant to the task:
1. `docs/product-spec.md` — product behavior and privacy rules.
2. `docs/architecture.md` — proposed technical boundaries and security.
3. `docs/test-plan.md` — acceptance and adversarial tests.
4. `design.md`, `references/Reference.png`, `references/Reference1.png` — approved visual identity.
5. `README.md` and `roadmap.md` — project context and current progress.

**Important:** Architecture and test documents are planning drafts, not authorization to implement. Explicitly flag unresolved product decisions and inconsistencies. Do not silently invent rules or change approved behavior.

## Working rules
- Work in small, narrowly scoped tasks; inspect only relevant files. Avoid broad audits, unrelated refactors, needless dependencies and repeated builds.
- **Do not create or apply migrations, deploy, change production resources or start backend integration without explicit approval.** Design first, review before SQL.
- Preserve existing working features and accessibility. Do not claim visual or browser testing without actually performing it.
- Maintain >=80% qualitative visual fidelity to approved references as a release acceptance target, verified with actual screenshots and human review.
- Respect privacy boundaries, server-enforced verification, anonymous ownership and anti-spam constraints.
- Never fabricate real users, posts, activity or engagement.
- At the end of **every task**, provide: concise changes, files modified, tests actually run, remaining issues, and **one descriptive Conventional Commit message**. Do **not** automatically commit or push.
- Treat `.agents/skills/frontend-design/SKILL.md` and `.agents/skills/web-design-guidelines/SKILL.md` as optional guidance if present and readable. Project specs and reference images take precedence.
