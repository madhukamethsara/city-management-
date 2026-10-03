# Connected reports, projects, announcements and feed

Supabase mode now uses persistent civic data as well as authentication.
Apply all three migrations in order before launching a configured app. Existing auth-only
deployments must complete this setup; there is no automatic demo-data fallback.

## Configure a staging project

1. Follow AUTH_SETUP.md to configure email sign-in, reset callbacks, and the
   Android/iOS URL schemes.
2. Run `supabase/migrations/202609290001_report_workflow.sql` in the Supabase SQL
   editor, as the database administrator. Apply it once. It creates the private
   civic schema, public RPCs, and the private `report-evidence` bucket. Then apply
   `supabase/migrations/202609300001_project_workflow.sql` once to add projects,
   subscriptions, project RPCs and recipient-scoped project notifications. Finally,
   apply `supabase/migrations/202610020001_announcement_workflow.sql` once for
   targeted announcements, feed participation and publication notifications.
3. Insert the local authorities and departments that the service actually
   supports. The fixture below is for staging only:

```sql
insert into civic_private.authorities(id, data) values (
  'staging-authority',
  '{"name":"Example Local Authority","type":"Council","district":"Example district","province":"Example province","center":{"latitude":7.4864,"longitude":80.3642}}'
);
insert into civic_private.departments(id, authority_id, data) values (
  'staging-roads', 'staging-authority',
  '{"name":"Roads","headName":"","categories":["Road Damage","Street Light","Drainage"],"officerCount":0}'
);
```

4. Register two staging accounts and complete onboarding for both in the same
   authority. The first remains a resident. Promote only the intended officer
   using their verified Auth user UUID:

```sql
update civic_private.profiles
set role = 'officer'
where id = '<verified-officer-auth-uuid>'::uuid
  and authority_id = 'staging-authority';
```

5. Sign out and sign in again as the officer. Privileged roles come from the
   database, never editable Auth user metadata. Authority transfers, role
   changes, and account deactivation are administrator SQL operations in this
   release, not client-side profile changes.
6. Start the app with public project credentials:

```sh
flutter run -d chrome --dart-define=AUTH_MODE=supabase --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY
```

Use the same defines for Android/iOS builds. Never put a service-role key in the
app. Use `--dart-define=AUTH_MODE=demo` for the full in-memory demonstration.

## What is connected

- Officer landing workspace with open, assigned-to-me, unassigned and urgent
  open-case counts, recent case links and shortcuts to complaints, projects and
  notices. Desktop uses a navigation rail; phones use bottom navigation.
- Complaint assignment and urgency filters combine with search, status and
  department filters. Cases sort by latest update. Assignment matching currently
  uses the stored officer display name; unique officer IDs remain follow-up work.

- Profile onboarding and restoration across app restarts.
- Resident report creation, case tracking, comments, follow preference, and
  confirmation/reopening of resolved cases.
- Authority-scoped officer review, assignment, status, priority, public history,
  private notes, and completion evidence.
- Server-generated case numbers and recipient-specific in-app notifications;
  read/unread state persists.
- Private JPG/PNG/WebP uploads, limited to 5 MB each. Residents may select up to
  five initial photos; a report can contain up to ten evidence files. Preview
  links expire after 60 seconds. Close and reopen a preview to renew its link.
- Explicit refresh buttons fetch updates from other users/devices.

Reports are visible only to their owner and officers in the same authority.
Nearby duplicate suggestions therefore use only reports the caller may read.
Comments are shared with those same participants; they are not a public feed.
All officer roles, including platformAdmin, remain scoped to one authority here.
The officer directory exposes only names, IDs, roles, activity and authority to
other officers; personal contact/location fields are not included.

### Projects

- Officers manage projects within their own authority, including location, dates,
  milestones/completion, progress, contractor, allocated budget and expenditure.
- Residents browse projects in their profile authority. Search, status and sort
  apply on the server before returning each page of 25 projects.
- Budget figures marked private and internal updates never appear in resident RPC
  responses. All active officer roles can manage their own authority's projects.
- Public documents are HTTPS links supplied by the authority. Tapping a document
  copies its link for opening in a browser. Binary document uploads, project image
  uploads and persistent project feedback are deferred; local-only controls are
  hidden in connected mode.
- Following is idempotent and scoped to the signed-in user. Subscriber identities
  are never exposed to other users. Public update, status and progress changes
  create notifications for active followers in the same authority; private-only
  updates do not notify residents.
- Creation retries retain the same form ID and payload. Edits use revisions;
  after a conflict, close the editor, refresh the listing and reopen the project.
