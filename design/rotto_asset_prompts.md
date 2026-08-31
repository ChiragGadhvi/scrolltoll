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

## Phase 4 — looping animations, replacing every static pose (in progress)

Every place in the app currently showing one of the nine static
`assets/rotto_*.png` files gets a 5-second seamlessly-looping animation
instead, delivered as **animated WebP** (switched from an initial Lottie
plan — video→vector AI conversion degraded shape/colour quality badly;
WebP is raster, so there is no tracing step to lose quality at). Flutter's
stock `Image.asset` plays it natively, same as the PNGs today, and it
supports real smooth alpha transparency (unlike GIF's hard-edged
transparency). Workflow: generate a short looping video per pose against
a flat solid background, hand over the raw MP4/WebM, and the background
removal + WebP encoding happens locally here via `ffmpeg` (`colorkey`
filter + `libwebp_anim` encoder — no rotoscoping tool needed on the video
side). Nothing in `lib/` changes until the files exist — this phase is
prompt-writing only so far.

### What actually works well for this pipeline

The video is the only quality ceiling now (no vector-tracing step to lose
detail at), but the background-keying step still needs a clean input:

- **Locked camera, locked character position/size** — no pan, no zoom, no
  reframing, no moving closer to him. **Rotto must be noticeably smaller
  than the frame** — his body (including any raised arms, antennae or
  feet) should fill well under a third of the frame's height, leaving a wide,
  clearly empty margin on all four sides the whole clip, the same framing
  as the still it's animating. Nothing of him may touch or crowd the
  edges — a generation that fills the frame edge-to-edge is wrong even
  if everything else about it is right. Any camera motion (including a
  slow push-in) confuses per-frame tracing.
- **One or two moving parts per loop**, not layered secondary motion — a
  body bob, a blink, a limb. Cloth folds, particle effects, complex
  secondary motion all convert to messy, jittery paths.
- **Flat, high-contrast background, no baked-in shadow** — plain white is
  easiest. Video can't carry alpha, so this gets `colorkey`'d out with
  `ffmpeg` afterward, same idea as the border-flood-fill used to add real
  alpha to the earlier static PNGs. A gradient backdrop or a soft shadow
  under Rotto's feet keys out messily or leaves a visible fringe/patch —
  flat and shadowless converts cleanly.
- **A true loop** — last frame matching the first, or motion that is
  inherently cyclical (a bounce, a blink, a spiral) — or there's a visible
  jump-cut every 5 seconds.
- 24fps, 5 seconds, character centered with the same generous padding as
  the stills.

### Prompts, by static asset replaced

Each entry gives the **image-to-video** version (preferred — anchors to
the exact already-approved pose) and a **text-to-video** fallback for a
tool that can't take an image input. All nine repeat the "flat 2D vector,
Dumb Ways to Die-style, solid purple body" identity implicitly by
anchoring to the existing PNG; the fallback prompts restate it explicitly
since they have nothing to anchor to.

1. **`assets/rotto_energetic.png`** (Home hero, Insights total card, day
   detail popup)
   - Image-to-video: "Animate this character with a light continuous
     bounce in place — compress down, spring up, a big happy blink once
     per cycle, arms swinging up slightly at the peak of the bounce. Loop
     seamlessly: the landing pose must exactly match the starting pose.
     Locked camera, character stays centered and the same size
     throughout, filling well under a third of the frame height with wide
     empty margin on all four sides — nothing touching the edges, never
     zoom in or crop closer. Flat white background. 5 seconds, 24fps."
   - Text-to-video fallback: "[Rotto's fixed identity from Phase 1 above].
     Pose: light continuous bounce in place, arms swinging up slightly at
     the peak, one big happy blink per cycle, landing exactly back on the
     starting pose for a seamless loop. Locked camera, flat white
     background, character centered and small in frame — filling well under a third of the frame height, wide empty margin on all four sides,
     nothing touching the edges — unchanging in size, never zoom in or
     crop closer. 5 seconds, 24fps."

