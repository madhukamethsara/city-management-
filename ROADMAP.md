# Smart Sabha development roadmap

Target platforms: Android, iOS, and responsive web.
Delivery order: complete one real workflow, then reuse its foundations.

## First delivery — implemented locally

- [x] Supabase adapter for profiles, reports, comments and notifications.
- [x] Database migration with authority/owner checks and private internal notes.
- [x] Private evidence uploads and expiring preview links.
- [x] Server-issued case numbers, transactional notifications, retry IDs and revisions.
- [x] Persistent onboarding, officer roles, and session data isolation.
- [x] Responsive shared headers, labelled navigation, mobile officer case cards.
- [x] Flutter workflow/layout tests and executable PostgreSQL permission tests.
- [ ] Apply migration and provision actual authority data in staging.
- [ ] Verify real Auth callbacks, Storage uploads, and multi-device sessions.
- [ ] Validate iOS on macOS/Xcode and perform device/browser accessibility checks.

See BACKEND_SETUP.md for deployment prerequisites and commands.

## Projects delivery - implemented locally

- [x] Authority-owned projects with server-authorised officer creation and editing.
- [x] Persisted milestones, dates, location, progress, contractor and budget figures.
- [x] Private budgets and internal updates removed from resident responses.
- [x] Public documents stored as HTTPS links; residents can copy links to open in a browser.
- [x] Per-person subscriptions and transactional public-update notifications.
- [x] Search, status filters, sorting and 25-item server pagination for resident/officer listings.
- [x] Stable creation retry IDs, revision conflicts and session-isolated reads/writes.
- [x] Database permission/workflow tests and Flutter contract/layout tests in CI.
- [ ] Apply the projects migration after the report migration in staging.
- [ ] Verify officer creation -> resident follow -> officer update -> notification across real sessions.

Project image uploads and persistent project feedback are still deferred; these demo
controls are hidden in connected mode. Document binary uploads are also deferred;
this delivery supports authority-provided public HTTPS document links.

## Announcements and feed delivery - implemented locally

- [x] Authority-owned drafts, publication and unpublication with officer-only writes.
- [x] Server-enforced ward and GN division targeting; both supplied targets must match.
- [x] Persistent comment text, per-person reactions and saves, and a saved-updates filter.
- [x] Transactional recipient-scoped publication notifications and delivery deduplication.
- [x] Stable creation/comment retry IDs, revision conflicts and session isolation.
- [x] Paginated notices, refresh controls, and independently loaded notification deep links.
- [x] PostgreSQL permission/workflow tests and Flutter contract/layout tests in CI.
- [ ] Apply the announcements migration after reports and projects in staging.
- [ ] Verify draft -> targeted publication -> resident comment/save across real sessions.

The connected feed currently contains published announcements. Targets use exact
profile ward/division names until authority-managed reference data is available.
The feed displays the latest 50 comments per notice. Scheduling, moderation,
project-update feed entries and older-comment browsing remain follow-up work.

## Next - complete remaining civic services

1. Proposals and consultations: persistent text answers and comments, one
   participation per person, review workflow and supported attachments.
2. Administration: audited, server-authorised user/role changes, authority
   transfers, departments and aggregate metrics computed from actual data.

Deliver and test each module end to end before exposing it in connected mode.

## Usability and release readiness

- Replace demo ward/division options with authority-managed reference data.
- Complete Sinhala/Tamil translations; language preference currently persists
  but does not translate every screen.
- Audit every remaining screen at narrow widths, enlarged text, landscape,
  keyboard-open layouts, keyboard navigation and screen-reader use.
- Add paginated data access, offline draft recovery and notification refresh/
  realtime behavior without losing local edits.
- Add upload retention cleanup, API abuse controls, observability, backup
  restore testing and separate staging/production release configuration.
- Validate Android, iOS and web release builds, signing, privacy disclosures,
  operational ownership, deployment rollback and user support.

No production deployment is implied by completion of the local implementation.
