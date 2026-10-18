# F30 · Guests see 3 hostels, then sign in

**Stage:** Ideas (founder, 2026-10-18) → **Spec final (hub, 2026-10-18, under the founder's delegation)** → Design → Build (wave 1).

**Founder (2026-10-18):** without signing in, a user sees two or three hostels (layouts and building views); after that the app
asks them to sign in to see more. Goal: every user becomes a signed-in user.

Replaces part of the 2026-10-05 rule "layouts free to access for everyone": they stay free of **holds**; after 3 hostels a
guest is asked to **sign in** (Google one-tap, free). Recorded in DECISIONS 2026-10-18.

## Rules (hub decisions)
| # | Rule |
|---|---|
| 1 | The unit is a **hostel page opened** (S13, incl. its Building view S87 and layouts). Guests get **3** distinct hostels per device |
| 2 | Explore list, map, prices, areas, filters, sort, UNVERIFIED pages (T32) stay free. Only the 4th **verified** hostel page asks for sign-in |
| 3 | The counter is per device, kept across restarts (`SharedPreferences` key `guestHostels`, list of hostel ids). A hostel opened from a shared link (`app/r/`, deep link) counts as one of the 3. Re-opening one of the 3 is free |
| 4 | Signed-in users: no limit. After sign-in the user lands back on the hostel they tried to open |
| 5 | Copy on the wall: title **"Sign in to see all N hostels"** (N = live hostels in Explore), line "Free. One tap with Google. Your 3 free hostels: A, B, C." Primary **Continue with Google** (red), secondary **Not now** (back to Explore). Never "Login required" |
| 6 | First visit hint on Explore (once, until dismissed or signed in): small line under the header "3 hostels free to open, then sign in (free)". Not a screen; a status variant of S8 |
| 7 | Demo APK / prototype (`DATA=sample`): same behaviour; **Continue with Google** there uses the existing sample sign-in path |

## Screens
| Id | Screen | What's on it |
|---|---|---|
| **T34** `signInWall` (new full-screen state over S13) | Sign in to see all N hostels | Hostelzy mark, title, "Free. One tap with Google.", the 3 hostels you opened as plain text, **Continue with Google**, **Not now**. Light + dark |
| S8 `explore` (variant) | First-visit hint line | Under the header, once |
| S13 `detail` (changed) | Opening the 4th hostel as a guest shows T34 instead of the page | — |

## Server
None. Client-side counter only. Sign-in is the existing Google flow (`afterSignIn = 'wall'` returns to the hostel).

## Build notes
- `features/session/guest.dart`: `guestHostels` list + `canOpenHostel(id)`; `AppState.openHostel` checks it for guests.
- `SharedPreferences` persisted like `opens`. Tests: 3 free, 4th walls, same hostel again is free, sign-in clears, shared link counts.
- SCREENS: +1 state (T34). BOARD count +1.

## Build (wave 1, branch `feature/w1-filter-wall-contacts`, PR #W1, 2026-10-18)
- **State** `features/session/guest.dart`: `guestFreeHostels = 3`; `guestHostels` (the verified hostels this guest opened,
  ids in order) and `guestHintOff`, both kept on the phone (`snapshot()` keys `guestHostels`, `guestHint`; `restore()` in
  `state.dart`); `canOpenHostel(h)` (signed in · UNVERIFIED · one of the 3 · under 3), `wallFor(h)`, `openHostel(id)` (the one
  opener for the hostel card, the map card, Saved and the UNVERIFIED card; `pickWhereHostel` counts too), `wallContinue()`
  (`afterSignIn = 'wall'`, `_afterScreen = 'detail'`; Google when the build has it, else the existing sample path
  `continueOnPhone` → About you), `wallNotNow()` (→ Explore), `dismissGuestHint()`. Sign-in clears the list (`_finishSignIn`,
  `savePhone`), so a signed-in user has no limit.
- **T34** `SignInWallScreen` in `features/session/guest_screens.dart`, shown by `HostelPage`
  (`features/explore/unverified_screen.dart`) when `wallFor(h)`; the page itself is untouched. **S8 hint** in `ExploreScreen`
  (`features/explore/explore_screen.dart`, keys `guestHint`, `guestHintClose`).
- **Copy** (F31 Rule A, applied on the coordinator's instruction, 2026-10-18): title "Sign in to see all N hostels" (N =
  `tierCounts(null).verified`), the state line "Your 3 free hostels: A, B, C.", red **Continue with Google**, **Not now**. The
  spec's "Free. One tap with Google." was a helper sentence and is **dropped**. The S8 hint "3 hostels free to open, then sign in
  (free)" stays (a count / state).
- **Tests** `hostelzy/test/f30_guest_limit_test.dart` (7): 3 free, the 4th walls (title, names, buttons, no "Login required"),
  re-opening one of the 3 is free, Not now → Explore, an UNVERIFIED page never walls or counts, kept on the phone; Continue with
  Google lands on the hostel and clears the count (the sample path and a Google fake); the map card, Saved and Where? count;
  restore / snapshot and the rules; the hint until dismissed and never when signed in; the wall fits 360 px at 2× text, light
  and dark. No SQL.

## Not in the spec
- "A hostel opened from a shared link counts": there is **no hostel share link yet** (`app/r/` carries HZ codes only; the
  `?h=<id>` link arrives with F28 Part 2's claim link, wave 2). Every opener goes through `openHostel`, so a link counts the day
  it exists. decided: no new deep link in wave 1.
- N on the wall = every live verified hostel in Explore's data (`tierCounts(null)`), not the current filtered list. decided.
- "Not now" always goes to Explore (the spec's copy), also from the map or Saved; Android back returns to where the user was. decided.
- The wall has no back arrow (not in the spec's element list); Android back works as everywhere. decided.
- Sign-in empties `guestHostels`, so a later log-out starts a fresh 3 on that phone. decided.
- "Free. One tap with Google." dropped (F31 Rule A, coordinator 2026-10-18). decided.

## Design
**Design approved** (Design, 2026-10-18). Canvas v25 on branch `design/f26-merge` (`docs/design/v25/`, hub publishes): **[T34]** signInWall light + dark (logo, "Sign in to see all N hostels", "Free. One tap with Google.", the 3 hostels, red Continue with Google, Not now) · [variant of S8] first-visit hint line with a dismiss ×. Rule A (F31) applied: no other helper lines.

