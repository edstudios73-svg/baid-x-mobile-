# BAID X release preparation

This is the Phase 12 release record. It does not contain secret values.

## Environment

Local Flutter reads `.env`, which is gitignored.

```text
SUPABASE_URL=YOUR_SUPABASE_PROJECT_URL
SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

The app may contain the Paystack test public key. It must not contain `sk_test_`, `sk_live_`, the Supabase service-role key, a database password, or a webhook secret.

Paystack test checkout stays on. A build must not switch to live keys in this phase.

Webhook, already configured for test mode:

`https://vxixalejbnvqivaytxzt.supabase.co/functions/v1/paystack-webhook`

Edge Function secret name: `PAYSTACK_SECRET_KEY`. Set it in the Supabase dashboard. Do not copy the value into the app or this file.

## Authentication

Email confirmation is required. Password reset uses the app scheme `com.baidx.baid_x_mobile://login-callback` on Android. Signing out returns to the marketplace. Protected routes, including billing, company billing, messages, projects, and verification review, redirect a signed-out person to sign-in.

## Roles and billing

Account type is set once on the server. A paid plan does not verify an account. Prices come from the database. `start_checkout` creates a pending payment. Only `apply_provider_payment`, called by the webhook after signature checks, can confirm it. Company billing requires an active company owner. Verification review requires a row in `private.verification_reviewers`. No reviewer is seeded.

## Database changes in Phase 12

Migration `phase12_lock_event_trigger`:

- Revoke `public.rls_auto_enable()` from `public`, `anon`, and `authenticated`.
- Add `payments_profile_idx`, `payments_company_idx`, and `subscriptions_company_idx`.

## Android

- Application ID: `com.baidx.baid_x_mobile`
- Name: BAID X
- Version: `1.0.0+1` from `pubspec.yaml`
- Permission: Internet
- Release signing currently uses the debug keystore so a release build can run. That APK is not a Play Store signing setup.

Before a store upload, create a release keystore outside the repo and a gitignored `android/key.properties`:

```text
storePassword=
keyPassword=
keyAlias=
storeFile=
```

Do not commit the keystore or those passwords.

## iOS

Display name is BAID X. The bundle id and version come from the Xcode build settings (`PRODUCT_BUNDLE_IDENTIFIER`, `FLUTTER_BUILD_NAME`). Archive and upload require a Mac with Xcode. No URL scheme was found in `Info.plist`, so the password-reset callback still needs an iOS URL type before iOS auth links work.

## Manual dashboard steps

- Enable Supabase leaked-password protection.
- Grant a verification reviewer by inserting their profile id into `private.verification_reviewers`. The app cannot do this.
- Before live payments, replace the Paystack test key, set the live secret only in the Edge Function, and point the Paystack live webhook at the same function. Do not do that during Phase 12.
- Add the release keystore before Google Play.
- Archive the iOS app on macOS.
