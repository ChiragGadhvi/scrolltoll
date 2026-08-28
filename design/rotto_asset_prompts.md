# Rotto — character & icon generation brief

Ready to run once the `kie-ai` MCP server is connected (restart Claude Code
from `E:\scrolltoll` so it picks up `.mcp.json`). Each prompt below is
self-contained — paste directly into the image-generation tool once loaded.

**Sequencing, per direction:** generate only the **confirmation pose** below
first, show it, and wait for approval before touching the other four moods,
the icon, or the splash. Nothing downstream (widget drawables, pubspec,
`rotto_character.dart`) changes until the base design is signed off.

## Style correction (v3 — current)

v2 (soft 3D clay-render, brain-topped head) was tried and rejected on the
confirmation-pose draft: the user wants a **flat 2D vector** style instead,
matching the **"Dumb Ways to Die"** game's characters — simple jellybean/blob
shapes, flat solid colors, little to no shading or gloss, clean thin or no
outlines, no 3D/plastic rendering. The brain-shaped head from v2 is also
dropped entirely (not just de-glossed) — Rotto is now a plain-headed blob
with just the two antennae. v1's original flat-style intent turns out to have
been right after all; v2 is superseded.

## Rotto's fixed identity (v3 — flat, no brain, purple)

Repeat this description verbatim in every future prompt so all poses and the
icon read as *one* character:

> Rotto: a cute simple flat 2D vector character in the style of the "Dumb
> Ways to Die" game — a rounded jellybean/blob-shaped body, flat solid
> colors with minimal or no shading/gradient, clean simple outlines (or no
> outline), not 3D-rendered, not glossy, not plastic-looking, solid purple
> body color (#7C5CBF), no brain shape or texture on the head, two thin
> curled antenna-like tendrils sticking up from the top of the head, two
> simple large black oval eyes close together with a small white highlight
> dot in each, no nose, a small simple open or closed mouth (varies by pose),
> short stubby purple arms and legs, no visible feet or hands detail beyond
> simple rounded stubs unless holding a phone. No background clutter, no
> floating icons, no text.

**Technical spec for every image:**
- Portrait or square canvas, character centered with generous padding
- Transparent background (PNG, alpha channel) if the model supports it;
  otherwise generate on a flat magenta (#FF00FF) backdrop and key it out
  afterward the same way `assets/brainfog_private.png` was cleaned up
  (border-flood fill to alpha — ask to run that conversion once the raw
  image is downloaded)
- No text, no watermark, no logo, no extra props/icons floating around it
  (the existing Brainfog placeholders have busy floating-icon backgrounds —
  Rotto's shots should be clean, character-only)
- High resolution, at least 1024×1536 (matches the existing asset dimensions)

## Confirmation pose — generate this one first

> [Rotto's fixed identity above]. Pose: standing/sitting naturally, holding a
> simple black smartphone up in one hand near face height, looking at the
> screen with a mildly dazed, wide-eyed, open-mouthed expression (one small
> white tooth visible), the other arm relaxed at its side. Friendly, a little
> goofy, not distressed. This is the reference/confirmation shot the rest of
> the mood set will be built from.

## The other four moods (hold until the confirmation pose is approved)

Same fixed identity, purple, same clean single-character framing — only the
pose/expression differs per mood. Sketch for later, not to be generated yet:

1. **Energetic** (score 100-80) — bouncy, mid-hop, arms up, big excited eyes,
   open happy smile, phone not in hand yet (or held loosely, low energy on
   the phone itself, high energy on the body).
2. **Scrolling** (score 79-60) — the confirmation pose above, or a close
   variant: calmly holding the phone, content half-lidded eyes.
3. **Tired** (score 59-40) — slumped shoulders, phone held low, drooping
   half-closed eyes, small yawn.
4. **Binge Mode** (score 39-20) — reclined, phone held overhead with both
   hands, eyes wide and glazed/spiral, fully absorbed, comedic commitment.
5. **No Energy** (score 19-0) — flopped flat, arms and legs splayed, eyes
   closed as flat lines, phone fallen to one side. Playfully exhausted, never
   scary or sad.

## App icon (hold)

Same fixed identity, simple friendly forward-facing standing pose, no phone,
centered with even padding for Android's adaptive-icon mask crop. Likely
needs a solid-color (not transparent) background per
`flutter_launcher_icons`' foreground-layer compositing — confirm against
`pubspec.yaml`'s `flutter_launcher_icons:` block when we get there.

## Status (done vs. still open)

Done:

1. All five moods generated via `gpt_image_2` image-to-image, anchored to
   `rotto_base_reference_v1.png` for consistency, then background-keyed to
   real alpha transparency locally (the raw generations came back with a
   flat cream backdrop baked in, not transparent — see
   `design/generated/*_transparent.png`).
2. Saved as `assets/rotto_<state>.png` (`energetic`, `scrolling`, `tired`,
   `bingemode`, `noenergy`) plus `assets/rotto_base.png` (neutral pose) and
   `assets/rotto_face.png` (tight face crop for small in-app logo use). The
   `_assets` map in `lib/utils/rotto_character.dart` now points at these —
   home, the weekly chart, the tracked-app tiles all picked it up for free.
3. App icon: a face closeup generated via image-to-image, then locally
   cropped/rescaled/recentered with a ~20% safe-zone margin (the model
   ignored padding instructions directly) and confirmed to have real alpha.
   Saved as `assets/ic_launcher.png`; `flutter_launcher_icons` re-run.
   `adaptive_icon_background` is still `#000000` (unchanged) — revisit if a
   purple/light background reads better behind the transparent foreground.
4. Splash: same icon art reused as `assets/ic_splash.png`;
   `flutter_native_splash:create` re-run (light `#F7F7F9` background, per
   existing pubspec config).
5. `pubspec.yaml`'s `assets:` list updated; old `brainfog_*` files deleted
   from `assets/` and no longer referenced anywhere in `lib/`.
6. Home screen: character stage enlarged (210px → 320px height). Today's
   tracked time was already surfaced in the score bar
   (`"$time of screen time today"`) and the insight card — not duplicated
   further.
7. `flutter analyze` (clean) and `flutter test` (all passing) confirmed
   after the asset swap.

Still open (not touched this pass):

- **Android home-screen *widget*** (`BrainfogWidgetProvider.kt` +
  `res/drawable-<density>/fog_{fresh,foggy,exhausted,critical}.png`) is a
  separate native subsystem from the in-app home page and still shows the
  old Brainfog-era widget art, including no `fog_binge` set for Binge Mode.
  Needs mdpi/hdpi/xhdpi/xxhdpi drawables regenerated per mood and
  `characterForState` rewired.
- Onboarding's privacy-explainer page reuses `assets/rotto_face.png` as a
  stand-in (no dedicated "stays on your phone" illustration was made).