2. **`assets/rotto_scrolling.png`** (same placements)
   - Image-to-video: "Animate this character holding the phone steady at
     face height. Subtle side-to-side head sway as if reading, eyes
     flicking left then right twice per loop, one slow blink, the phone
     itself stays still in hand. Loop seamlessly back to the starting
     head position. Locked camera, flat white background, character
     small and centered in the middle of the frame — filling well under a third of the frame height, wide
     empty margin on all four sides, nothing touching the edges — and
     unchanging in size, never zoom in or crop closer. 5 seconds, 24fps."
   - Text-to-video fallback: "[Rotto's fixed identity]. Pose: holding a
     simple black smartphone steady at face height, subtle side-to-side
     head sway as if reading, eyes flicking left then right twice per
     loop, one slow blink, phone stays still. Loop seamlessly. Locked
     camera, flat white background, character small and centered in the middle of the frame —
     filling well under a third of the frame height, wide empty margin on all
     four sides, nothing touching the edges — never zoom in or crop
     closer. 5 seconds, 24fps."

3. **`assets/rotto_tired.png`** (same placements)
   - Image-to-video: "Animate this character with slumped shoulders. One
     slow heavy blink — eyes close and reopen slower than a normal blink —
     head drooping down slightly then lifting back to the starting droop,
     a small yawn-like mouth stretch at the midpoint. Loop seamlessly back
     to the exact starting pose. Locked camera, flat white background,
     character small and centered in the middle of the frame — filling well under a third of the frame height, wide empty margin on all four sides, nothing touching the
     edges — and unchanging in size, never zoom in or crop closer. 5
     seconds, 24fps."
   - Text-to-video fallback: "[Rotto's fixed identity]. Pose: slumped
     shoulders, phone held low, one slow heavy blink, head drooping then
     lifting back to the starting position, a small yawn-like mouth
     stretch at the midpoint, looping seamlessly. Locked camera, flat
     white background, character small and centered in the middle of the frame — filling well under a third of the frame height, wide empty margin on all four sides,
     nothing touching the edges — never zoom in or crop closer. 5
     seconds, 24fps."

4. **`assets/rotto_bingemode.png`** (same placements)
   - Image-to-video: "Animate this character almost entirely still — fully
     absorbed, phone held overhead with both hands not moving. The only
     motion is a slow hypnotic spiral rotating inside each eye. The spiral
     completes exactly one full rotation over the 5 seconds so it loops
     seamlessly with no visible seam. Locked camera, flat white
     background, character small and centered in the middle of the frame — filling well under a third of the frame height, wide empty margin on all four sides, nothing
     touching the edges — and unchanging in size, never zoom in or crop
     closer. 5 seconds, 24fps."
   - Text-to-video fallback: "[Rotto's fixed identity]. Pose: reclined,
     phone held overhead with both hands, body almost entirely still and
     fully absorbed, a slow hypnotic spiral rotating inside each eye that
     completes exactly one rotation per 5-second loop for a seamless
     repeat. Locked camera, flat white background, character small and
     centered — filling well under a third of the frame height, wide empty
     margin on all four sides, nothing touching the edges — never zoom
     in or crop closer. 5 seconds, 24fps."

5. **`assets/rotto_noenergy.png`** (same placements)
   - Image-to-video: "Animate this character flopped flat with arms and
     legs splayed, eyes closed as flat lines. The only motion is a gentle,
     slow breathing rise and fall of the body. Loop seamlessly — the body
     returns to the exact same resting height at the start and end of each
     cycle. Locked camera, flat white background, character small and
     centered — filling well under a third of the frame height, wide empty
     margin on all four sides, nothing touching the edges — and
     unchanging in size, never zoom in or crop closer. 5 seconds, 24fps."
   - Text-to-video fallback: "[Rotto's fixed identity]. Pose: flopped flat,
     arms and legs splayed, eyes closed as flat lines, a gentle slow
     breathing rise and fall of the body as the only motion, returning to
     the exact same resting height each cycle for a seamless loop. Locked
     camera, flat white background, character small and centered in the
     middle of the frame — filling well under a third of the frame
     height, wide empty margin on all four sides, nothing touching the
     edges — never zoom in or crop closer. Playfully exhausted, never
     scary or sad. 5 seconds, 24fps."

