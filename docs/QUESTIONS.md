# Questions the hub answered itself (founder's delegation, 2026-10-18)

Founder, 2026-10-18: "You should never require my input… If there is any decision, take your own decisions and put them in
DECISIONS.md. If there are any questions, answer them yourself and put them in QUESTIONS.md. Never ask me anything until the
entire build is done." Every answer below is the hub's; the founder can change any of them after testing. ₹ = money.

| # | Question | Hub's answer | Where it lands |
|---|---|---|---|
| Q-F28-1 | Use Google Places API (needs the founder's card)? | Yes, as the one-time secret `GOOGLE_PLACES_KEY`; the app and the import workflow work without it until it exists | F28 Part 3 |
| Q-F28-2 | Show a rent on listed hostels only after a human confirmed it? | Yes. "Rent on request" otherwise and after 60 days without confirmation | F28 Part 4 |
| Q-F28-3 | Verified-only as a switch in Filters or a chip in the row? | Switch in Filters (the row stays Near me · Price · Filters, founder's F26 wish) | F28 Part 1 |
| Q-F28-4 ₹ | Who calls owners and what are they paid? | Founder + partners; partners ₹20 per listed hostel after the team check (same ₹20 as the hold pay) | F28 Part 2 |
| Q-F28-5 ₹ | Payout to a resident who added their hostel, and the cap? | ₹200 (founder's number) once the hostel goes live; ₹2,000/month cap for ₹200 + ₹20 rewards together, queued to next month beyond it | F28 Part 2 |
| Q-F28-6 | What counts as a duplicate? | Same owner phone, or same name within 150 m | F28 Part 2 |
| Q-F28-7 | Where do partners work? | In the app's Add a hostel screen with a partner code; the team makes codes in the console | F28 Part 2 |
| Q-F29-1 | Masked Aadhaar enough for owners? | Yes by default (tenant covers the first 8 digits); an owner can switch on "Full copy needed (police file)" | F29 Part 3 |
| Q-F29-2 | Delete the ID after move-out? | The file is in the owner's Drive, so it is theirs; we drop our pointer at move-out and offer "Delete from my Drive" | F29 Part 3 |
| Q-F29-3 | Any government ID allowed? | Yes, Aadhaar is the default wording | F29 Part 2 |
| Q-F29-4 | Where does the ID go before the owner connects Drive? | Nowhere near Hostelzy: the tenant sends it on WhatsApp to the owner, the owner ticks "ID received" | F29 Part 2 |
| Q-F29-5 | Does the owner still type the rent for a joining tenant? | Only picks the bed and the date; fee and advance are prefilled from the room's rate and the terms | F29 Part 2 |
| Q-F30-1 | 2 or 3 free hostels? | 3 | F30 |
| Q-F30-2 | What stays free for guests? | List, map, prices, filters, UNVERIFIED pages. The wall is on the 4th verified hostel page | F30 |
| Q-F30-3 | Does this break the 2026-10-05 "free for everyone" rule? | It changes it: no hold is ever needed; a sign-in is asked after 3 hostels. Recorded in DECISIONS | F30 |
| Q-PROC-1 | Prototype-first for this build? | Suspended for this run: the founder tests the final APK. Build merges when `tools/check.sh` is green; the hub republishes the prototype at the end | DECISIONS |
| Q-PROC-2 | Which chats run? | Build and Design only; Marketing/Finance/Brand not created (the poster is built by Build from the brand guide) | HUB.md |
| Q-PROC-3 | Order of work? | Waves 1–4 in `docs/IDEAS.md`; each wave is one PR to main (APK auto) | IDEAS.md |
| Q-FIN-2..9 | Finance questions Q2–Q9 (rewards cap, founding price, partner pay, guarantees…) | Planned with the **recommended** answers in `docs/finance/plan.md` §0; nothing is promised to anyone until the founder confirms | finance/plan.md |
