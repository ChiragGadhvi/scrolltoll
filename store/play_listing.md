# Play Store listing — Rotto

Everything below is checked against what the app actually does as of this build.
Nothing here claims a feature that isn't shipped.

**The existing listing describes the old app.** It talks about a savings jar,
"tolls", points saved and "your time is money" — all of that was removed from
Rotto. The three current screenshots show the jar UI and cannot be reused.

---

## App name (max 30)

Current field says `Rotto` (5 chars). That's clean but gives Play nothing to
match searches against. Pick one:

| Option | Chars | Note |
|---|---|---|
| `Rotto` | 5 | Pure brand. Only findable if someone already knows the name. |
| `Rotto: Screen Time Pet` | 22 | **Recommended.** Keeps the brand first, adds the two words people actually search. |
| `Rotto — Screen Time Buddy` | 25 | Same idea, softer. |

## Short description (max 80)

```
Meet Rotto. His energy drains as your screen time climbs. Fully offline.
```
(72 characters)

Alternates, if you want a different angle:
```
A screen time tracker with a face. Pick your apps, watch Rotto react.
```
```
Track only the apps you choose. Rotto's mood does the rest. No account.
```

## Full description

```
Rotto is a little creature who lives on your phone and reacts to how much you
scroll.

He starts every morning full of energy. As the time in your chosen apps adds
up, his score drops from 100 towards 0 and he changes with it — bouncing,
then settling in for a scroll, then tired, then fully committed to the feed,
then flat out. One glance at him tells you how your day is going.

🟣 A CHARACTER, NOT A SPREADSHEET
Five moods, from Energetic to No Energy, driven purely by your real screen
time. Rotto never nags and never scolds. He just reacts.

📱 ONLY THE APPS YOU PICK
Nothing is counted until you choose it. Instagram, YouTube, TikTok, games,
your browser — or nothing at all. Anything installed on your phone can be
tracked, and you can change the list any time.

⏱️ HONEST NUMBERS
Rotto measures real foreground time from Android's own usage data. Nothing is
estimated, inferred or padded. Screen off means the clock stops.

📊 TODAY, THIS WEEK, THIS MONTH
Insights shows your day, your week and your month. Every day appears as a coin
with Rotto's face in it — the pose tells you the mood, the number tells you the
time. Tap any day to see its total and the app that took the most of it.

🔍 PER-APP DETAIL
Tap any tracked app for its own history: how long, how many times you opened
it, your longest single stretch, your typical visit, and what share of your
screen time it accounts for.

🏠 HOME SCREEN WIDGET
A small widget showing Rotto's current pose and today's score. Glance and know.

🔔 GENTLE NUDGES
An optional end-of-day reminder, and a heads-up when Rotto's mood changes.
Both off-switchable, neither pushy.

🔒 FULLY OFFLINE — NOTHING LEAVES YOUR PHONE
Rotto has no internet permission at all. It cannot phone home, because it has
no way to. No account, no sign-in, no cloud, no analytics, no ads, no tracking.
Your history lives in your phone's private storage and goes with the app if you
uninstall it.

WHAT ROTTO DOES NOT DO
It never blocks, closes, locks or limits an app. It doesn't read your screen,
your messages or your notifications. It sets no targets and gives you no
allowance to blow. It measures, and it gives you a face to read.

Rotto is for fun and self-awareness. The score and the moods are not a medical
or diagnostic measure of anything.

PERMISSIONS
• Usage Access — the only way Android will report app screen time. You grant it
  yourself in Settings, and Rotto works without it (you just get no numbers).
• Notifications — for the optional daily reminder and mood changes.
• App list — so the picker can show you which apps you could track.

Take a look at your day. Rotto's already looking.
```

---

## Graphics

Generated and ready to upload from `store/`:

| Asset | File | Spec | Status |
|---|---|---|---|
| App icon | `store/play_icon_512.png` | 512×512 PNG, opaque | ✅ ready |
| Feature graphic | `store/feature_graphic_1024x500.png` | 1024×500 PNG, opaque | ✅ ready |

Both are flat RGB with no alpha, which is what Play wants — it applies its own
rounding and shadow to the icon.

### Screenshots — you have to capture these

Delete all three current ones; they show the jar app. Play needs **2–8**, and
**at least 4 at 1080px+ on the shortest side** to be eligible for promotion, so
shoot 5 or 6. In portrait (9:16) on a normal-density phone.

I can't generate these — a fabricated screenshot of a screen the app doesn't
render would be misleading, and Play treats that as a metadata violation. Run
the app and capture:

1. **Home** — Rotto on the hill with a real score and a few apps listed. Best
   with 1–3 hours of tracked time so he's mid-ladder and the list isn't empty.
2. **Insights → Week** — the coin chart. This is the most distinctive screen in
   the app; make it screenshot #2 so it shows up in the store carousel early.
3. **Insights → Month** — the calendar of coins.
4. **Day detail popup** — tap a coin, capture the centred dialog with the pose
   and the most-used app.
5. **App detail** — a tracked app's history plus "How you use it".
6. **Settings** — the ROTTO'S MOODS list. Explains the whole concept in one
   image, which is exactly what a store browser needs.

Practical note: get a day or two of real usage on the device first. On a fresh
install Month is mostly empty coins (Android only hands over about a week of
detail), and empty screens sell nothing.

---

## The other Play forms that will block your release

These are separate from the listing and each one can hold up review:

- **Data safety** — declare **no data collected and no data shared**. That is
  genuinely true here: the release build has no `INTERNET` permission. Tick
  "data is encrypted in transit" as not applicable, and say data is not
  transferred off device.
- **`QUERY_ALL_PACKAGES` declaration** — Play requires a written justification
  for this one. Yours: the app's core function is letting the user choose which
  installed apps to track, so it must enumerate launchable apps to populate the
  picker. It is never transmitted anywhere.
- **Usage Access / `PACKAGE_USAGE_STATS`** — expect a policy question. Same
  answer: it is the only Android API that reports per-app foreground time, which
  is the entire product.
- **Privacy policy URL** — required. `PRIVACY_POLICY.md` in this repo is
  accurate and current; host it somewhere public (GitHub Pages works) and paste
  the URL.
- **Content rating** questionnaire — no objectionable content, no ads, no
  purchases.
- **Ads declaration** — no ads.
- **Target audience** — not designed for children; this avoids the Families
  policy requirements entirely.

## Also worth fixing before you build the AAB

- **`android/key.properties` does not exist.** The Gradle config falls back to
  debug signing when it's missing, so the AAB would be debug-signed and Play
  will reject the upload. You need your upload keystore wired up here.
- **Version is `2.0.0+3`** in pubspec, but the last commit in git is at
  `1.0.0+2`. Whatever versionCode you last shipped, the new one has to be
  higher, so check the Play Console's release history before building.
- The console header still reads "ScrollToll" — that updates once you save the
  listing with the new app name. The package name stays `com.chirag.scrolltoll`
  forever and is invisible to users; that's fine and can't be changed.