6. **`assets/rotto_waiting.png`** (the sitting pose `RottoLoader` shows on
   every loading screen across the app — high visibility, worth doing well)
   - Image-to-video: "Animate this character sitting patiently. A gentle
     side-to-side sway or a small foot-tap, one occasional blink. The mood
     is calm and patient, not bored or annoyed. Loop seamlessly back to
     the exact starting pose. Locked camera, flat white background,
     character small and centered in the middle of the frame — filling well under a third of the frame height, wide empty margin on all four sides, nothing touching the
     edges — and unchanging in size, never zoom in or crop closer. 5
     seconds, 24fps."
   - Text-to-video fallback: "[Rotto's fixed identity]. Pose: sitting,
     waiting patiently, a gentle side-to-side sway or small foot-tap, one
     occasional blink, calm and patient rather than bored. Loop
     seamlessly. Locked camera, flat white background, character small
     and centered — filling well under a third of the frame height, wide empty
     margin on all four sides, nothing touching the edges — never zoom
     in or crop closer. 5 seconds, 24fps."

7. **`assets/rotto_empty.png`** (the shrug pose `RottoEmptyState` shows
   wherever a list has nothing in it yet)
   - Image-to-video: "Animate this character with a friendly shrug: arms
     and shoulders rise into a shrug, hold briefly, ease back down to
     neutral, then repeat. Friendly 'nothing here yet' body language, not
     sad or apologetic. Loop seamlessly back to the exact starting pose.
     Locked camera — do not zoom in or move closer to him at any point.
     Keep him small and centered in the middle of the frame, filling well under a third of the frame height with wide empty margin on all four sides — his
     shrugging arms must stay clear of the frame edges even at the peak
     of the shrug — exactly as framed in the starting image, unchanging
     in size the whole clip. Flat white background. 5 seconds, 24fps."
   - Text-to-video fallback: "[Rotto's fixed identity]. Pose: a friendly
     shrug — arms and shoulders rise, hold briefly, ease back down to
     neutral, repeating in a seamless loop. Upbeat, not apologetic. Locked
     camera — no zoom, no moving closer. Character small and centered in
     the middle of the frame — filling well under a third of the frame
     height, wide empty margin on all four sides, arms staying clear of
     the edges even mid-shrug — unchanging in size throughout. Flat white
     background. 5 seconds, 24fps."

8. **`assets/rotto_base.png`** (onboarding's "meet Rotto" first page;
   lower priority — a calm default rather than a hero moment)
   - Image-to-video: "Animate this character with a simple calm idle: a
     gentle breathing motion and one relaxed blink per loop. Welcoming,
     no dramatic motion. Loop seamlessly. Locked camera, flat white
     background. Rotto stands small, centered in the middle of the frame both horizontally and vertically — his
     full standing height, including antennae and feet, spans no more than about a third of the frame's height and a third of its width, leaving a
     wide, clearly visible empty margin above his head, below his feet,
     and past each arm. Do not let any part of him touch or crowd the
     frame edges, and do not zoom in — unchanging in size. 5 seconds,
     24fps."
   - Text-to-video fallback: "[Rotto's fixed identity]. Pose: standing
     neutrally, a simple calm idle breathing motion and one relaxed blink
     per loop, welcoming and friendly, no dramatic motion, looping
     seamlessly. Locked camera, flat white background. Rotto stands
     small in the middle of the frame — his full standing height,
     including antennae and feet, spans no more than about a third of the frame's height and a third of its width, leaving a wide, clearly visible empty
     margin above his head, below his feet, and past each arm. Do not
     let any part of him touch or crowd the frame edges, and do not zoom
     in. 5 seconds, 24fps."

9. **`assets/rotto_face.png`** (tight face crop used small, logo-style, in
   onboarding's privacy page; lowest priority — rendered too small for
   elaborate motion to read anyway)
   - Image-to-video: "Animate this close-up face crop with one simple,
     relaxed blink repeating every 2-3 seconds, nothing else moving. Loop
     seamlessly. Locked camera — do not zoom in or out, do not move
     closer — framing stays pixel-identical to the source crop
     throughout, flat white background. 5 seconds, 24fps."
   - Text-to-video fallback: skip — this one is a tight crop of an
     existing approved character, best generated only as image-to-video
     from the actual PNG rather than redescribed from scratch.

