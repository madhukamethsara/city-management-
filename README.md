# Smart Sabha — Flutter Frontend

Smart Sabha is a mobile-first civic engagement application for Sri Lankan Pradeshiya Sabhas, Urban Councils, and Municipal Councils.

It gives residents one place to discover public projects, see them on an OpenStreetMap map, report local issues, track their cases, receive local announcements, submit community proposals, and take part in public consultations. Authorised officers receive a separate management console.

> **Two modes:** demo mode includes all civic screens with seeded in-memory data. Supabase mode connects reports, projects, announcements, feed participation, profiles, departments, administrator account management, private evidence and notifications to persistent storage. Apply all four migrations and follow [backend setup](BACKEND_SETUP.md) before using configured Supabase credentials. See [the roadmap](ROADMAP.md) for remaining modules.

## Included functionality

### Citizen experience

- Welcome, registration, login, forgot-password, and reset-password flows
- Guest browsing and role-aware access prompts
- Five-step onboarding: personal details, authority/ward, private approximate location, review, completion
- Responsive citizen shell: Home, Explore, Report, Projects, Notifications, Profile
- Public-project search, sort, status filtering, grid/list views, budget transparency, milestones, updates, documents, feedback, follow updates
- Interactive OpenStreetMap map with project, report, and facility markers
- Multi-step issue reporting with location pinning, gallery image selection, duplicate-report detection, case number generation, and tracking
- Report timeline, resident resolution confirmation, comments, and follow updates
- Civic feed with reactions, comments, save, and clipboard sharing
- Local announcements, community proposals, support/follow/comment flows, and consultations
- Notification state with unread counts and mark-all-read behaviour
- Global search across visible projects, announcements, reports, proposals, and consultations

### Officer experience

- Protected officer console with responsive sidebar/drawer navigation
- Operational metrics and visual charts
- Searchable/filterable complaint table with department, officer, priority, public update, internal note, and completion-evidence controls
- Project creation and management: status, progress, budget visibility, contractor, milestone, public update, document, and image inputs
- Announcement create/edit/draft/publish/archive controls with geographic targeting
- Department head, officer-count, and service-category management
- User search, role assignment, and activate/deactivate controls
- Aggregate complaint, ward, category, project-progress, and service-resolution analytics

## Main demo accounts

| Account | Email | Password |
| --- | --- | --- |
| Citizen | `citizen@smart-sabha.lk` | `demo12345` |
| Officer | `officer@smart-sabha.lk` | `demo12345` |

Demo sign-in checks the listed credentials. Supabase authentication is available when configured; see [authentication setup](AUTH_SETUP.md) for project settings, callback URLs, and live verification. Connected report data is persistent after completing [backend setup](BACKEND_SETUP.md). Projects are also persistent, including officer edits, budget privacy, public document links, subscriptions and paginated search. Announcements and their public feed are also persistent, including geographic targeting, comments, reactions and saves. Proposals and consultations remain demo-only.

## Folder structure

```text
smart_sabha_flutter/
├── lib/
│   ├── app.dart                         # Route protection and application bootstrap
│   ├── core/
│   │   ├── constants/app_copy.dart      # Translation-ready labels
│   │   └── theme/app_theme.dart          # Civic design system
│   ├── data/demo_civic_repository.dart  # Seeded frontend repository implementation
│   ├── models/domain_models.dart         # Strongly typed domain models
│   ├── state/
│   │   ├── app_controller.dart           # Shared application state and mutations
│   │   └── app_scope.dart                # Inherited app controller scope
│   ├── widgets/
│   │   ├── app_widgets.dart              # Reusable cards, states, badges, metrics
│   │   ├── civic_map.dart                # OpenStreetMap map component
│   │   └── civic_shell.dart              # Citizen navigation shell
│   └── features/
│       ├── auth/                         # Authentication and welcome screens
│       ├── onboarding/                   # Resident profile onboarding
│       ├── citizen/                      # Home, feed, notifications, profile, search
│       ├── projects/                     # Project explorer, detail, map
│       ├── reports/                      # Issue creation and case tracking
│       ├── community/                    # Announcements, proposals, consultations
│       └── admin/                        # Officer dashboard and admin management
├── .env.example
├── analysis_options.yaml
└── pubspec.yaml
```

## Run locally

Use Flutter 3.32.8 / Dart 3.8.1 or a compatible newer stable SDK, then run these commands from this folder:

```bash
flutter pub get
flutter run -d chrome
```

Android, iOS, and web runners are included. Use `flutter devices` to list available targets and `flutter run -d <device-id>` to select one. iOS builds require macOS and Xcode. Keep `pubspec.lock` checked in for reproducible dependency versions.

The Android runner includes the internet permission needed to display maps in release builds:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

## Configuration

Copy the placeholders from `.env.example` into your own secret-management flow. The map URL can be supplied at runtime without adding a dotenv package:

```bash
flutter run \
  --dart-define=MAP_TILES_URL=https://tile.openstreetmap.org/{z}/{x}/{y}.png \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Never bundle a Supabase service-role key in this mobile application.

## Backend status

`SupabaseCivicRepository` implements the first connected workflow: resident
report submission, authority-scoped officer review, comments/evidence, case
tracking, private notes, and recipient-scoped notifications. Profiles restore
onboarding and database-assigned roles. Server functions enforce permissions
and transaction boundaries. Client state is cleared on account changes.

`DemoCivicRepository` continues to support the full feature demonstration.
Connected mode never silently falls back to demo records. Projects now support
authority-scoped officer edits, milestones, private/public updates and budgets,
public HTTPS document links, following and transactional notifications. Resident
and officer listings use server-side search, sorting and pagination. Project image
uploads and feedback remain deferred. Announcements support drafts, publication, ward/GN division targeting and recipient notifications. Their feed persists comments, reactions and saved updates. Department edits and authority administrator account management are connected. Proposals and consultations are not connected yet.

Read [BACKEND_SETUP.md](BACKEND_SETUP.md) to apply all four migrations, provision a
staging authority/officer, run the database tests, and verify deployment.
Read [ROADMAP.md](ROADMAP.md) for remaining frontend/backend and release work.

## Quality checks

The GitHub Actions workflow in `.github/workflows/flutter.yml` runs on pushes,
pull requests, and manual dispatches. It uses Flutter 3.32.8, installs the
committed dependency lockfile, and checks formatting, analysis (including info
lints), and all tests. Keep the CI SDK version aligned with the local baseline.
The workflow needs no project secrets. Its first hosted run occurs after push.

To reproduce the CI checks locally:

```bash
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub --fatal-infos
flutter test --no-pub
```


After installing Flutter, run:

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

## Screenshots

Add screenshots here after running the app on an Android emulator, iOS simulator, browser, or physical device.

## Map attribution

The in-app map renders OpenStreetMap tiles and visibly attributes OpenStreetMap contributors. Use a production tile provider or respect the OpenStreetMap tile usage policy before a large public deployment.
