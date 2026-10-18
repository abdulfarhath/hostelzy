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

## Not in the spec
Nothing. Anything extra Build finds goes here and waits for the hub.

## Design
Board `[T34] signInWall` light + dark, variant of `[S8]` with the hint line. Red CTA, square corners, 2 px rules.