### Once you have the raw videos

Hand over the raw MP4/WebM per pose, named to match
(`rotto_energetic.mp4`, `rotto_waiting.mp4`, etc.), shot against a flat
solid background (plain white, no baked-in shadow). From there:

1. No `ffmpeg` in this sandbox, so this now runs through a local Python
   script (`cv2` + `Pillow`) instead of the originally-planned `colorkey`
   filter — same idea, per-frame border flood fill to alpha. Two bugs
   found the hard way while doing `rotto_base`/`rotto_empty`/`rotto_waiting`,
   worth not repeating on `rotto_face`:
   - `cv2.floodFill`'s default range is *relative to each neighbouring
     pixel*, not the original seed colour — on a frame with soft 3D
     shading (a gradient, not a flat fill) it can "drift" through the
     gradient and eat most of the character, not just the background.
     Needs `cv2.FLOODFILL_FIXED_RANGE` set explicitly.
   - The generation prompts' own "small, centered, generous margin"
     framing fix (needed so nothing clips mid-loop) becomes dead
     transparent space once baked into the shipped asset — crop every
     frame to the union of all frames' content bounding box (so a
     mid-loop pose like a raised arm is never clipped) plus a small
     buffer, *before* encoding, rather than shipping the full padded
     canvas.
   Also watch for one anomalous lead-in frame (e.g. a single solid-black
   frame before the real content starts) and a small generator watermark
   in one corner — drop frames whose corner colour doesn't match the
   clip's dominant background, and keep only the largest connected opaque
   blob after keying (the watermark isn't attached to Rotto, so it's a
   separate, much smaller component and gets dropped for free).
2. Encode the keyed, cropped result as an animated WebP, matching the
   naming of the PNGs it replaces (`rotto_energetic.webp`, etc.).
3. Wire it in: drop the `.webp` files into `assets/`, add them to
   `pubspec.yaml`'s asset list, point `RottoCharacter`'s mood map and
   `RottoLoader`/`RottoEmptyState` at them — no new package, the
   `Image.asset(...)` call sites stay exactly as they are, since
   `Image.asset` already plays animated WebP natively. I will remove
   `home_screen.dart`'s hand-rolled idle-bob animation on the hero
   character once its replacement lands, since the loop is already baked
   into the WebP and the two would otherwise fight each other.

The tiny coins in the week chart and month calendar (54px and smaller)
should probably stay static PNGs rather than each decoding its own
animated WebP — worth revisiting once the full-size ones are in and I can
see how they actually perform, not deciding it now.

## Phase 5 — richer poses + a furnished scene (revision of Phase 4 entries 2–5)

The user reviewed a reference sheet of the four "couch" moods (Scrolling,
Tired, Binge Mode, No Energy) and asked for three changes before the next
generation pass:

1. **More interesting, more legible poses** — Scrolling in particular reads
   as "holding a phone" rather than "scrolling": the free hand does a
   vague point/gesture instead of actually swiping. Named example: Rotto
   sitting on the sofa, one hand cradling the phone, the **other hand
   actively swiping down the screen**.
2. **Better, more interesting loops** — not just a single idle tell (a
   blink, a sway); each pose gets its own small piece of business that is
   obviously *about that mood* while still looping cleanly.
3. **A few background elements** — the current sheet's backdrop is flat
   cream behind a single couch. Add 2–3 room props so it reads as a
   corner of a living room, not a character floating on a swatch.

This supersedes Phase 4's entries 2–5 (Scrolling, Tired, Binge Mode, No
Energy) below; Phase 4's entries 1, 6, 7, 8, 9 (Energetic, waiting, empty,
base, face) are untouched. **v3's "flat 2D vector, no shading" style text
above is stale** — the actual approved/shipped poses (this reference
sheet, and the mp4/webp files already in `assets/`) are the softly-shaded,
gently-3D "clay" look v2 originally proposed, sitting on a coral couch.
Treat the reference sheet's four images, not the old v3 paragraph, as the
ground truth for "Rotto's fixed identity" from here on.

