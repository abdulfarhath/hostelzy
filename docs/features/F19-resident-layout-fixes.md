# F19 · Residents fix their room layout

**Stage:** Design approved · 2026-10-02 (standing approval) · design: https://claude.ai/artifact/9apSaAYTzGsS8EdFQTZNBR · spec ready, founder idea, 2026-10-02 · no money and no new business rules beyond the
decision below (see DECISIONS.md "Residents fix their room layout").

## Problem
A room's layout (shape, beds, cupboards, AC, window, door) can be wrong: the owner or the team drew
it from photos or memory. The people who live in that room know it best. Moving things around is
also fun, and it keeps residents coming back to the app.

## Who can do it
- **A confirmed resident of the hostel** (an active stay there, confirmed by the owner) can suggest
  fixes for **any room in that hostel**, not just their own.
- Everyone else (tenants browsing, someone with only a hold, residents of other hostels) **still sees
  the "Edit room" button**. Tapping it shows a friendly lock sheet: "Only residents of <hostel> can
  fix room layouts. Stay here to help others see the real room." with **Book a bed** / **See beds**
  and "Already staying here? Ask your owner for your invite code." This is meant to make people want
  to join.
- A person who has moved out loses access.
- The owner (and the Hostelzy team) approve.

## User stories
**Resident**
- On my room's layout I tap **Edit my room** and get the same layout editor owners use
  (move/rotate items, change the room shape, mark items working / not working).
- I can play freely. My draft is saved only on my phone, and nobody sees it until I send it.
- I tap **Send to owner** and add a short note ("cupboard is on the left wall"). I see
  "Waiting for owner".
- I get a notification when it's approved or rejected (with the owner's reason).
- **Reset** throws away my draft and goes back to the published layout.

**Owner**
- I get a push: "Anjali (lives in 204) suggested a fix for Room 207". Example: "Anjali (Room 204) suggested a layout fix".
- I see the current layout and the suggestion **side by side** (changes highlighted) plus the note.
- I tap **Approve & publish** or **Reject** (optional reason). Approve replaces the published
  layout right away; the old one is kept in history.

**Hostelzy team**
- Sees all suggestions in the console and can approve/reject if the owner doesn't answer in 7 days.

## Rules
- One open suggestion per resident per room. A new one replaces their old pending one.
- Same safety rules as the owner editor: an AC room must have an AC unit; bed count = sharing; a bed
  with a resident can't be deleted; no gates, CCTV or exits shown.
- The resident's name is shown to the owner only, never to tenants.
- Women's PG floor-plan privacy stays for outsiders. Residents of the hostel may see every room there.
- Approved layouts show "Checked by a resident" with the date on the hostel page.

