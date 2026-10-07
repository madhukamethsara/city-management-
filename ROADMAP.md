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

Persistent project feedback is implemented, with server authorship, authority isolation
and retry IDs. Officers can upload public JPG/PNG/WebP images and PDF documents,
up to 10 MB each, alongside authority-provided HTTPS document links. Uploads use
immutable objects in the public project bucket; report evidence remains private.
Storage HTTP uploads and native file-picking verification are pending staging/devices.

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

1. Proposals and consultations: persistent proposals, support/follow preferences,
   comments, officer review and consultation publication are implemented locally.
   Text and choice answers persist privately with one response per person.
   Live staging verification, proposal attachments, project conversion and
   aggregate consultation results remain follow-up work. The officer editor
   publishes mixed written-answer and single-choice questions with validated options.
   Participation lists/comments currently load in full; server pagination remains work.
2. Administration follow-up: private audit history with cursor pagination and
   server-side analytics across all project pages are implemented locally.
   Authority transfers and department lifecycle staging verification remain.
   Existing department edits and authority-scoped role/activity management now
   persist through permission-checked RPCs. Resolution metrics use case history.
   Department creation/removal is implemented locally with authority-admin permissions,
   creation retries, duplicate-name checks and protection for referenced departments.
   Apply the department lifecycle migration after officer management in staging and
   verify create -> edit -> reload -> remove across real administrator sessions.

Deliver and test each module end to end before exposing it in connected mode.

Apply the four 20261006 migrations in filename order after department lifecycle.
Connected screens require these migrations; they do not fall back to demo data.
Then apply `202610070001_notification_refresh.sql` for notification refresh.
The notification screen fetches on opening and provides pull-to-refresh, a
refresh button and retry without reloading other civic data. Late responses are
discarded after account changes; confirmed read state survives a stale snapshot.
Analytics represents the latest bootstrap/refresh snapshot. Audit history starts
when its migration is applied and excludes contact details, answer text, private
notes, evidence and budget amounts. Historical audit events are not backfilled.

## Usability and release readiness

- Replace demo ward/division options with authority-managed reference data.
- Complete Sinhala/Tamil translations; language preference currently persists
  but does not translate every screen.
- Audit every remaining screen at narrow widths, enlarged text, landscape,
  keyboard-open layouts, keyboard navigation and screen-reader use.
- Add paginated data access, offline draft recovery and notification realtime
  behavior without losing local edits. Manual notification refresh is implemented;
  live staging verification remains pending.
- Add upload retention cleanup, API abuse controls, observability, backup
  restore testing and separate staging/production release configuration.
- Android and web demo release builds pass locally. Validate iOS on macOS/Xcode,
  connected production builds, release signing, privacy disclosures,
  operational ownership, deployment rollback and user support.

No production deployment is implied by completion of the local implementation.