### The shared room (reuse identically across all four)

Generate once, reuse as the anchor/background for all four image-to-video
prompts, so the four moods read as one continuous scene:

> A small living-room corner: Rotto's coral/pink couch (as in the
> reference sheet) sits on a soft round rug, with a short wooden side
> table to one side holding a single mug, and a potted plant on the other
> side. A framed picture or a softly-lit window on the wall behind, kept
> simple — no visible clutter beyond these three props. Warm, flat,
> even lighting, no hard cast shadows other than each object's own soft
> contact shadow. The wall and floor beyond the rug are a single flat
> unbroken colour (cream, matching the existing sheet) for keying.

**Constraints that keep this keyable** (carried over from Phase 4, now
more important with more objects in frame):
- Couch, rug, table, plant and Rotto must all stay fully inside the
  frame with clear flat-background margin on every side — nothing may
  touch the image border, or the border-flood-fill used to key the
  background can't reach around it.
- Locked camera, no zoom, no push-in toward Rotto at any point — the
  framing, distance and scene stay pixel-for-pixel identical to the
  starting still for the whole clip. That still already frames the
  whole furnished scene with clear margin on every side and nothing
  touching the edges — if the tool doesn't strictly obey the input
  image's framing, say so explicitly in the prompt (do not let Rotto or
  the couch grow larger, get cropped tighter, or drift toward the
  edges).
- All props are static set-dressing: no swaying plant leaves, no
  steam off the mug, no independent motion. Only Rotto (and the one
  called-out piece of business per pose below) moves. Anything else
  moving multiplies the number of edges that have to key cleanly frame
  to frame.
- Same flat, shadowless, single-colour wall/floor behind everything, for
  the same reason plain white worked before — it's what actually gets
  keyed out; the couch/rug/table/plant/Rotto all stay opaque in the
  final asset, same as the couch already does today.

### Revised pose + loop prompts

Each of the four now follows a small **beginning → middle → payoff →
reset** beat structure across the 5 seconds, rather than one continuous
idle tell — a real tiny story per loop, timestamped so it's unambiguous
where the loop seam has to land.

**Scrolling** (replaces Phase 4 entry 2)
- Pose: sitting on the couch, phone held at chest height in one hand,
  **the other hand's index finger extended and touching the screen,
  mid-swipe** — not a vague gesture, an actual scrolling motion.
- Beats: 0.0–1.0s swipe down; 1.0–1.6s brief pause, finger lifted, a
  small interested reaction (eyebrows raise slightly, head tilts a
  little, one blink) as if something on screen caught his eye; 1.6–2.6s
  swipe down again; 2.6–5.0s repeat the swipe-pause-react rhythm once
  more, ending with the finger back at the top of the screen and the
  head/eyebrows back at their neutral starting position, matching frame
  0 exactly.
- Image-to-video: "Animate this character sitting on the couch. The
  free hand's finger swipes down the phone screen, lifts, pauses
  briefly with a small interested reaction — eyebrows raise slightly,
  head tilts a touch, one blink — as if something on screen caught his
  attention, then swipes down again; repeat this swipe-pause-react
  rhythm twice over the 5 seconds. The hand holding the phone stays
  still. Loop seamlessly: the swiping finger and the head/eyebrows must
  both be back at their exact starting position on the frame the loop
  restarts. Locked camera — never zoom in or move closer to him — Rotto
  and the whole furnished scene stay centered and the exact same size
  and position throughout, flat unbroken background colour beyond it. 5
  seconds, 24fps."
- Text-to-video fallback: "[Rotto's fixed identity, matching the
  reference sheet's couch-sitting style]. Scene: [the shared room
  paragraph above]. Pose: sitting on the couch, one hand holding a
  simple black smartphone at chest height, the other hand's finger
  swiping down the screen, pausing briefly with a small interested
  reaction (eyebrows raise, slight head tilt, one blink) as if
  something caught his eye, then swiping again — this swipe-pause-react
  rhythm repeating twice over the 5 seconds — looping seamlessly back
  to the swipe and head's exact starting position. Locked camera — never
  zoom in or move closer — character and scene centered and unchanging
  in size/position, flat unbroken background colour behind the
  furnished scene. 5 seconds, 24fps."

