# BAID X

Flutter app for BAID X. It uses the existing Supabase project that already powers the website. This repository does not create a second backend.

## Run

```bash
copy .env.example .env
```

Put the BAID X project URL and publishable key in `.env`. Do not put the service-role key in the app.

```bash
flutter pub get
flutter run
```

Until those values are real, the app launches and shows that Supabase is not connected. It does not load sample data.

## Not confirmed yet

The connected Supabase account does not include the BAID X project, so tables, roles, RLS, storage, and auth callbacks have not been inspected. Do not assume column names.
