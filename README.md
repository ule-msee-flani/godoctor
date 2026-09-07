# GoDoctor

On-demand telemedicine + medicine ordering marketplace for Kenya (patients,
doctors, chemists). See [PROJECT_SPEC.md](PROJECT_SPEC.md) for the full
product/technical spec this build follows.

## Repo layout

```
app/                  Flutter web app (PWA) -- patient, doctor, chemist, admin UI
supabase/migrations/  Numbered SQL migrations: schema, RLS, matching logic, storage
supabase/seed/        Starter KEML drug catalog (~100 rows)
```

## One-time setup

### 1. Supabase project

1. Create a project at [supabase.com](https://supabase.com) (or use an existing one).
2. In the SQL Editor, run each file in `supabase/migrations/` **in order**
   (0001 through 0009), then `supabase/seed/keml_subset.sql`.
   - If you have the Supabase CLI linked to the project instead, `supabase db push`
     applies everything in `supabase/migrations/` for you.
3. In Authentication settings, enable **Phone** sign-in (needs an SMS provider
   configured, e.g. Twilio/MessageBird -- see Supabase's Auth > Providers >
   Phone docs) and make sure **Email** sign-in is on too (fallback per spec).
4. Create your first admin user manually: sign up any user through the app
   normally, then in the SQL editor run:
   ```sql
   update public.users set role = 'admin' where id = '<that user's auth.users id>';
   ```
   (There's no self-service admin signup by design.)

### 2. App config

```
cd app
cp .env.example .env
# edit .env: paste your Supabase project URL + anon key
```

`.env` is git-ignored -- never commit real credentials.

### 3. Run it

```
cd app
flutter pub get
flutter run -d chrome
```

To build the deployable PWA:

```
flutter build web
```

`web/manifest.json` is already set to `display: standalone` for
Add-to-Home-Screen / browser-install support.

## What's real vs. stubbed in this pass

Everything in the spec's "build now" list is implemented against live
Supabase tables/RLS/Realtime: auth, role-based dashboards, doctor matching
(rank-by-longest-idle-time with offer/decline/timeout chain), emergency
keyword hard-stop, prescription issuing (structured + free-text), chemist
inventory, medicine search + nearby-chemist matching, order lifecycle, and
the doctor/chemist verification queue.

Deliberately stubbed, per spec's "explicitly deferred" list, with a documented
seam for later:
- **Payments**: `OrderRepository.placeOrder` writes a `payments` row with
  `is_simulated = true` and marks it `succeeded` immediately -- no real M-Pesa
  Daraja call yet. Swap that one method for an Edge Function call.
- **Video calls**: `core/widgets/video_call_panel.dart` is an isolated
  placeholder widget everywhere a call surface is shown. Drop in Agora/Daily.co
  there without touching the surrounding in-call layout.
- **Push notifications**: `services/notifications.dart` only drives in-app
  banners today (no service-worker Web Push yet -- needs VAPID keys + an Edge
  Function sender). SMS fallback is not built (still an open decision per spec).
- **Offer expiry**: `expire_stale_offers()` (0008 migration) exists but needs
  a scheduler to actually fire -- either enable `pg_cron` in the Supabase
  dashboard and schedule it every ~10s, or call it from a periodically-invoked
  Edge Function. Not wired up yet.
- Chemist↔doctor Q&A, refill flow, Swahili i18n, doctor scheduling, and admin
  analytics are all phase 2 per spec and not built.

## Known open decisions (per spec, not resolved here)

Commission structure, doctor payout timing, exact dispute/timeout auto-resolution
policy, in-consultation text chat, and the SMS-fallback decision are all still
open business/product calls -- see PROJECT_SPEC.md's "Known open decisions".
