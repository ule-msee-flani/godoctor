# Image shot list

The app ships without real photography. Every spot below currently renders a
designed blue-gradient placeholder (icon + filename label) via `AppImage`
(`lib/core/widgets/app_image.dart`) so nothing looks broken in the meantime.

**Drop a file at the exact path below and it displays automatically** — no
code changes needed, just a hot-restart / rebuild.

| File path | Used on | Suggested size / ratio | Content idea |
|---|---|---|---|
| `assets/images/auth_hero.png` | Role-select screen (top) and reused on the login screen | ~1200×900 (4:3), will render at 220px tall | A warm, professional shot or illustration of a video consultation — patient on a phone/laptop talking to a doctor. Sets the tone for the whole app. |
| `assets/images/home_banner.png` | Patient home screen, below the greeting | ~1200×600 (2:1), renders at 140px tall | A friendly wellness/health banner — could be a simple lifestyle photo or a calming health-themed graphic. Low-detail is fine since it renders small. |
| `assets/images/waiting_search.png` | "Looking for a doctor" waiting screen | ~1000×750, renders at 200×280 | An illustration/photo conveying "searching" or "connecting" — e.g. a doctor on-call, a phone ringing, a calm waiting-room feel. |

Only three images are wired up for now — enough to make the patient flow feel
designed without over-committing to assets before you have them. If you want
more spots covered (e.g. a distinct "matched" or "order confirmed" image
instead of the icon-badge treatment currently used there), say which screen
and I'll wire up an `AppImage` slot for it the same way.

## Notes

- Any common web format works (PNG, JPG, WebP); PNG is assumed above but the
  extension doesn't matter as long as the path matches.
- Images are served from `assets/images/`, already registered in
  `pubspec.yaml`.
- `AppImage` uses `BoxFit.cover` by default, so images get cropped to fill
  the given box — pick source images with the subject centered.
