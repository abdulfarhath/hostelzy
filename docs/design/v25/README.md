# F28 boards (Design 2, 2026-10-18) · on main canvas v24

Spec: `docs/features/F28-listed-hostels-import.md` ("Screens" + "Design"). Base: main canvas v24
(`docs/design/main-canvas/project/canvas.json`, 472 files, branch `design/f26-merge` @ 09c1c65).
Generator: `scripts/f28.py` (run from anywhere; reads `main-canvas/project`, writes `project/` + `parts/f28.json`).

`parts/f28.json` = `{"boards": {file: {x, y, w, h, title}}, "order": [files], ...}`. New boards sit in **one new row**
at y = 57907 (max y 56707 + 1200), 80 px apart; variants and dark boards 120 px below their main board.
`row_note.f28` is a title note for the row (y − 400). The original Design chat assembles `canvas.json`.

## New files (20) · 4 counted + 14 variants + 2 dark
| Board | File | Position |
|---|---|---|
| **[S92] addHostel** · Add a hostel (light) | `f28-addHostel.dc.html` | row |
| [dark] addHostel | `f28-addHostel-dark.dc.html` | under S92 |
| [variant of S92] partner: code typed once, rent range, ₹20 | `f28-addHostelPartner.dc.html` | under S92 (next slot) |
| **[S93] myAdd** · Your hostel on Hostelzy (Added ✓, Send to your owner) | `f28-myAdd.dc.html` | row |
| [dark] myAdd | `f28-myAdd-dark.dc.html` | under S93 |
| [variant of S93] Owner asked · Owner agreed (UPI asked once) · Verified · Paid · Still waiting (60 days) · Queued (₹2,000 cap) | `f28-myAddAsked / Agreed / Verified / Paid / Waiting / Queued.dc.html` | under S93, 6 slots |
| **[W8] app/list/** · List your PG on Hostelzy, free (390×1360) | `f28-wList.dc.html` | row |
| [variant of W8] sent: "We’ll call you within 2 days" | `f28-wListSent.dc.html` | under W8 |
| **[W9] app/list/poster.html** · A4 794×1123, QR to app/list/ | `f28-wPoster.dc.html` | row |
| [variant of S8] explore: first-visit hint, verified then listed, end row "Can’t find your PG? Add it" | `f28-explore.dc.html` | row |
| [variant of S22] rewards: ₹200 hostel verified / ₹20 partner rows | `f28-rewards.dc.html` | row |
| [variant of C14] Listed › To call (call script, List / Not a PG / Call later, Export CSV) | `f28-c14ToCall.dc.html` | row |
| [variant of C14] Listed › To refresh (Rent confirmed today / Closed) | `f28-c14ToRefresh.dc.html` | row |
| [variant of C14] Listed › Partners (add partner, ₹ due, Active) | `f28-c14Partners.dc.html` | row |
| [variant of C15] Claims: "added by Ravi T. (resident) · owner phone matches ✓" | `f28-c15.dc.html` | row |

## Updated in place (4, same file names; `parts/f28.json` keeps their current x/y)
| Board | File | Change |
|---|---|---|
| [H1] filters sheet | `r-filters.dc.html` | **Verified only** switch (off) under Food included |
| [S79] me | `me.dc.html` | row **Add a hostel** (becomes "Your hostel" → S93 once one exists) |
| [T20] rStay not yet | `w3-stayNotYet.dc.html` | **Add my hostel** button in the dashed box |
| [C14] console Listed | `f26-c14.dc.html` | segment row Listed · To call · To refresh · Partners, Export CSV, Source column, "confirmed <date>" under the rent |

Counts after merge: 179 + 2 (S92, S93) = **181 counted**, +14 variants, +2 dark; 472 + 20 = **492 files** (limit 512).
Not drawn (not in the Design section): S9 map with the switch, A5 poster, the tenant-side T? exploreEmpty entry point.

Note for SCREENS: the canvas already has a board titled `[W8] delete-account/` (`wDel.dc.html`); the spec fixes
**W8 = app/list/** and **W9 = poster**. Build/hub to renumber the delete-account page when SCREENS.md §5 is updated.

**Design approved** (Design 2, 2026-10-18).