**Tired** (replaces Phase 4 entry 3) — the "fighting it, and winning, just
barely" mood. Deliberately contrasts with No Energy below, which loses
that fight: here the phone is always caught before it falls.
- Pose: same slumped-shoulders/drooping-eyes couch pose as the
  reference sheet, with one added detail: the phone has gone loose in
  the lower hand and is **slowly tilting/slipping**, about to (but never
  quite) fall.
- Beats: 0.0–1.5s eyes droop, head sinks lower, grip loosens and the
  phone starts to tilt; 1.5–2.2s the tilt peaks — phone at its most
  precarious angle, one slow heavy blink closing at this exact moment;
  2.2–3.2s a small startled jolt, eyes crack back open, hand snaps the
  phone back to a level grip; 3.2–5.0s settles back down into the exact
  starting slump, ready to sink again from frame 0.
- Image-to-video: "Animate this character slumped on the couch. Eyes
  droop, head sinks lower, and the phone in the lower hand tilts
  further and further off-level as the grip loosens — at its most
  precarious angle, one slow heavy blink closes — then a small startled
  jolt snaps the phone back level and the head back up, easing back
  down to the exact starting slump. Repeats once per loop, phone never
  actually falls. Loop seamlessly back to the exact starting grip and
  head position. Locked camera — never zoom in or move closer to him —
  character and scene centered and unchanging in size/position, flat
  unbroken background colour behind the furnished couch scene. 5
  seconds, 24fps."
- Text-to-video fallback: "[Rotto's fixed identity, matching the
  reference sheet]. Scene: [the shared room paragraph]. Pose: slumped
  on the couch, phone held low in one hand, eyes drooping and head
  sinking lower as the grip loosens and the phone tilts further
  off-level, one slow heavy blink at the most precarious tilt, then a
  small startled jolt snaps the phone level and the head back up,
  easing back to the exact starting slump — the phone never actually
  falls. Loop seamlessly. Locked camera — never zoom in or move closer —
  character centered, unchanging size/position, flat unbroken
  background behind the furnished scene. 5 seconds, 24fps."

**Binge Mode** (replaces Phase 4 entry 4)
- Pose: same wide-eyed, fully-absorbed couch pose, both hands on the
  phone, with the added detail that **both thumbs tap/scroll rapidly**
  instead of the phone being held perfectly static.
- Beats: 0.0–1.8s sitting forward on the edge of the couch, both thumbs
  tapping/flicking the screen rapidly; 1.8–2.6s leans in even closer to
  the screen, shoulders hunching up, as the spiral in each eye reaches
  its widest point; 2.6–3.4s leans back out to the starting distance;
  3.4–5.0s resumes the rapid tapping at the starting posture, spiral
  completing exactly one full rotation over the 5 seconds so both the
  lean and the spiral land back on frame 0 together.
- Image-to-video: "Animate this character sitting forward on the edge
  of the couch, phone held with both hands, both thumbs tapping and
  flicking the screen rapidly and continuously — quick, twitchy,
  comedic over-commitment. Partway through, he leans in even closer to
  the screen, shoulders hunching up, then leans back out to the
  starting distance. A slow hypnotic spiral rotates inside each eye,
  completing exactly one rotation over the 5 seconds so it loops
  seamlessly together with the lean. The camera itself never zooms in
  or moves closer, even as he leans — locked camera, character and
  scene centered and unchanging in size/position, flat unbroken
  background colour behind the furnished couch scene. 5 seconds,
  24fps."
- Text-to-video fallback: "[Rotto's fixed identity, matching the
  reference sheet]. Scene: [the shared room paragraph]. Pose: sitting
  forward on the edge of the couch, phone held with both hands, both
  thumbs tapping and flicking the screen rapidly and continuously in a
  twitchy, comedic, fully-absorbed way, leaning in even closer to the
  screen partway through with shoulders hunching up, then leaning back
  out to the starting distance, a slow hypnotic spiral rotating once
  per 5-second loop inside each eye timed to land back on the starting
  lean and rotation together. Loop seamlessly. The camera itself never
  zooms in or moves closer, even as he leans — locked camera, character
  centered, unchanging size/position, flat unbroken background behind
  the furnished scene. 5 seconds, 24fps."

