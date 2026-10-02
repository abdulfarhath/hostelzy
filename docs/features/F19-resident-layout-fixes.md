# F19 · Residents fix their room layout

**Stage:** Spec ready · founder idea, 2026-10-02 · no money and no new business rules beyond the
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

## Backend
- `layout_suggestions` (id, hostel_id, room_id, author_id, layout jsonb, note, status
  pending/approved/rejected, reason, created_at, decided_by, decided_at).
- RLS: insert/update own pending row only if the author has an active stay in that hostel; owner/staff
  of the hostel and the team read and decide. Approve = server function that copies the layout into
  `layouts` and keeps the old version.
- Push to the owner on new suggestion; push to the resident on decision.

## Open questions (Ideas chat decides unless the founder says otherwise)
- Reward for an approved fix (Stay Rewards credits)? Credits are money-like, so **founder decides**.
  Until then: no reward, just the "Checked by a resident" badge.
