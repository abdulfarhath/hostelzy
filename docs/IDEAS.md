# Ideas register (ATA-100 style numbering: chapter-section-subject)

Founder asked 2026-10-18: "What are all our ideas? What are all we gonna build now?" One row per idea, numbered like an
aircraft manual (chapter = feature, section = part). Status: 🟢 Liked, waiting for "spec it" · 🟡 Open question · ⏸ Later ·
🔴 Dropped · 🔨 Building · ✅ Built. **2026-10-18 06:30: the founder said "start designing and building everything".** Waves 1–4 below are in progress; specs: F28, F29, F30.

| No. | Idea | Who does it | Depends on | Status |
|---|---|---|---|---|
| **28-00-00** | **Get every Hyderabad hostel in (F28)** | | | |
| 28-10-00 | Verified-only switch in Filters; verified cards first, listed after | Design + Build | — | 🟢 |
| 28-20-00 | Places API discovery: hidden drafts per area (name, pin, phone, photo) | Build script | Founder's card on Google Cloud | 🟢 |
| 28-21-00 | Console › Listed › Import queue: call, type rent range, tap List | Build | 28-20 | 🟢 |
| 28-30-00 | Tenant adds their own PG: owner phone required, paid only when verified, tenant drives it | Design + Build | — | 🟢 |
| 28-31-00 | Payout amount (~₹200) and its monthly cap | Founder + Finance | — | 🟡 |
| 28-40-00 | Partner walk: "Add hostel in 60 s", ₹20 per listed hostel | Build (same screen as 28-30) + Finance | 28-30 | 🟢 |
| 28-50-00 | Owner self-serve link `app/list` + QR posters | Build + Marketing | — | 🟢 |
| 28-60-00 | WhatsApp outreach to Places phones from a separate SIM (open-source tool) | Founder; hub writes the sender | 28-20 | 🟢 |
| 28-70-00 | Public ads as leads (Facebook / Telegram / college boards), a human calls | Partner | — | 🟢 |
| 28-80-00 | OpenStreetMap pins as a supplement | Build script | — | 🟢 |
| 28-90-00 | Freshness: monthly "still running? rent same?"; 60 days silent → "Rent on request" | Build | 28-60 | 🟢 |
| 28-91-00 | College ambassadors | Marketing | — | ⏸ Last |
| 28-92-00 | GHMC lodging licences | — | — | 🔴 Dropped |
| **29-00-00** | **Owner does less typing (F29)** | | | |
| 29-10-00 | "Ask to join": owner taps, WhatsApp link from the owner's number, tenant fills name + ID + move-in, owner approves | Design + Build | — | 🟢 |
| 29-20-00 | ID photo goes to the owner's Google Drive; Hostelzy keeps only a pointer; masked by default | Build | Drive scope on the consent screen (founder, 5 min) | 🟢 |
| 29-21-00 | Show the ID in-app via a short Drive link | Build | 29-20 | 🟢 optional |
| 29-22-00 | OneDrive / Outlook | Build | 29-20 | ⏸ v2 |
| 29-23-00 | Zero-tech fallback: "ID received ✓" tick | Build | — | 🟢 |
| 29-30-00 | Call · WhatsApp · Notify on every resident row (Rent + Residents), text follows status | Design + Build | — | 🟢 |
| **30-00-00** | **Guests see 3 hostels, then sign in (F30)** | | | |
| 30-10-00 | Count hostel pages opened per device; 4th → "Sign in to see all N hostels, free" | Design + Build | — | 🟢 |
| 30-11-00 | List, map, prices stay free; shared links count | Build | 30-10 | 🟡 founder yes/no |
| 30-12-00 | Replaces the 2026-10-05 "free for everyone" rule (sign-in only, never a hold) | Hub → DECISIONS | founder approval | 🟡 |
| **90-00-00** | **Older ideas from the first prototype (not planned)** | | | |
| 90-10-00 | Compare hostels side by side | — | — | ⏸ |
| 90-20-00 | "Make an offer" on rent | — | — | ⏸ |
| 90-30-00 | Safety tab, SOS / emergency | — | — | ⏸ |
| 90-40-00 | Move-in handover checklist | — | — | ⏸ |
| 90-50-00 | Parent view of a stay | — | — | ⏸ |
| 90-60-00 | Owner staff, mess headcount, expenses, P&L | — | 27 Save food gives the headcount | ⏸ |
| 90-70-00 | Chains of hostels (one owner, many) | — | — | ⏸ |
| 90-80-00 | Bed-level pricing | — | — | ⏸ |
| 90-90-00 | Room notice board | — | — | ⏸ |

## Built and waiting on the founder (not ideas any more)
| No. | Item | Founder step |
|---|---|---|
| 26-00-00 | F26 founder review (21 items + 12 reverts), apk-105 | Test the APK · run the SQL once |
| 27-00-00 | F27 Save food + 6 extras, apk-105 | Same SQL run |
| 00-10-00 | Supabase access token expired | Re-create it (FOUNDER-TODO 0b) |

## Hub's proposed build order (when the founder says "spec it")
| Wave | What | Why first |
|---|---|---|
| 1 | 28-10 Verified filter · 29-30 Contact buttons for all · 30-10 Guest limit | Small, one screen each, no SQL or keys; ships in one PR + prototype |
| 2 | 28-30 Tenant adds PG · 29-10 Ask to join (one shared "join / add" flow) | Both are "a link from WhatsApp opens a short form"; one design, two uses |
| 3 | 28-20/21 Places discovery + Import queue · 28-50 Owner link + posters · 28-60 sender script | Needs the founder's card; fills the map while 2 runs |
| 4 | 29-20 Drive storage for IDs · 28-90 Freshness · 28-80 OSM | After owners are using 29-10 |