**No Energy** (replaces Phase 4 entry 5) — the flagship rewrite: unlike
Tired, he actually loses the fight this time. The phone doesn't slip
off to one side, it **drops straight onto his own face** — that's the
gag: he's so out of it he doesn't even react.
- Pose: sitting low and slumped on the couch, **head tilted back
  against the cushion so his face points forward/up** rather than
  drooping forward — this is what makes "the phone falls on his face"
  physically make sense: it's held right above his face, so when his
  grip goes slack it only has a few inches to fall before landing flat
  on him. Phone held up near face height in one raised hand, already
  heavy-lidded at the start.
- Beats — the loop, timestamped:
  - **0.0–1.2s**: sitting low, head tilted back against the cushion,
    phone held up near face height, eyes already half-closed.
  - **1.2–2.0s**: eyes fall fully shut.
  - **2.0–2.3s**: exactly as the eyes shut, the raised arm goes slack and
    the phone drops the short distance straight down, **landing flat on
    his face**.
  - **2.3–3.2s**: hold — phone resting on his face, completely still, no
    reaction at all. The gag is that he doesn't even flinch.
  - **3.2–3.8s**: a small jolt/twitch — the arm weakly lifts, pushing the
    phone back up off his face.
  - **3.8–4.6s**: the phone returns to the exact starting raised
    position near his face, eyes cracking back open to match.
  - **4.6–5.0s**: settles into the exact starting heavy-lidded pose,
    frame-matching 0.0s so the loop is seamless — then the whole cycle
    (doze off, phone falls on his face, recover) repeats.
- Image-to-video: "Animate this character sitting low and slumped on the
  couch, head tilted back against the cushion so his face points
  forward/up, holding the phone up near face height in one raised hand,
  already heavy-lidded. His eyes fall fully shut — exactly at that
  moment, the raised arm goes slack and the phone drops the short
  distance straight down, landing flat on his face. Hold for a beat with
  the phone resting on his face, completely still, no reaction at all.
  Then a small jolt: the arm weakly lifts, pushing the phone back up off
  his face and back to the exact starting raised position, eyes cracking
  back open to match, settling into the exact starting heavy-lidded
  pose. One full doze-off/phone-drops-on-face/recover cycle per
  5-second loop, ending frame-identical to the start. Locked camera —
  never zoom in or move closer to him — character and scene centered
  and unchanging in size/position, phone stays within frame throughout,
  flat unbroken background colour behind the furnished couch scene. 5
  seconds, 24fps."
- Text-to-video fallback: "[Rotto's fixed identity, matching the
  reference sheet]. Scene: [the shared room paragraph]. Pose: sitting
  low and slumped on the couch, head tilted back against the cushion so
  his face points forward/up, holding a simple black smartphone up near
  face height in one raised hand, already heavy-lidded. Eyes fall fully
  shut; exactly at that moment the raised arm goes slack and the phone
  drops the short distance straight down, landing flat on his face; hold
  with the phone resting on his face, completely still, zero reaction;
  then a small jolt as the arm weakly lifts, pushing the phone back up
  off his face to the exact starting raised position, eyes cracking back
  open, settling into the exact starting pose. One full
  doze-off/phone-drops-on-face/recover cycle per 5-second loop,
  playfully exhausted rather than scary or sad, ending frame-identical
  to the start. Locked camera — never zoom in or move closer — character
  centered, unchanging size/position, phone stays within frame
  throughout, flat unbroken background behind the furnished scene. 5
  seconds, 24fps."

### Once you have these four raw videos

Same pipeline as Phase 4's "once you have the raw videos" section:
`ffmpeg` `colorkey` to remove the flat wall/floor and produce real alpha
(couch/rug/table/plant/Rotto all stay opaque), encode as animated WebP,
drop into `assets/`, add to `pubspec.yaml`, and the four `_moods` entries
in `rotto_character.dart` just point at the new files — no other code
changes, since `Image.asset` already plays whatever WebP is there.
