# Smart Sabha

Smart Sabha is a Flutter civic engagement app for Sri Lankan Pradeshiya Sabhas, Urban Councils and Municipal Councils. Residents can report local issues, track cases, follow public projects and participate in local announcements. Officers and administrators manage civic services through a role-aware console.

The project targets Android, iOS and responsive web. It includes a full in-memory demo and a Supabase implementation for the core workflows. Live staging, device and production release verification remain pending; see [the roadmap](ROADMAP.md).

## Features and delivery status

| Area | Supabase mode |
| --- | --- |
| Authentication and profiles | Email/password sign-in, registration, recovery, persistent onboarding and database-assigned roles |
| Issue reports | Case numbers, private evidence uploads, comments, assignment, status history, internal notes and resident resolution confirmation |
| Projects | Officer creation/editing, milestones, progress, budgets with resident privacy, public HTTPS document links, subscriptions and paginated search |
| Announcements and feed | Drafts, publication, ward/GN division targeting, recipient notifications, comments, reactions and saved updates |
| Departments | Persistent edits; authority administrators can create departments and remove unused departments |
| Account management | Authority-scoped role and active-state management with server permission checks |
| Notifications | Recipient-specific in-app notifications and persistent read state |
| Proposals and consultations | Demo only; connected workflows remain on the roadmap |

The interface includes an OpenStreetMap explorer, responsive navigation and officer case-management views. Project image uploads, binary document uploads and persistent project feedback remain deferred. Analytics uses available case data; server-side analytics across all pages remains follow-up work.

## Quick start

Use Flutter **3.32.8** with Dart **3.8.1**, the CI baseline, or a compatible newer SDK. Keep `pubspec.lock` committed for reproducible dependencies.

```sh
git clone https://github.com/madhukamethsara/city-management-.git
cd city-management-
flutter pub get --enforce-lockfile
flutter run -d chrome --dart-define=AUTH_MODE=demo
```

Use `flutter devices` to list targets, then `flutter run -d <device-id> --dart-define=AUTH_MODE=demo` for an emulator or physical device. Android requires the Android SDK; iOS development requires macOS and Xcode. Web development requires Chrome.

### Demo accounts

| Role | Email | Password |
| --- | --- | --- |
| Resident | `citizen@smart-sabha.lk` | `demo12345` |
| Authority administrator | `officer@smart-sabha.lk` | `demo12345` |
| Officer | `dilan.w@smart-sabha.lk` | `demo12345` |

Demo data is seeded and held in memory. It resets when the app restarts. These accounts are demo fixtures, not accounts in your Supabase project.

## Connect Supabase

Follow [authentication setup](AUTH_SETUP.md) for email delivery, callback URLs and session configuration, then [backend setup](BACKEND_SETUP.md) for database provisioning and verification.

Apply all five migrations in order before starting connected mode:

1. `supabase/migrations/202609290001_report_workflow.sql`
2. `supabase/migrations/202609300001_project_workflow.sql`
3. `supabase/migrations/202610020001_announcement_workflow.sql`
4. `supabase/migrations/202610040001_officer_management.sql`
5. `supabase/migrations/202610050001_department_lifecycle.sql`

Provision actual authorities and departments, register staging users, and assign the initial officer/administrator roles as described in the backend guide. New accounts start as citizens. Server functions enforce authority and role permissions; connected mode does not fall back to demo records.

For local web development, allow `http://localhost:3000/` in Supabase Auth and run:

```sh
flutter run -d chrome --web-port=3000 --dart-define=AUTH_MODE=supabase --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY --dart-define=AUTH_REDIRECT_URL=http://localhost:3000/
```

For Android/iOS, omit the web redirect override to use `lk.smartsabha.app://auth-callback`. Register that callback in Supabase Auth. Use the same public project settings for builds.

### Configuration

Settings are supplied through `--dart-define`. [.env.example](.env.example) documents the values; the app does **not** load that file automatically.

| Setting | Purpose |
| --- | --- |
| `AUTH_MODE` | `auto` (default), `demo` or `supabase`. Auto selects Supabase when either project setting is present; both settings must be valid. |
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Public publishable/anon key; never use a service-role or secret key |
| `AUTH_REDIRECT_URL` | Optional absolute authentication callback URL |
| `MAP_TILES_URL` | Tile URL template; defaults to `https://tile.openstreetmap.org/{z}/{x}/{y}.png` |

## Project structure

```text
lib/
  app.dart             Application bootstrap and protected routes
  core/                Configuration, copy and theme
  data/                Repository contracts, demo/Supabase adapters and codecs
  models/              Civic domain models
  state/               Shared controller and inherited application scope
  features/            Auth, onboarding, citizen, reports, projects, community, admin
  widgets/             Shared UI, navigation and map components
supabase/migrations/   Ordered database migrations and permission-checked RPCs
test/                  Flutter unit, repository, workflow and layout tests
tool/                  Executable PostgreSQL permission/workflow tests
.github/workflows/     CI checks
```

## Validation

Run the Flutter checks from the repository root:

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub --fatal-infos
flutter test --no-pub
```

Database checks require Node.js (CI uses Node 22) and an ephemeral PostgreSQL runtime:

```sh
npm install --prefix .dart_tool/sql-validation --no-audit --no-fund --ignore-scripts @electric-sql/pglite@0.5.8
node tool/test_report_backend.mjs
node tool/test_project_backend.mjs
node tool/test_announcement_backend.mjs
node tool/test_officer_backend.mjs
```

These checks run locally without a live Supabase project. The [GitHub Actions workflow](.github/workflows/flutter.yml) runs Flutter and database checks on pushes and pull requests. Live Auth callbacks, Storage HTTP uploads, multiple device sessions and accessibility still need staging/device verification.

## Builds

For a demo build:

```sh
flutter build apk --dart-define=AUTH_MODE=demo
flutter build web --dart-define=AUTH_MODE=demo
```

Connected builds require the Supabase defines above. Release signing, hosting, privacy disclosures, operational ownership and rollback are tracked in the roadmap.

## Development guides

- [ROADMAP.md](ROADMAP.md): delivery status and remaining work
- [BACKEND_SETUP.md](BACKEND_SETUP.md): migrations, authority provisioning, permissions and staging checks
- [AUTH_SETUP.md](AUTH_SETUP.md): authentication modes, callback configuration and live verification
- [TODO.md](TODO.md): implementation checklist

When contributing, keep changes focused on a roadmap task, run the relevant checks and describe behavior, validation and deployment requirements in the pull request.

## Maps

The app displays attribution to OpenStreetMap contributors. Choose a suitable tile provider for deployment and review the [OpenStreetMap tile usage policy](https://operations.osmfoundation.org/policies/tiles/) before using the public tile service at scale.