- Project lists and details have explicit refresh controls. Pagination reflects
  current records; refresh from the first page after concurrent additions/edits.

### Announcements and public feed

- Officers draft, publish, edit and unpublish notices within their own authority.
  Residents receive only published notices matching their profile ward and GN
  division. Both supplied targets must match exactly; blank fields include all
  wards/divisions. The audience label is generated from these targeting fields.
- Publication creates notifications for active, onboarded recipients in the
  matching area. A delivery ledger prevents repeats after retries or republication.
  Unpublishing or narrowing the audience removes obsolete notice notifications.
- Published notices form the connected feed. Reactions and saves belong to the
  authenticated caller; other users' preference identities are private. Comments
  retain their text and server-established authorship. The latest 50 comments
  appear in each notice's feed discussion.
- Lists load 25 records at a time. Refresh fetches other devices' changes; load
  more retrieves additional notices. Filters apply to loaded records. Notification
  links fetch the requested notice independently of the list cache.
- Creation and comment retries use stable IDs. Officer edits use revisions; after
  a conflict, close the form, refresh and reopen it. Scheduling, moderation,
  older-comment browsing and project-update feed entries remain follow-up work.

Proposals, consultations, broader user/department administration and aggregate
analytics remain demo features. Unsupported routes show service availability,
and unsupported writes fail explicitly.

## Consistency and security

- Application tables are in the unexposed `civic_private` schema, have RLS
  enabled, and grant no direct access to anon/authenticated roles.
- Each RPC uses an explicit empty search path, checks the authenticated user
  and current database permissions, and commits related records transactionally.
- Report creation uses a stable request ID for retries within the form.
  Repeating the same request after a lost response returns the existing case.
- Updates use revisions. A conflict asks the user to refresh and review rather
  than overwriting another person's changes.
- Only the server can create notifications, establish comment identity, or
  generate case numbers. Residents never receive internal notes.
- Uploaded files are immutable through client APIs. An upload whose report save
  fails may remain unattached. Before public rollout, schedule server-side
  cleanup of old objects that are not referenced by any report; do not delete
  objects immediately after a timeout because the report transaction may have
  succeeded.

The adapter follows Supabase's [database function guidance](https://supabase.com/docs/guides/database/functions)
and [row-level security guidance](https://supabase.com/docs/guides/database/postgres/row-level-security).

## Verification

```sh
flutter analyze --no-pub --fatal-infos
flutter test --no-pub
npm install --prefix .dart_tool/sql-validation --no-audit --no-fund --ignore-scripts @electric-sql/pglite@0.5.8
node tool/test_report_backend.mjs
node tool/test_project_backend.mjs
node tool/test_announcement_backend.mjs
```

The SQL test executes the actual migration against ephemeral PostgreSQL with
minimal Auth/Storage contracts. It covers tenant isolation, resident privacy,
privilege escalation, notification isolation, rollback, conflict detection,
retry idempotency, comments, reopening, evidence policies and inactive users.
Project checks additionally cover private budgets/updates, authority ownership,
subscriptions, transactional notifications, revision conflicts, creation retries,
validation and searchable pagination. Announcement checks cover drafts, ward/division
visibility, publication notifications, idempotent comments/reactions/saves, revision
conflicts, pagination and inactive accounts. These checks do not replace testing
Supabase JWT validation, Storage HTTP uploads, or
email callbacks against staging.

Before deployment, complete a real resident → officer → resident cycle in
separate browser sessions and on Android and iOS. Confirm that comments,
evidence, notifications and profile details survive restart. Check keyboard
navigation, screen readers, slow networks and failure/retry behavior.
For projects, create a project as the officer with a private budget and internal
update, then sign in as the resident in a separate session. Verify those private
fields are absent, follow the project, and post a public update as the officer.
Refresh resident notifications and open the project. Unfollow, change progress,
and confirm no new notification arrives. Check document links, a second authority,
more than 25 projects, and a stale editor in a second officer session.
For announcements, create an unpublished notice as an officer, then confirm that
residents cannot list it or open its URL. Publish for a single ward and GN division;
verify that only matching residents receive it and its notification. Comment,
react and save as a resident, restart, and verify persistence. Test a second ward,
a second authority, unpublication, retry after a lost response and concurrent edits.
iOS compilation and device validation require macOS/Xcode.

## Release limits

Reports, projects, announcements and feed participation are connected locally;
this is not the complete civic platform. Reference
data and officer assignments must be provisioned by an administrator. Updates
are fetched manually; push/realtime subscriptions, offline drafts, pagination for other modules,
rate limits, production monitoring, backup recovery drills and retention/
cleanup automation remain release work tracked in ROADMAP.md.
