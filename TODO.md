# Smart Sabha implementation checklist

Demo mode uses seeded, in-memory data. Reports, profiles, projects and announcements have local
Supabase implementations; staging/device verification is still pending. Screen
presence is not production completion. See ROADMAP.md for current delivery status.

## 1. Foundation
- [x] Inspect the app and document implementation gaps.
- [x] Show loading, safe startup errors, and retry without restarting.
- [x] Separate repository contracts from demo data and add report mutation contracts.
- [x] Move existing profile, project, community, and notification controller writes behind repository contracts.
- [x] Add formatting, analysis, and test checks in CI.

## 2. Authentication and permissions
- [x] Implement configurable Supabase login, registration, recovery, and session restoration.
- [ ] Configure a Supabase project and verify live email delivery, callbacks, and session restoration (see AUTH_SETUP.md).
- [x] Enforce active-account and role permissions for connected reports/projects.
- [x] Persist profiles and onboarding details.
- [ ] Distinguish officer, department-admin, and platform-admin permissions.

## 3. Persistent core request workflow
- [x] Define database tables with local-authority ownership.
- [x] Implement backend repository and authority-scoped access policies.
- [x] Persist report submission, assignment, updates, and resident confirmation.
- [x] Upload actual report attachment bytes with appropriate access permissions.
- [x] Deliver notifications to their intended users and persist read state.
- [ ] Verify citizen submission -> officer update -> resident notification across sessions.

## 4. Remaining civic features
- [x] Persist projects, milestones, budgets, public document links, and following.
- [ ] Verify projects against staging; add binary document/image uploads and persistent project feedback.
- [x] Persist announcements, geographic targeting, publication and recipient notifications.
- [x] Persist announcement-feed comments, reactions and saves.
- [ ] Verify targeted announcement publication and feed participation against staging.
- [ ] Persist proposals, comments, reactions, and consultation answers.
- [ ] Replace placeholder analytics with calculated data.
- [ ] Complete Sinhala, Tamil, and English translations and accessibility checks.

## 5. Release readiness
- [ ] Handle validation and network failures for all data operations.
- [ ] Test access isolation, core workflows, and supported devices.
- [ ] Configure production environments, monitoring, backups, and release builds.
- [ ] Confirm whether payments, permits, or bookings belong in a later release.

Backend connection requires a selected provider and project configuration.
Never commit service credentials or bundle privileged keys in the Flutter app.
