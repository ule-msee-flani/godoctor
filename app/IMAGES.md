# Image shot list

The app ships without real photography. Every spot below currently renders a
designed blue-gradient placeholder via `AppImage`
(`lib/core/widgets/app_image.dart`) so nothing looks broken in the meantime.

**Drop a file at the exact path below and it displays automatically** — no
code changes needed, just a hot-restart / rebuild.

| File path | Used on | Suggested size / ratio | Content idea |
|---|---|---|---|
| `assets/images/auth_hero.png` | Role-select screen (top) | ~1200×900 (4:3), renders 220px tall | A warm, professional shot or illustration of a video consultation — patient on a phone/laptop talking to a doctor. Sets the tone for the whole app. |
| `assets/images/banner_doctor.png` | Home banner carousel, slide 1 ("See a doctor in minutes") | ~1200×500 (≈2.4:1), renders ~150px tall | A doctor (friendly, approachable) or a video-consult scene. Keep the subject on the **right** — the left third is covered by a dark text scrim. |
| `assets/images/banner_pharmacy.png` | Home banner carousel, slide 2 ("Medicine from chemists near you") | ~1200×500 | A pharmacist/shelf of medicines or a medicine pack in hand. Subject on the right. |
| `assets/images/banner_records.png` | Home banner carousel, slide 3 ("Keep every prescription in one place") | ~1200×500 | A phone showing a prescription, or a tidy health-folder graphic. Subject on the right. |
| `assets/images/waiting_search.png` | "Looking for a doctor" waiting screen | ~1000×750, renders 200×280 | An illustration/photo conveying "searching" or "connecting" — e.g. a doctor on-call, a phone ringing, a calm waiting-room feel. |

Banner text is drawn by the app on top of the image, so **don't bake text into
the banner images**.

## Notes

- Any common web format works (PNG, JPG, WebP); the path must match exactly
  (including the extension you actually use — if you supply `.jpg`, tell me and
  I'll update the path, or just save as `.png`).
- Images are served from `assets/images/`, already registered in
  `pubspec.yaml`.
- `AppImage` uses `BoxFit.cover`, so images are cropped to fill the box — pick
  sources with the subject centred (or on the right for banners).
- Only use images you have the rights to. Stock/illustration sites with a
  clear commercial licence are fine; don't lift photos from other apps or
  repos.
