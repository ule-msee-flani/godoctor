# Assets: where every picture, logo and video goes

Everything you supply lives under this folder. **Save a file with the exact
name shown; the extension can be `.png`, `.jpg`, `.jpeg` or `.webp`** and the
app finds it automatically. Anything you haven't supplied yet shows a designed
placeholder, so nothing looks broken while you fill things in.

> **After adding or replacing files, fully restart the app** (stop and run
> again). Hot reload does not pick up new asset files.

```
assets/
├── video/            the launch video
├── logo/             app icon + in-app logo
└── images/
    ├── auth/         sign-in / role screen picture
    ├── banners/      the three home-screen carousel banners
    ├── states/       waiting / status screens
    ├── specialties/  one picture per specialty (+ optional page header)
    └── medicine/
        ├── categories/   one picture per medicine shelf
        └── products/     optional picture per medicine (see NAMES.txt)
```

## Launch video: `assets/video/`

| File | Notes |
|---|---|
| `splash.mp4` | Plays full screen the first time the app opens, then fades into the app. `.webm` / `.mov` also work. |

- **Format:** MP4 (H.264) plays everywhere. Keep it short (2 to 5 seconds) and small (a few MB).
- **Shape:** it is scaled to *cover* the screen, so the edges get cropped on
  screens with a different shape. Keep important content in the middle. A
  portrait video (e.g. 1080x1920) suits phones best.
- **Sound:** plays with sound on Android. **Browsers block autoplay with sound,
  so on the web (and installed web app) it is silent.**
- **Background colour:** before the video's first frame there is a solid colour
  (`#0B1730`, dark navy). If your video starts on a different colour, change it
  in these three places so there is no colour flash:
  `lib/core/widgets/splash_gate.dart` (`kSplashBackground`),
  `android/app/src/main/res/values/splash_colors.xml`, and `web/index.html`.
- **What is not possible:** the phone briefly draws its own launch screen
  before any app can run. We've made it a plain colour with no icon on Android.
  An *installed web app* on Android shows a browser-made icon splash for a
  moment (browsers don't allow anything else); the video follows straight after.

## Logo: `assets/logo/`

| File | Size | Used for |
|---|---|---|
| `app_icon.png` | 1024x1024, square, **no transparency** | The app icon (Android home screen, web app icon, browser tab) |
| `app_icon_foreground.png` | 1024x1024, **transparent background**, artwork inside the central 66% | Android's round/squircle "adaptive" icon (the phone crops the edges) |
| `logo.png` | any size, **transparent background**, wide is best | The logo shown inside the app (top of the sign-in screen) |

The two `app_icon` files currently hold a placeholder we generated. **After you
replace them, regenerate the icons for every platform:**

```
cd app
dart run flutter_launcher_icons
```

(or just tell me and I'll run it and rebuild).

## Sign-in screen: `assets/images/auth/`

| File | Size | What |
|---|---|---|
| `auth_hero` | about 1200x900 | Warm picture at the top of the role-select screen: a patient video-calling a doctor |

## Home carousel: `assets/images/banners/`

Each banner keeps its blue/teal colour as a see-through tint **over** your
picture, so pick pictures that still look good under colour. Put the subject on
the **right**; the left is where the text sits.

| File | Slide | Size |
|---|---|---|
| `banner_doctor` | "See a doctor in minutes" | about 1200x500 |
| `banner_pharmacy` | "Medicine from chemists near you" | about 1200x500 |
| `banner_prescriptions` | "Keep every prescription in one place" | about 1200x500 |

Don't put text inside the pictures; the app draws the words.

## Status screens: `assets/images/states/`

| File | Size | What |
|---|---|---|
| `waiting_search` | about 1000x750 | "Looking for an available doctor" screen |

## Specialties: `assets/images/specialties/`

One **square** picture per specialty (about 600x600), used on the home screen
tiles and the intake form. Optionally add a wide `<name>_hero` picture (about
1600x900) for the top of that specialty's own page; without it the tile picture
is used there.

| Tile label | Picture file | Optional page header |
|---|---|---|
| General | `general` | `general_hero` |
| Children | `children` | `children_hero` |
| OB/GYN | `obgyn` | `obgyn_hero` |
| Internal | `internal` | `internal_hero` |
| Skin | `skin` | `skin_hero` |
| Mental health | `mental-health` | `mental-health_hero` |
| Heart | `heart` | `heart_hero` |
| ENT | `ent` | `ent_hero` |
| Bones | `bones` | `bones_hero` |

The **text** of each specialty page is in its own file:
`lib/features/patient/specialties/content/<name>_content.dart`. Edit one
without touching the others. To give a specialty a completely different page
layout, register a custom screen in `specialty_registry.dart`
(`specialtyPageOverrides`).

## Medicine gallery: `assets/images/medicine/`

The "Order medicine" screen shows one big product picture at the top and shelves
of medicines below. A medicine's picture is the first of these that exists:

1. **A photo set in the database by an admin:** upload to the `drug-images`
   bucket in Supabase and put the file name in that medicine's `image_path`.
2. **A chemist's pack photo:** chemists photograph the pack they sell when
   adding stock (or later, by tapping the photo in their inventory table). The
   most recent one from a verified chemist is used. Patients also see each
   chemist's own photo when choosing where to buy.
3. **Its own picture** in `products/`, named as listed in
   `products/NAMES.txt` (all 90 current medicines, generated from the live catalogue).
4. **The picture for its shelf** in `categories/` (below).
5. A tinted illustration.

The shelf pictures and a few product pictures shipped now are **free placeholders
for testing** (CC0 / public domain / CC BY). Sources and licences are listed in
`images/medicine/CREDITS.md`; the CC BY ones need that credit shown somewhere in
the app (e.g. an About/credits screen). Replace them before launch.

Supplying just the 7 shelf pictures already makes the gallery look complete.

| Shelf | File in `categories/` | Size |
|---|---|---|
| Tablets | `tablets` | about 600x600 |
| Capsules | `capsules` | about 600x600 |
| Syrups & Sachets | `syrups` | about 600x600 |
| Creams & Topicals | `creams` | about 600x600 |
| Drops, Sprays & Inhalers | `drops` | about 600x600 |
| Injections & Infusions | `injections` | about 600x600 |
| Other | `other` | about 600x600 |

## Rights

Only use pictures you own or have a licence to use commercially. Do not copy
photos from other apps or websites.
