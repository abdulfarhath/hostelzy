# F30 · Guests see 3 hostels, then sign in (ideating, 2026-10-18)

**Founder (2026-10-18 05:40):** without signing in, a user sees two or three hostels' layouts and building views; after that
the app asks them to sign in to see more. The point is to bring every user into the app as a signed-in user. "Is this idea
fine, or is there any improvement needed?"

Note: this changes the 2026-10-05 rule "layouts free to access for everyone, never a screen saying hold a bed to see".
Holds stay out of it (no hold needed); only **sign-in** is asked after 3 hostels. If approved, DECISIONS gets the new rule.

## Hub's view: fine, with 5 adjustments
| # | Adjustment | Why |
|---|---|---|
| 1 | Gate the **hostel page**, not the layout | The layout is inside the hostel page. Counting "hostels opened" is simple for the user to understand: "3 hostels seen" |
| 2 | Explore list, map, prices, areas stay free | A guest can still search and compare; they sign in when they want to go deep. Searching is what brings them in; the gate only costs them when they already found value |
| 3 | The ask says what they get, not what they can't | "Sign in to see all 120 hostels. Free, one tap." Google one-tap sign-in (already in the app). Never "Login required" |
| 4 | Count per device, kept across restarts; shared links count too | A hostel opened from a WhatsApp `app/r` link is one of the 3. No way round it by reinstalling is not worth building; the honest counter is enough |
| 5 | Owner try mode "Edit this layout" is inside the hostel page | So it is covered by the same 3; nothing extra |

Also: sample-data demo APK and the prototype show the gate too (with a "sign in" that just continues), so the founder can review it.

## What changes if approved
S13 hostel page: 4th open as a guest → full-screen sign-in ask (new screen, "Sign in to see more" with the count); Explore
cards show a small "3 free" hint on the first visit only. SQL: none (client-side counter + the existing is_guest checks). SCREENS +1.

## Question for the founder
| # | Question | My pick |
|---|---|---|
| 1 | 3 hostels (not 2)? | 3 |
| 2 | Agree that list, map and prices stay free for guests, the gate is on the hostel page? | Yes |