## Screens
0. Non-resident: any room layout → **Edit room** → lock sheet (above).
1. Resident: any room in their hostel → layout → **Edit room** (editor in "suggestion" mode, banner "Only you
   see this until you send it").
2. Resident: Send sheet (note + Send) → "Waiting for owner" state → approved / rejected result.
3. Owner: Today/Inbox card "Layout fix from Room 204" → side-by-side compare → Approve / Reject.
4. Team console: list of pending suggestions (older than 7 days first).

## Design

**Design approved · 2026-10-02** (standing approval). Canvas "Hostelzy · F19 Residents fix their room layout": https://claude.ai/artifact/9apSaAYTzGsS8EdFQTZNBR
Phone boards 390×844 (light; dark copies at the end of rows); console 1440×900. Same look as the owner layout editor (aLayout). Updated 2026-10-02 for the founder's change: any room in the hostel, plus a join nudge for non-residents. The example is Rahul, who lives in 204, fixing Room 207.

0. **Non-resident lock sheet** (`Lock`, `LockDark`): the Room tab shows **Edit room** to everyone. For non-residents it opens "Only residents of Anjani Residency can fix room layouts" / "Stay here to help others see the real room.", with **Book a bed** (red), **See beds** and "Already staying here? Ask your owner for your invite code."

1. **Resident, any room in their hostel** (`Main`): Room 207's layout with **Edit room**, and "Residents of Anjani Residency can see and fix every room here." Women's PG floor privacy still applies to outsiders.
2. **Suggestion editor** (`Edit`, `EditDark`): dark banner "Only you see this until you send it", the room map with the moved item outlined in red, the selection line with nudge arrows, Turn / Reset / Undo / Redo, Status (working / not working), room size, "Checks before sending", and "Send to owner".
3. **A check fails** (`EditCheck`): "Bed A has a resident · it can’t be deleted"; Send is off and a toast explains why.
4. **Send sheet** (`Send`): a change summary, an optional note for the owner, "Tenants never see who sent it", and Send.
5. **After sending** (`After`, tweak): Waiting for owner (Change my suggestion / Withdraw it) · Approved ("Checked by a resident · 2 Oct") · Not approved (owner's reason, Edit my room again).
6. **Tenant badge** (`Checked`): "Checked by a resident · 2 Oct" on the Room tab; the resident's name is never shown.
7. **Owner push** (`Push`): "Rahul (lives in 204) suggested a fix for Room 207".
8. **Owner Today card** (`Today`): "Layout fix for Room 207", from "Rahul V. · lives in 204-B" with the note and "Compare and decide".
9. **Compare** (`Compare`, `CompareDark`): Now v1 | Suggested, side by side, changes outlined in red, "What changed", the resident's name and note (owner only), then Approve & publish / Reject.
10. **Reject sheet** (`Reject`): an optional reason with chips, "The current layout stays live".
11. **Approved** (`Approved`): "Live for tenants", v2 "fix by a resident", v1 kept in history, the tenant badge, and "Undo publish".
12. **Team console, Layout fixes** (`Console`, `ConsoleDark`): a new nav item; a table of pending fixes, oldest first, with "Owner silent" past 7 days; a detail pane with the compare and Approve & publish / Reject / Remind the owner on WhatsApp.

**v1 additions (designed 2026-10-02):**
- `Try`: a visitor in **try mode** gets the full editor with a grey "Try mode · play freely, nothing is saved" strip. Only the outlined **Send · residents only** button is locked, and it opens the `Lock` sheet. Leaving discards the try.
- `QuickFix`: tap an item, then pick **Wrong place / Missing / Broken / Not in this room**, add an optional word and an optional photo (camera button), and send ("Send: AC unit is broken"). "Bigger change? … the editor."
- `Send` now has **1 photo (optional)**, "Only Srinivas and the Hostelzy team see it". The owner's `Compare` shows the photo.
- The trust badge reads **"Checked by 3 residents · 2 Oct"** on `Checked` and `Approved` (N = different residents with approved fixes in 6 months).
- `Limit`: "You have 3 fixes waiting at Anjani Residency", listing the waiting ones with "Keep my draft for later".
- `Mute`: the owner taps "Mute Rahul’s suggestions" on `Compare`, then confirms in a sheet. The resident sees "Suggestions are off for this hostel"; unmuting is under Manage → Residents.
- `Today` also shows a **Broken** quick fix as a repair card ("Broken: AC unit, Room 207" · Start work / Not broken).

Not designed: a reward for approved fixes (the founder decides; until then, the badge only).

## Backend
- `layout_suggestions` (id, hostel_id, room_id, author_id, layout jsonb, note, status
  pending/approved/rejected, reason, created_at, decided_by, decided_at).
- RLS: insert/update own pending row only if the author has an active stay in that hostel; owner/staff
  of the hostel and the team read and decide. Approve = server function that copies the layout into
  `layouts` and keeps the old version.
- Push to the owner on new suggestion; push to the resident on decision.

## v1 additions (Ideas chat, 2026-10-02, founder delegated: "keep going, no approval needed")
1. **Visitor try mode**: non-residents can open the editor and move things around (nothing saved
   to the server); only **Send** is locked, and tapping it shows the lock sheet. Leaving the editor
   discards the try.
2. **Quick fixes**: tap any item → "Wrong place" / "Missing" / "Broken" / "Not in this room" →
   Send. The full editor stays for bigger changes. "Broken" items also show on the owner's Today as
   a maintenance item.
3. **Optional photo**: 1 photo per suggestion (Storage, same rules as hostel photos; visible only to
   the owner and team).
4. **Trust badge**: "Checked by N residents · <date>" on the room and hostel page, where N counts
   approved suggestions from different residents in the last 6 months.
5. **Spam limit**: max 3 pending suggestions per resident per hostel; the owner can mute a resident's
   suggestions.

Later (v2): "Share my room" image card for WhatsApp/Instagram.
Still the founder's call: Stay Rewards credits for approved fixes (money). Default: none.

## Open questions (Ideas chat decides unless the founder says otherwise)
- Reward for an approved fix (Stay Rewards credits)? Credits are money-like, so **founder decides**.
  Until then: no reward, just the "Checked by a resident" badge.

## Build

**Built · 2026-10-02** (branch `feature/f19-layout-fixes`, stacked on the S-series PRs).

**Resident**
- **Home:** a new "Room layouts" row opens their own room's layout (board 1). The room chips switch to any room in their hostel.
- **Edit room** opens the owner's editor in suggestion mode (boards 2 and 3):
  - Dark banner: "Only you see this until you send it".
  - Move with drag or the nudge arrows; Turn, Reset, Undo, Redo.
  - Working / Not working (on the draft only); room size ±1 ft.
  - Checks before sending. "Bed A has a resident · it can’t be deleted" turns Send off.
- **Draft:** stays on this phone, and survives restarts.
- **Send** (board 4) lists what changed, then takes an optional note and Send.
- **After sending** (board 5), the room shows one of:
  - "Waiting for <owner>", with Change my suggestion / Withdraw it;
  - Approved, with Done;
  - Not approved: the reason, then Edit room again / Talk to <owner> on WhatsApp.
- **Limit:** 3 open fixes per hostel is the most (board 3c). A new fix for the same room replaces the old one.

**Everyone else**
- The Room tab's bottom bar has **Edit room**; Compare beds moved to a chip.
- For non-residents, Edit room opens the lock sheet (board 0): Book a bed / See beds / "Ask your owner for your invite code."

**Owner**
- **Today:** "Layout fixes from residents" cards (board 8).
- **Compare** (board 9): Now vN | Suggested side by side, with changes outlined in red. "What changed" lists them. Below: the resident's name and note (owner only), then Approve & publish / Reject.
- **Reject** sheet (board 10): reason chips plus text.
- **Approved** (board 11): Live for tenants, the versions, the tenant badge, and Undo publish.

**Tenants**
- The Room tab shows "Checked by a resident · 2 Oct", or "Checked by N residents". Names are never shown.

**Team console** (board 12)
- New "Layout fixes" nav item, listing waiting fixes oldest first. Fixes waiting 7 days or more show "Owner silent".
- Detail shows what changed, the note, Approve & publish / Reject (only after 7 days), and "Remind <owner> on WhatsApp".

**Server:** migration `20261002160000_f19_layout_fixes.sql`, which adds:
- tables `layout_fixes` and `layout_history`;
- functions:
  - `send_layout_fix`: confirmed residents only, checks the layout, max 3 open, pushes the owner;
  - `withdraw_layout_fix`;
  - `decide_layout_fix`: staff, or the team after 7 days; approve publishes and keeps the old version in history; pushes the resident;
  - `publish_layout`: owners publish their own edits on the server (DECISIONS 2026-10-02, F18);
  - `undo_layout_publish`;
  - `layout_checks()`: public counts for the badge;
- `layout_fixes` in Realtime.

Tests: `supabase/tests/layoutfix_test.sql`; flow tests "F19: …" (2); console logic test.

### v1 extras · Built · 2026-10-02 (branch `feature/f19-extras`)
- **Try mode (`Try`):** a visitor's Edit room opens the full editor with "Try mode · play freely, nothing is saved". Only the outlined **Send · residents only** button is locked; it opens the `Lock` sheet. Leaving discards the try, and no draft is kept.
- **Quick fix (`QuickFix`):** on their room screen a resident taps an item (fan, AC, window, door, washroom) and picks one of:
  - Wrong place / Missing / Broken / Not in this room
  - then adds an optional word and an optional photo, and sends ("Send: AC unit is broken").
  - "Bigger change? … the editor" stays.
  - Quick fixes count toward the limit of 3 waiting. A quick fix and a layout fix for the same room can both wait.
- **Repairs:** a **Broken** quick fix goes to the owner's Today as a repair card: "Broken: AC unit, Room 207" with the resident's word and the photo, then **Start work** / **Not broken**. The resident gets a push either way.
  - Other quick fixes show as "Quick fix: Window is in the wrong place, Room 207" with **Got it** / **Not right**. Approving one changes no layout; the owner edits the room themselves.
- **Photo:** one photo, optional, on the Send sheet and on a quick fix. "Only <owner> and the Hostelzy team see it."
  - It's stored in the private `fix-photos` bucket under `<hostel>/<user>/…`. The uploader, the hostel's staff and the team can read it; the app and the console use signed links.
  - Compare shows it.
- **Mute (`Mute`):**
  - Compare has "Mute <name>’s suggestions", which opens a confirm sheet.
  - Muting closes that resident's waiting fixes. From then on they see "Suggestions are off for this hostel", and Edit room and quick fixes are off for them.
  - Unmute is under Manage → Residents → "Layout suggestions off" → Turn on.
- **Team console:** Layout fixes shows a quick fix as one line ("Broken: AC unit") plus the photo.
- **Server (`20261002190000_f19_extras.sql`, FOUNDER-TODO 4q):**
  - `layout_fixes` gets `kind`, `issue`, `item`, `photo` and `repair`.
  - New: `send_quick_fix`, `set_repair`, `mute_fix_author` / `unmute_fix_author`, and the table `layout_fix_mutes`.
  - `send_layout_fix` takes the photo; `decide_layout_fix` doesn't touch the layout for quick fixes.
  - New bucket `fix-photos`, with policies.
  - Tests: `supabase/tests/fixextras_test.sql`; flow tests in `test/fix_extras_test.dart` (3) plus the updated F19 test (try mode).
- **Still the founder's call:** rewards for approved fixes. There are none.
