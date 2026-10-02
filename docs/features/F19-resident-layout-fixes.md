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
Phone boards 390×844 (light; dark copies at the end of rows); console 1440×900. Same look as the owner layout editor (aLayout).

1. **Resident, My room** (`Main`): their own room's layout only, with "Edit my room". Women's PG privacy: never the floor.
2. **Suggestion editor** (`Edit`, `EditDark`): dark banner "Only you see this until you send it", the room map with the moved item outlined in red, the selection line with nudge arrows, Turn / Reset / Undo / Redo, Status (working / not working), room size, "Checks before sending", and "Send to owner".
3. **A check fails** (`EditCheck`): "Bed A has a resident · it can’t be deleted"; Send is off and a toast explains why.
4. **Send sheet** (`Send`): a change summary, an optional note for the owner, "Tenants never see who sent it", and Send.
5. **After sending** (`After`, tweak): Waiting for owner (Change my suggestion / Withdraw it) · Approved ("Checked by a resident · 2 Oct") · Not approved (owner's reason, Edit my room again).
6. **Tenant badge** (`Checked`): "Checked by a resident · 2 Oct" on the Room tab; the resident's name is never shown.
7. **Owner push** (`Push`): "Rahul (Room 204) suggested a layout fix".
8. **Owner Today card** (`Today`): "Layout fix from Room 204" with the note and "Compare and decide".
9. **Compare** (`Compare`, `CompareDark`): Now v1 | Suggested, side by side, changes outlined in red, "What changed", the resident's name and note (owner only), then Approve & publish / Reject.
10. **Reject sheet** (`Reject`): an optional reason with chips, "The current layout stays live".
11. **Approved** (`Approved`): "Live for tenants", v2 "fix by a resident", v1 kept in history, the tenant badge, and "Undo publish".
12. **Team console, Layout fixes** (`Console`, `ConsoleDark`): a new nav item; a table of pending fixes, oldest first, with "Owner silent" past 7 days; a detail pane with the compare and Approve & publish / Reject / Remind the owner on WhatsApp.

Not designed: a reward for approved fixes (the founder decides; until then, the badge only).

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
