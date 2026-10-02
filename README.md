# GoDoctor

On-demand telemedicine + medicine ordering marketplace for Kenya (patients,
doctors, chemists). See [PROJECT_SPEC.md](PROJECT_SPEC.md) for the full
product/technical spec this build follows.

### **[⬇ Download the app](https://ule-msee-flani.github.io/godoctor/)**

The download page offers GoDoctor for Android (the latest release's APK) and
GoDoctor for iOS (the app itself at `/app/`, added to the Home Screen). Its
source is in [`website/`](website/); `.github/workflows/website.yml` builds the
app for the web from the latest release and publishes both with GitHub Pages
after every release — no action needed.

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

### Android app

The same codebase builds a native Android app (recommended for reliable push
on the 20-30s doctor-offer window):

#### Publishing a new version (no build on your machine)

GitHub builds the signed APK and publishes it as a Release; the
[download page](https://ule-msee-flani.github.io/godoctor/) picks it up
automatically. Either:

```
git tag v1.0.1 && git push origin v1.0.1
```

or GitHub → **Actions → Release Android APK → Run workflow** and type the
version. The workflow is `.github/workflows/release-apk.yml`; it needs the
repository secrets `APP_ENV`, `ANDROID_KEYSTORE_BASE64` and
`ANDROID_KEYSTORE_PASSWORD` (already set). Each run gets a higher build
number, so phones install it as an update.

**Signing key:** `secrets/godoctor-release.jks` (git-ignored; password in
`secrets/KEYSTORE-README.txt`). Back it up somewhere safe: without it you
can never ship an update to installed apps (or the Play Store listing).

#### Building locally

```
cd app
flutter build apk --debug --target-platform android-arm64   # quick test build
flutter build apk --release   # signed with secrets/godoctor-release.jks via android/key.properties
```

Things that will bite on a fresh machine:

- **One-time SDK setup.** `flutter doctor` must show the Android toolchain
  green: install the SDK *command-line tools* and run
  `flutter doctor --android-licenses` (you have to accept the licences
  yourself).
- **`JAVA_HOME` must point at a JDK that exists** (JDK 17-21 is safest). A
  stale `JAVA_HOME` gives "The supplied javaHome seems to be invalid".
- **Memory.** `android/gradle.properties` is sized for a 4 GB machine. The
  Flutter default (`-Xmx8G`) crashes the Gradle JVM with "insufficient
  memory" on small machines; raise it on a bigger one.
- **The first build is slow** (it downloads the Flutter engine for each CPU
  type). `--target-platform android-arm64` skips the emulator/32-bit engines.
- After removing a plugin from `pubspec.yaml`, delete `app/.dart_tool/flutter_build`
  if the web build complains about a package that no longer exists.
- App icon: regenerate with `flutter test tool/generate_icon_test.dart`, then
  `dart run flutter_launcher_icons`.

### Medicine information (free public sources)

"About this medicine" in the Order Medicine screen reads the `drug_info`
table, filled from **RxNorm** (matching, free, no key) and **openFDA** drug
labels (free; add `OPENFDA_API_KEY=...` to `app/.env` only if you hit rate
limits):

```
cd app
node tool/import_drug_info.js          # writes supabase/seed/drug_info.sql + a report
```

Then load `supabase/seed/drug_info.sql` into the database. Only labels for the
same form/route are used (no IV label for eye drops); medicines without a safe
match simply show "information not available yet". These are US labels, so the
app never shows US dosing to patients and always shows the source. To switch to
a paid Kenyan source later, replace the importer; the app only reads
`drug_info`.

### Database changes

Migrations live in `supabase/migrations/`. The repo is linked to the live
project with the Supabase CLI (`supabase/config.toml`), and the local files
and the database's migration history match exactly:

```
npx supabase migration list --linked     # local vs remote, should all match
npx supabase migration new <name>        # create a new migration file
npx supabase db push --linked            # apply any new ones to the live DB
npx supabase db query --linked -f file.sql   # run a one-off SQL/data file
```

(The Supabase MCP server in `.mcp.json` works on the same project too.) Data
files that aren't schema, like the medicine information, live in
`supabase/seed/` and are loaded with `db query -f`.

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
