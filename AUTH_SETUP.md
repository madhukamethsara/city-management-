# Authentication setup

The app supports Supabase email/password authentication. Civic records and
profiles still use the in-memory demo repository; this is not a production backend.
Live accounts receive the citizen role until backend role permissions are added.
Onboarding must be repeated after restarting until profile persistence is connected.

## Select the mode

- No configuration: demo authentication, with the two seeded account passwords
  set to `demo12345`. Unknown emails and incorrect passwords are rejected.
- `AUTH_MODE=demo`: explicitly use the demo, regardless of Supabase settings.
- `AUTH_MODE=supabase`: require Supabase configuration. Missing settings show a
  startup error; the app never falls back to demo authentication.
- `AUTH_MODE=auto` (default): use Supabase when either Supabase setting is present.

## Configure a Supabase project

1. Enable the email/password provider and email confirmation in Supabase Auth.
2. Obtain the project URL and public publishable/anon key. Never use a service-role
   or secret key in the Flutter app.
3. In Auth URL Configuration, allow the callback URLs you will use:
   - Android/iOS: `lk.smartsabha.app://auth-callback` (registered in the platform files).
   - Web development: `http://localhost:3000/`.
   - Web deployment: your deployed app URL, including a subdirectory if applicable.
4. Configure the Site URL and email delivery for the project.
5. Run web locally with a fixed port:

```bash
flutter run -d chrome --web-port=3000 --dart-define=AUTH_MODE=supabase --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY --dart-define=AUTH_REDIRECT_URL=http://localhost:3000/
```

For mobile, omit `AUTH_REDIRECT_URL` to use the registered custom scheme. If you
change the scheme, update both AndroidManifest.xml and Info.plist as well as the
Supabase allowlist. `.env.example` documents the settings; it is not loaded automatically.

The SDK stores and refreshes sessions. Email confirmation and recovery links are
handled by the SDK; a recovery session opens the new-password form. Opening the
reset route directly does not grant permission to change a password. With the
SDK's PKCE flow, open the email link in the same app/browser that initiated it.

## Live verification still required

- Register with a new address; confirm the email, then sign in.
- Check an incorrect password fails without selecting a demo account.
- Restart and confirm the account session is restored.
- Request recovery, open the email link, set a password, and sign in with it.
- Sign out, restart, and confirm that protected screens are inaccessible.
- Test callbacks on Android, iOS, and the deployed web origin.

Automated tests use a fake auth provider and mocked HTTP responses, not a live
Supabase project. No email or remote account is created by those tests.

References: [Supabase Flutter authentication](https://supabase.com/docs/reference/dart/auth-signinwithpassword),
[auth events](https://supabase.com/docs/reference/dart/auth-onauthstatechange),
[mobile deep links](https://supabase.com/docs/guides/auth/native-mobile-deep-linking).
