# F31 · No explanations anywhere · everything in priority order

**Stage:** founder rule (2026-10-18) → **Spec final (hub, same day, under the founder's delegation)** → Design 3 + Build 5 (wave 5, last).

**Founder (2026-10-18):** "Near the drink-water notification there is an explanation saying this thing does this thing. Big
apps like Airbnb never give explanations; Zoho never explains any button. I don't need any explanations anywhere. Everything
simple, neat and clean. In the owner's dashboard we show whether food is eaten on the top instead of what matters to the
owner. Everything is displayed by priority: what the user wants to see first. The drink water should be somewhere else, not
on the top. Keep this in mind and add it to the application."

## Rule A · No explanations (every screen, sheet, state, push, web page)
| Remove | Keep |
|---|---|
| Any grey helper sentence under a control, row or card that says what it is for or how it works ("Managers who help you run it", "Who's eating · the count closes 3 h before each meal", "Only if you chat on a different number…", "Owners see this name on your holds…", "Change it any time in Me → Reminders. Runs on this phone.", "A friendly nudge every 30 minutes…", "Talking through Hostelzy keeps your deal and your ₹100 reward.", "Then paste them in the hub chat…") | A subtitle that is a **value or a state**: "12 residents · 2 waiting", "3 active", "+91 98… · not verified", "No UPI yet", "Closes 5:00 pm · 31 eating", dates, counts, prices, "Rent on request", "Not available yet" |
| Intro paragraphs in sheets and empty states; "Why?" lines; tips, coach marks, "i" icons, tooltips; "You can also…" lines; marketing sentences inside the app | One-line irreversible warnings ("This can't be undone."), legal lines required by stores (Terms, delete account), the honest server state when the SQL is not run yet |
| Toasts longer than 6 words; push bodies that explain | Toast = the result ("Saved", "Sent to owner"); push = title + fact + buttons |
| Labels that describe purpose ("Turn on water reminders so you…") | Labels that name the action ("Send on WhatsApp", "Approve", "Add a hostel") |
Empty states: ≤ 6 words + one button. Kickers (small section labels) stay: they are labels, not explanations. Languages: the te/hi
packs drop the same lines.

## Rule B · Priority order (what the user came for, first)
| Screen | Order from the top (hide a block when it is empty or zero) |
|---|---|
| **S36 Owner Today** | Header · **money strip**: "Due today ₹X · Late ₹Y" (tap → Rent) · the needs-you tabs **Holds · Payments · Joining · Fixes** with counts, most urgent first · Fair Play card **only while a case is open** (no longer pinned on top) · This month (beds taken · free · rent pending · occupancy) · **Headcount card** (meals) · Still N free beds? · Confirm layouts · rates card |
| **S23 Resident Home** | Rent card (when due/late; otherwise the small paid line) · Next meal card · Food this week · the 3 actions (notice, swap, fix) · 30-day review card. **No water card, no reminder offer** on Home |
| **Reminders** | Live only in Me › Reminders (and the Notifications switches in Settings). The first-time sheet "Want water reminders?" is **removed** (sheet retired); the glasses/"rings next" card shows only inside Me › Reminders |
| **Owner Manage (S42…)** | Residents · Rates and UPI · Layouts · Meals · Photos · Deals · Complaints · Food menu · House rules · Tenant IDs (F29) · Team · Plan |
| **S79 Me (tenant/resident)** | Name + phone · Your hostel (F28, only when one exists) · Saved & Holds / My stay · Rewards · Reminders · Settings |
| **Settings** | Account · Notifications (switch labels only) · Language · About (version line) · Delete account last |
| Lists everywhere | Most urgent / newest first; "nothing" states are one short line |

## Not changed by F31
Colours, fonts, rules, square corners, the tab bars, screen count (minus the retired offer sheet), any feature's behaviour.
F26 revert #6 (the "₹100 reward" sentence) is superseded by Rule A: the sentence goes. The lock line "Owner's number shows after
you hold a bed." stays (it is a state).

## Screens
| Id | Change |
|---|---|
| S36 `oToday` | Reordered as above; money strip new; Fair Play card conditional |
| S23 `rHome` | No TodayCard / offer; order as above |
| H? `waterOffer` | **Retired** (sheet removed; Build names the id in SCREENS) |
| Manage, Me, Settings, every sheet with a helper line | Copy removed per Rule A; Build lists each removed line in its Build section (screen · old line) |

## Build (wave 5, Build 5 on `feature/w5-clean`, integrated last by Build 1)
Merged to `main` (#155, 2026-10-18), with waves 2–5 on `integration/w2-5`.

1. Audit: grep every `T('…', s: 12|13, c: p.mu` / subtitle / `hint` string in `hostelzy/lib`, `app/`, l10n packs; classify Keep / Remove with the rule above; write the table into this file's Build section **before** editing.
2. Apply Rule A and Rule B. Retire the offer sheet and `maybeOfferReminders()`. Keep tests green; update the texts the tests assert.
3. `tools/check.sh` green; feature file Build section = the full table of removed lines and the new orders; `docs/handover/w5-build.md`; last commit "W5 DONE". No SCREENS/BOARD edits (the integrator does them: retire the offer sheet id, totals).

### Build 5 · audit (2026-10-18, before editing)
Grep: every `T('…', s: 12|13, c: p.mu` (261 lines), every subtitle list, `placeholder:`, every `toastMsg` over 6 words,
push bodies in `supabase/migrations`, the pages in `app/`, the console, the te/hi packs (both empty: nothing to drop).
**Keep** = a value, state, count, date, price, column header, legal line, honest server state, irreversible warning.
**Remove** = the line goes. **Shorten →** = the value stays, the explaining sentence goes. Line numbers are `main` @ 6bf2983.

| Screen · file:line | Line (short) | Decision |
|---|---|---|
| debug overview `ui/shell.dart:177` | "Mobile prototype. Everything is clickable…" | Keep (debug-only page, not in the APK) |
| Reminders `reminders_screens.dart:183` | "Reminders ring in the Android app. You can set them up here." | Remove |
| Reminders `:263` | "Add your own, like medicine at 9 pm or a call home on Sundays." | Remove |
| Reminders `:315` | "Reminders ring from this phone, even offline. Nothing rings outside your awake hours." | Remove |
| Reminders `:311` | Laundry day · "When {owner} sets one" | Shorten → "Not set" |
| Reminders `:119/212/269/292/303/392/573` | times, "Every 30 min · 8 am–10 pm", "Glasses a day", next ring | Keep |
| H41 `waterOffer` `reminders_screens.dart:506-539` | whole sheet + "Change it any time in Me → Reminders. Runs on this phone." | **Sheet retired** (+ `maybeOfferReminders()`, `remOffered`, `acceptOffer`) |
| S23/S8 `TodayCard` `reminders_screens.dart:541` | glasses / "rings next" card on Home and Explore | Removed from Home and Explore (Me › Reminders keeps its own glasses + next-ring rows) |
| Layout map `layout_map.dart:413` | "You get a notification when…" / "Owners draw their rooms and residents correct them…" | Remove |
| Layout map `:581` | "Same price for every bed here" | Shorten → "₹X a month" · "Tap a free bed" stays |
| Layout map `:665` | "Comparing two open beds. Both cost ₹X a month." | Shorten → "Both ₹X a month" |
| Layout map `:441/446/680` | size, version, legend values | Keep |
| Owner layouts `owner_layout_screens.dart:220` | "Last confirmed N days ago. Every 3 months, check that…" | Shorten → "Last confirmed N days ago" |
| Owner layouts `:113/114` | size · version · drawn by | Keep |
| Layout fixes `layout_fixes_screens.dart:47` | "Sent {date} · “note” Tenants still see the current layout." | Shorten → "Sent {date} · “note”" |
| Layout fixes `:61` | "“reason” You can send a new fix any time." | Shorten → "“reason”" |
| Layout fixes `:125` | "You can still see every room here." | Remove |
| Layout fixes `:131` | "You live in X, so you can fix any room here. Tap an item…" | Remove |
| Layout fixes `:137` | "Residents of X can see and fix every room here." | Remove |
| Layout fixes `:275` | "Tap a fan, the AC or a window to mark it working or not." | Remove |
| Layout fixes `:278` | "Wrong size? Change the width or length by 1 ft." | Remove |
| Layout fixes `:340` | "Already staying here? Ask your owner for your invite code." | Remove |
| Layout fixes `:423` | "{owner} sees your name… Tenants never see who sent it." | Remove |
| Layout fixes `:553` | "Only {owner} and the Hostelzy team see it." | Remove |
| Layout fixes `:615` | "Bigger change? Close this and move things in the editor." / "1 photo · only … see it. Tap it to remove." | Shorten → nothing / "1 photo" |
| Layout fixes `:642` | "Unmute any time in Manage → Residents." | Remove |
| Layout fixes `:688` | "All checks pass. Bed IDs and prices don’t change." | Shorten → "All checks pass" |
| Layout fixes `:698` | "1 photo · Sent {date} · only you see who sent it" | Shorten → "1 photo · Sent {date}" |
| Layout fixes `:719` | "Tenants never see that {name} sent it." | Remove |
| Layout fixes `:748` | "The current layout stays live. {name} can send a new fix." | Remove |
| Layout fixes `:115/208/375/469/480/489/592/773` | room line, draft state, "Sent {date}", from, "Published just now" | Keep |
| Admin layout `admin_layout_screen.dart:50` | "Free. The Hostelzy team draws it within 48 hours. Tenants keep seeing…" | Shorten → "Free · within 48 hours" |
| Admin layout `:128` | "v3 live · edits make a new version" | Shorten → "v3 live" (pending variant stays) |
| Admin layout `:242` | "N photos · in the team console" | Shorten → "N photos" |
| Admin layout `:212/221/240` | bed facts, bed state, request values | Keep |
| Team tracker `team_tracker_screens.dart:106` | "The Hostelzy team visits to set it up" | Remove |
| Team tracker `:116` | "Each hostel has its own plan and its own managers." | Remove |
| Team tracker `:249` | "They join by signing in with Google and the code we send on WhatsApp." | Remove |
| Team tracker `:82/147/317` | area · beds · free, stage · next | Keep |
| Team home `team_screens.dart:25` | "For the Hostelzy team only. Owners and tenants don’t need this." | Remove |
| Team home `:32` | "The founder adds team accounts. There is no passcode." | Remove |
| Team home `:46-55` (4 tool subtitles) | "On a visit: basics, rooms…", "Lead → Visited → …", "Draw and move beds…", "Who helps with visits…" | Remove (title rows only) |
| Team home `:96` | "Payments and Fair Play cases are in the team console: {url}" | Shorten → "Team console · farhath.me/hostelzy/app/console" |
| Team mode `:222` | "You edit and publish your own layouts. Want help? The Hostelzy team…" | Remove |
| Refund `refunds_screens.dart:114` | "Check your bank app for the UPI reference above." | Remove |
| Plan `plan_screens.dart:210` | "Scan with any UPI app. The amount and the note REF are filled in." | Shorten → "UPI note REF" |
| Plan `:246` | "{included} Hostelzy never touches your tenants’ money." | Shorten → "{included}" |
| Plan `:372` | "We match the UPI reference with our bank record, usually within a day. No screenshots needed." | Remove |
| Plan `:288/320/322` | invoice ref · amount, price a month, tier note | Keep |
| Reviews `reviews_screens.dart:239` | "Only people who stayed here can review. Owners can reply, not delete." | Remove |
| Reviews `:296` | "Shown as X · verified resident. One review per stay; you can change it later…" | Shorten → "Shown as X · verified resident" |
| Reviews `:373` | "Shown as X · verified stay. Your answer counts toward…" | Shorten → "Shown as X · verified stay" |
| Reviews `:467` | "You can reply once to each review. Reviews can’t be removed; report one only if…" | Remove |
| Ranking `:497` | "Reviews count only from residents with a confirmed stay. Fair Play strikes lower the rank." | Remove |
| Ranking `:499` (`rankFeatured`) | "Hostels with more than 80 beds get a featured spot…" | Remove |
| Reviews `:534` | "Reviews can’t be removed for being low. The Hostelzy team hides a review only if…" | Remove |
| Reviews `:118/120/126/144/149/200/211/235/355/419` | kind · stay, advance state, reply, "Reported", "Report abuse", stats | Keep |
| Rewards `rewards_screens.dart:214` | "{owner} gives you ₹100 off. Hostelzy credits that ₹100 on {owner}’s next invoice." | Remove |
| Rewards `:272` | "Hostelzy checks this from real stays. We don’t share which hostels…" | Remove |
| Rewards `:38-45/108/131` | step values ("₹100 off your next stay, and 2-hour holds", "Trusted tenant badge · first look at new beds"), "Your code X" | Keep |
| Trusted perks `stay_tools_screens.dart:217` | "When a bed turns free, you can hold it 1 hour before everyone else" | Shorten → "1 hour before everyone else" |
| Trusted perks `:218/219` | "Instead of 1 hour", "On your hold request" | Keep |
| Save food `save_food_screens.dart:195` | "Tap a meal to switch between eating and skip. Everything is “eating” unless you skip." | Remove |
| Owner meals `:447` | "Residents can change their answer until then. After it, the answer is locked…" | Remove |
| Owner meals `:497` | "1 skip = 1 plate the kitchen didn’t cook. No ranking of people…" | Remove |
| Food `:121/160/281/303`, `week_table.dart:109` | "Closes at … · N eating", "Skip", "Count closed", "N skipping · cook for M", "From X’s menu" | Keep |
| Amenities `amenities_screens.dart:96` | "Shared by everyone on that floor. {in rooms}" | Shorten → "{in rooms}" only |
| Amenities `:129` | "Nothing listed yet. Add the fridge, RO, washing machine…" | Shorten → "Nothing listed yet" |
| Amenities `:216` | "Tap what isn’t working…" / "Residents can add or fix this list…" | Remove |
| Amenities `:219` | "Residents and {owner} keep this list up to date." | Remove |
| Amenities `:376` | "{item} marked Not working · {date}. Keep it, or correct it." | Shorten → "{item} marked Not working · {date}" |
| Amenities `:421` | "Broken things also show on Today as a repair." | Remove |
| Amenities `:62/405` | "Updated by residents · date", who · when | Keep |
| Sign-in `session_screens.dart:194` | "Type the name owners should see." | Remove |
| Sign-in `:218` | "We’ll check it by SMS later. Until then owners see “not verified”." | Remove (the NOT VERIFIED tag is the state) |
| Role `:361` | "You can switch later in Me." | Remove |
| Owner sign-in `:408` | "Sign in once with it and your PG opens here, set up the way we did it on the visit." | Remove |
| Role `:423` | "Join it with the MGR- code your owner sent you." (under "Manager at a PG?") | Remove (title row stays) |
| Code `:444` (`mgrHint`) | "Manager codes start with MGR. The owner sends it on WhatsApp; it works once, for 7 days." | Remove |
| Scan `:552` | "Allow it in your phone’s Settings → …, or type the code." / "Type the code from the poster instead." | Shorten → "Camera blocked in Settings" (denied) · nothing otherwise |
| Sign-in `:158/196/289/297/490-494` | "Use on this phone only", NOT VERIFIED, "Resend in 0:30", "Change number", Terms line | Keep |
| Where `guest_screens.dart:94` | "The same field is on Explore and on the Map." | Remove |
| Sign-in wall `:125` | "Then your name and phone number. Owners see it as “not verified”." | Remove |
| Language `:181` | "Words not checked yet show in English." | Remove ("(beta)" is the state) |
| Me `me_screen.dart:23` | Settings · "Language, notifications, log out" | Remove subtitle |
| Me `:24` | Help on WhatsApp · "Ask the Hostelzy team" | Remove subtitle |
| Me `:84` | "Looking for a bed, or live in a PG?" / "Live in a PG or run one?" | Remove (Switch role › stays) |
| Me `:20-22/65/95` | refund state, Member / Trusted, reminders summary, phone · not verified, version | Keep |
| Settings `settings_screens.dart:107-111` | the 5 notification subtitles ("When the owner confirms or replies", "3 days before", …) | Remove (switch labels only) |
| Settings `:171` | "Once it’s settled, come back to Settings → Delete account." | Remove |
| Delete account `:208` | "We keep only what the law or the hostel needs, without your name or phone on it." | Remove |
| Delete account `:214` | "You can also ask for deletion on the web: {url}" | Remove |
| Delete account `:189-199` | "This can’t be undone.", Deleted / Kept lists | Keep (irreversible warning + store rule) |
| Notifications `:358` | "Your phone asks next. Change it any time in Settings." | Remove |
| Name `:412` | "Owners see this name on your holds, enquiries and stay." | Remove |
| WhatsApp number `:434` | "Only if you chat on a different number… message you here." | Remove |
| Settings `:45/135/258/384` | row values, version line, account email, version needed | Keep |
| Owner Manage `owner_manage_screen.dart:257` | "Today is highlighted. Tap a day to edit it. Residents and tenants see the same week." | Remove |
| Owner Manage `:297` | "Counts only. Hostelzy never shows who said what." | Remove |
| Owner Manage `:301` (`menuEmpty`) | "No menu yet. Tenants see “Menu not added yet” on your hostel page until you save one." | Shorten → "No menu yet" |
| Owner Manage `:381` | "Tenants see these under House rules › on your hostel page." | Remove |
| Owner Manage `:412` | Food menu · "Breakfast, lunch and dinner, by day" | Shorten → "None yet" / "This week" |
| Owner Manage `:414` | Meals · "Who’s eating · the count closes N h before each meal" | Shorten → "Closes N h before each meal" |
| Owner Manage `:417` | Photos · "Your hostel’s photos" | Shorten → "None yet" |
| Owner Manage `:423` | Team · "Managers who help you run it" | Shorten → "N managers" / "None yet" |
| Owner Manage `:665` | "Not set. Residents’ meal reminders use the usual times: breakfast 7:30…" | Shorten → "Not set · 7:30 · 12:30 · 8:00" |
| Owner Manage `:682` | "Residents’ meal reminders ring at the start time." | Remove |
| Owner Manage `:135/144/243/575` + other row subtitles | counts, "None open", "Trial · N days left", bed · since · ref | Keep |
| Deals `owner_deals.dart:90` | "Always on: exit rules written at booking. Costs you nothing." | Shorten → "Always on · ₹0" |
| Deals `:75/76` | deal terms and cost | Keep |
| Rates `rate_card.dart:94` | "Green: ₹X a month off with your Hostelzy deal, {target}." / "Hostelzy price is the walk-in price until you add a monthly deal." | Shorten → "₹X a month off · {target}" / "No monthly deal yet" |
| Rates `:161` | "An AC room needs an AC unit in its layout. If a room’s layout has none…" | Remove |
| Rates `:36/144` | column headers, sharing · walk-in | Keep |
| Owner Today `owner_today_screen.dart:178` | "N of M beds have a resident. Holds don’t count." | Shorten → "N of M beds" |
| Owner Today `:392` | "New holds, payments and fixes show up here." | Remove (empty state = "Nothing needs you now") |
| Owner Today `:55/58` (hold note) | "Code HZ-1 · placed in the Hostelzy app" / "Placed from the Hostelzy app" | Shorten → "Code HZ-1" / nothing |
| Owner Today `:308` | New layout · "Drawn by Hostelzy · check it, then publish" | Shorten → "Drawn by Hostelzy" |
| Owner Today `:127/419` other item subtitles | kpi labels, who · what · UPI ref, bed · last day, refund due | Keep |
| Fair Play card `:462` | "{title}. 47 h left to explain or fix it." / "{title}. Your reply is with the founder." | Shorten → "{title} · 47 h left" / "{title} · with the founder" |
| Owner beds `owner_beds_screen.dart:39` | "Tap a bed for its bed sheet. Tap a room number for its layout." | Remove |
| Owner beds `:50` | "Layouts › to create or copy one." | Shorten → "Layouts ›" |
| Map `map_screen.dart:171` | "We add hostels area by area, after we visit each one. Try a nearby area." | Remove (title "No hostels here yet" stays) |
| Fair Play rules `fair_play_screens.dart:166` | "You always get 48 hours to explain. Fix a mistake in that time…" | Remove |
| Fair Play rules `:157` | the 4 rule bodies (`fairRules`) | Keep (the rules are the content) |
| Report `:302` | "The owner never sees your name. We check our own records first…" | Remove |
| Case `:360` | "What happened, from Hostelzy records:" | Shorten → kicker "From Hostelzy records" |
| Case `:399` | "Shown only to you and the Hostelzy team." | Remove |
| Case `:424` | "You have N strikes. A mistake fixed within 48 hours closes the case…" | Shorten → "You have N strikes" |
| Strike `:511` | "Strikes come from a decided case, or from 3 fixes in 6 months…" | Remove |
| Strike `:502` ("What changes" subtitles) | "For 30 days", "No new enquiries, holds or bookings"… | Keep (consequences = state) |
| Holds `holds_screens.dart:108` | "Your hold on bed X ended. One tap helps us keep owners fair. If you joined, your ₹100 Member reward…" | Shorten → "Your hold on bed X ended." |
| Holds `:118` | "Only the Hostelzy team sees your answer, never the owner." | Remove |
| Holds `:77/83/312` | hostel · rent · ref, "left", demo button | Keep |
| Building `building_view.dart:202` | "Shared things sit on top of each floor. Tap a floor to see if they’re working." | Remove |
| Picker `picker_screen.dart:213` | "Hostelzy never shows gates, CCTV, exits or residents’ names on any plan." | Remove |
| Picker / building `:145/268/369`, `:100-181` | floor · spot, "Tap a free bed", sharing · rent, floor counts | Keep |
| Hold sheet `holds_sheets.dart:70/72` | option subtitles "Go and see it first" / "Sure already" | Remove (ticks stay: "₹0 now", "Bed kept for you", …) |
| Hold sheet `:88` | "You pay by UPI straight to X. Hostelzy never holds your money." / "If X doesn’t keep it within the hour, the bed is free again. You pay nothing…" | Remove |
| WhatsApp sheet `:134` | "Nothing is sent until you press send in WhatsApp." | Remove |
| Hold sheet `:79` | bed · rent · sharing · advance · back | Keep |
| Resident Home `resident_screens.dart:68` | "Paid. Thank you." | Shorten → "Paid" |
| Resident Home `:114` | "How is your stay so far? Rate X for other tenants." | Shorten → "How is your stay so far?" |
| Resident Home `:140` | "{owner} hasn’t put the menu on Hostelzy yet." | Shorten → "No menu yet" |
| Complaint sheet `help_sheets.dart:59` | "{owner} sees it in Hostelzy. You’ll see here when it’s fixed." | Remove |
| Add resident `residents_sheets.dart:136` | "Only until X goes live. After that, the Hostelzy team marks it." | Remove |
| Add resident `:159` | "{who} confirms by joining with your invite code. They count as a resident once they confirm." | Remove |
| Add resident `:110/152` | date, rent · due at move-in | Keep |
| Hostel page `hostel_screen.dart:287` | "Same price for every bed of a type. Food included. Electricity extra, by meter." | Shorten → "Food included · Electricity extra, by meter" |
| Hostel page `:484` | "Big hostels open the building on its own page, so this page stays short." | Remove |
| Hostel page `:133/207/266/351/352/474` | "Beds and prices checked by Hostelzy · date", advance · back, free counts | Keep |
| Unverified `unverified_screen.dart:150` | "Expected, not confirmed. The owner hasn’t joined Hostelzy yet." | Shorten → "Expected, not confirmed" |
| Unverified `:220` | "Only the Hostelzy team sees this." | Remove |
| Unverified `:139` | "Listed by the Hostelzy team · not checked yet" | Keep |
| Pay `payments_sheets.dart:54` | shield line (spans) "Hostelzy never holds your money…" | Remove |
| Pay `:97` | "Hostelzy never holds your money. It goes straight to the owner." | Remove |
| Pay `:125` | "12 digits, in your UPI app under the payment" | Remove |
| UPI `:287` | "Advances and rent go straight here. Hostelzy never holds the money; you confirm…" | Remove |
| UPI `:292` | "Pays you ₹1 from your own phone to check it works." | Remove |
| Rent `rent_pay_screen.dart:140` | "You pay {owner} directly. Hostelzy never holds the money." | Remove |
| Free beds card `onboarding_cards.dart:76` | "… Fresh beds rank higher." | Shorten → "Not confirmed yet" / "Last confirmed N days ago" |
| Free beds card `:98` | "Not confirmed for N days: tenants see “Availability not confirmed” and you rank lower." | Shorten → "Not confirmed for N days" |
| Rates card `:127` | "… Tenants see the date you last confirmed them." | Shorten → "Not confirmed yet" / "Last confirmed {date}" |
| Rates card `:148` | "Not confirmed for a month: tenants see “Not confirmed in over a month” on your prices." | Shorten → "Not confirmed for a month" |
| Add hostel `add_hostel_screen.dart:477` | "They upload to this hostel now; the owner can change them later in Manage › Photos." | Remove |
| Add hostel `:545` | "Taken by Hostelzy, in daylight, from the door. Tick each one once it is in the hostel’s Drive folder." | Remove |
| Add hostel `:646` | "The owner adds the rest within 3 days." | Remove |
| Add hostel `:687` | "Residents here before Hostelzy count as “Joined before Hostelzy”. They confirm…" | Remove |
| Add hostel `:739` | "You can go on and come back: go live needs the owner linked." | Remove |
| Add hostel `:827` | "Goes live with “Visited by Hostelzy · {date}”. The 30-day free trial starts today." | Shorten → "Visited by Hostelzy · {date} · 30-day free trial" |
| Add hostel `:259/284/347/576/665/728/825` | notes, "Has beds", defaults, "Sketch + measurements", phone · bed, "The link works once, for 7 days.", "Optional: N residents added" | Keep |
| Rooms `rooms_screens.dart:28` | "Add or remove rooms and floors. A room with a resident or a hold can’t be removed. Prices come from Manage → Rates." | Remove |
| Team members `:161` | "Visits: add hostels and residents. Layouts: draw rooms. Payments: check UTRs. They show as Active once…" | Remove |
| Rooms `:38/58/143` | "No beds · hidden from tenants", sharing · type · rent, phone · role | Keep |
| Meter `stay_tools_screens.dart:45` | "Type each room’s meter now. We split it between the residents in the room." | Remove |
| Meter `:94` | "Residents see “Electricity · 70 units ÷ 4…” on their rent…" | Remove |
| Laundry `:199` | "Residents who turn on the Laundry reminder get it at 8 pm the evening before." | Remove |
| Meter `:59/78/87/130` | column headers, "N in", values, "Type each room’s meter for {month}" / "{month}: N rooms" | Keep |
| Photos `photos_screens.dart:143` | "Drag to reorder. The first is the cover." / "Drag to reorder." | Remove |
| Photos `:374` | "Photos by the owner" | Keep |
| Placeholders (19) | examples inside empty fields ("e.g. Sri Sai Men’s PG", "Food, water, the owner…") | Keep (an example is a value, not a sentence); `reviews:161` "Thank them, or say what you are fixing" → Remove; `delAcc` "Helps us improve" → Remove |
| Toasts over 6 words (133 `toastMsg` calls) | see the toast table below | Shorten → the result |
| Push bodies (SQL) | see the push table below | Shorten (new migration redefines the functions) |
| Web `app/index.html:15` | "Hostelzy is an Android app for tenants, residents and hostel owners in Hyderabad." | Remove |
| Web `app/index.html:17` | "The test build is an APK file from GitHub. Your phone asks you to allow installs from this source. The Play Store version comes later." | Shorten → "Android APK · test build" |
| Web `app/delete-account/` | whole page | Keep (store-required deletion page) |
| Web `app/r/index.html:19` | "Hostelzy doesn’t take enquiries any more: owners’ numbers show once you hold a bed. Old links and posters still open the app." | Remove (line 15 "Hold a bed in the app to message or call the owner." stays: the lock state) |
| Web `app/j/index.html:18` | "Pay rent by UPI, see the food menu and raise complaints from your phone." | Remove |
| Web `app/j/index.html:20` | "This link has no invite code. Ask your hostel owner for the full link." | Shorten → "This link has no invite code." |
| Web `app/j/index.html:23` | "Then open Hostelzy, sign in and pick I live in a Hostelzy PG. Keep this code…" | Shorten → "In the app: I live in a Hostelzy PG" |
| Console `console.js:56` | "Onboarding, payments, Fair Play and layout help. Only Hostelzy team Google accounts can sign in." | Shorten → "Hostelzy team Google accounts only" |
| Console `:59` | "Not on the team? Use the Hostelzy app instead." | Remove |
| Console `:149` | "The rest (rooms, rates, photos, residents) is done on the visit, in the app’s team mode." | Remove |
| Console `:178` | "No invoices yet. They start when a hostel’s 30-day trial ends." | Shorten → "No invoices yet" |
| Console `:217` | "Photo added. The owner sees it with the case." | Shorten → "Photo added" |
| Console `:299` | "Strikes: 1 warning · 2 deals hidden for 30 days · 3 removed from Hostelzy. 3 fixes within 48 hours in 6 months = 1 warning (counted by the server). No fines." | Shorten → "1 warning · 2 deals hidden 30 days · 3 removed" |
| Console `:305` | "Owners draw and publish their own layouts. When one asks us to draw a room, it shows in Layout help, due within 48 hours." | Remove |
| Console `:335` | "Type the corners clockwise from the top-left, in feet: 0,0 14,0 14,8 10,12 0,12" | Shorten → "0,0 14,0 14,8 10,12 0,12" (the example) |
| Console `:342` | "Type at least 3 corners inside the room." | Shorten → "At least 3 corners" |
| Console `:355` | "The owner’s app places the beds, fans and windows inside these walls; they check it and publish." | Remove |
| Console `:39/242/280` | "Not set up yet…", "Signals show once SQL step 4zf1 has run." | Keep (honest server state) |

### Build 5 · done (2026-10-18, branch `feature/w5-clean`, integrated by Build 1)
Everything in the audit table above is applied, plus the orders below. `flutter analyze` clean, `flutter test` green (see
`docs/handover/w5-build.md` for the check log). No SCREENS/BOARD edits (integrator: retire the sheet below, recount).

**Retired:** App sheet **#41 `waterOffer`** ("Want water reminders?", Shared) and `maybeOfferReminders()` / `acceptOffer()` /
`remOffered` (the `rem.offered` snapshot key is ignored on load). `TodayCard` (glasses / "rings next") is gone from S23 Home and S8
Explore; Me › Reminders keeps its own glasses and next-ring rows. `WaterOfferSheet` and `TodayCard` classes deleted.

**New orders (Rule B)**
| Screen | Order from the top, as built |
|---|---|
| S36 Owner Today | Header · Plan banner (only when the plan is late; unchanged) · **Money strip** `Due today ₹X · Late ₹Y` (tap → Rent; hidden when both are 0; red when anything is late) · **Holds · Payments · Fixes** tabs (Joining comes with Build 2's tab) · **Fair Play card only while a case is open** (strike count folded into its title) · This month (beds taken · free · rent pending · % full) · **Headcount card** · Still N free beds? · Confirm layouts · rates card |
| S23 Resident Home | Header · Rent card ("Paid" when paid) · Next meal card · Food this week · the 3 actions (Pay rent · Raise complaint · Message owner) · 30-day review card ("How is your stay so far?") |
| S8 Explore | No TodayCard, no offer; otherwise unchanged |
| Owner Manage | Residents · Rates and UPI · Room layouts · Meals · Photos · Deals · Complaints · Food menu · House rules · Reviews and ranking (not in the F31 list; kept, see Not in the spec) · Team · Your plan |
| S79 Me | Name + phone · (Your refund, when open) · Stay Rewards · Reminders · Settings · Help on WhatsApp · Log out · Switch role › · version |
| Settings | **Account** (Name · Phone · WhatsApp) · **Notifications** (switch labels only) · **Language** (Language · Look) · **About** (Privacy · Terms · Fair Play rules · Hostelzy team · version line) · Log out · **Delete account last** |

**Money strip rule.** "Due today" = every resident whose rent is `Due` (unpaid, not yet late); "Late" = rent `Overdue`. Both sums
come from the same rows as the Rent tab, so the strip and the tab always agree.

**Toasts shortened (Rule A, ≤ 6 words = the result).** 153 `toastMsg` texts:
| Old | New |
|---|---|
| Awake hours need at least an hour. | Awake hours: at least an hour |
| You can keep $maxMyRems reminders. Delete one first. | Limit: $maxMyRems reminders |
| That’s outside your awake hours ($awakeLabel). Change them under Drink water first. | Outside awake hours ($awakeLabel) |
| Only residents can fix room layouts. Ask your owner for your invite code. | Residents only |
| This room has no layout yet. The owner draws it first. | No layout yet |
| Nothing changed yet. Move things to where they really are. | Nothing changed yet |
| Sent to $owner. You get a notification when they decide. | Sent to $owner |
| Rejected. The current layout stays live. ${f.author.split(' ').first} can send a new fix. | Rejected |
| Back to the earlier version. Tenants see it again. | Back to the earlier version |
| That photo didn’t open. Try another one. | That photo didn’t open |
| Enter the room size in feet (6 to 60). | Room size: 6 to 60 ft |
| ${by.name} is editing this room. Try again when they’re done. | ${by.name} is editing this room |
| $who is editing this room. Try again when they’re done. | $who is editing this room |
| Couldn’t save it. Check your internet and try again. | Couldn’t save. Check your internet. |
| Tap a bed or an item first. | Tap a bed or an item first |
| All ${room.share} beds are placed. A new bed changes the sharing: the owner confirms the price first. | All ${room.share} beds are placed |
| No room left for another bed inside the walls. | No room for another bed |
| Bed $bedId has a resident. It can’t be deleted. | Bed $bedId has a resident |
| Tap an AC, window, door, washroom or pillar to turn it. | Tap an item to turn it |
| Bed ${room.label}-$other is now the upper bunk over ${room.label}-$lower. | ${room.label}-$other is now the upper bunk |
| Thanks. Your layouts are confirmed for the next 3 months. | Layouts confirmed for 3 months |
| Sent to ${hostelById(l.hid).owner}. They check it and publish. | Sent to ${hostelById(l.hid).owner} |
| We’ll tell you when room $label’s layout is ready. | You get a notification when it’s ready |
| Only one free bed in this room. | Only one free bed here |
| Room ${l.room} layout approved. Tenants see it now. | Room ${l.room} layout approved |
| Say what’s different, or add a photo. | Add a note or a photo |
| Couldn’t send it. Check your internet and try again. | Couldn’t send. Check your internet. |
| Sent. The Hostelzy team draws it within 48 hours. You get a notification. | Sent · within 48 hours |
| Add a name and a 10-digit number. | Name and 10-digit number needed |
| Saved. $name shows as Active after the founder adds their Google account and they open team tools. | Saved · $name |
| Invite pending. This demo has no server, so nothing is sent. | Invite pending · sample data |
| Message the Hostelzy team on WhatsApp to book a visit. | Book a visit on WhatsApp |
| Sign in with your Hostelzy team Google account first. | Team Google account needed |
| ${l.name} is live. The 30-day trial starts today. | ${l.name} is live · trial started |
| Notice sent. $stayOwner accepts it in Hostelzy. | Notice sent to $stayOwner |
| Bed ${b.id} is listed as free from ${dayMon(day)}. | Bed ${b.id} free from ${dayMon(day)} |
| UPI reference saved. Hostelzy checks it against the bank record. | UPI reference saved |
| Your first invoice isn’t out yet. You pay once it arrives. | No invoice yet |
| Your owner hasn’t added you yet. Reviews open once you’re a resident here. | Not a resident here yet |
| Tap the stars to rate your stay. | Tap the stars first |
| Review posted as $meShort · verified resident. | Review posted as $meShort |
| Tell us if you got your advance back. | Advance back? Pick one |
| You already replied to this review. Each review gets one reply. | Already replied |
| Pick up to $maxDeals. Remove one first. | Limit: $maxDeals deals |
| Reviews open after 30 days of your stay, on ${dayMon(on)}. | Reviews open on ${dayMon(on)} |
| Sent to the Hostelzy team. They hide it if it breaks the rules. | Sent to the Hostelzy team |
| Code saved. You and $who each get ${fmt(referralReward)} after your first month at a Hostelzy hostel. | Code saved · ${fmt(referralReward)} each |
| Thanks. $stayOwner sees how many said $v, not who. | Saved |
| The count for that meal has closed. Your answer counts from the next meal. | Count closed for that meal |
| The count now closes $hours h before each meal. Residents see the new time. | Closes $hours h before each meal |
| Only residents of this hostel can change this list. | Residents only |
| That’s 20 changes today. Try again tomorrow. | Limit: 20 changes a day |
| Couldn’t save your name. Check your internet and try again. | Couldn’t save. Check your internet. |
| Google sign-in works in the Android app. Use Hostelzy on this phone for now. | Google sign-in: Android app only |
| Mobile numbers start with 6, 7, 8 or 9. | Numbers start with 6, 7, 8 or 9 |
| Notifications allowed. Sign in with Google to get them. | Notifications on · sign in to get them |
| Notifications allowed. This demo has no server, so nothing is sent. | Notifications on · sample data |
| Notifications are off. Turn them on in your phone’s settings → Apps → Hostelzy. | Notifications off in phone settings |
| Saved. Notifications work in the Android app. | Saved |
| Couldn’t turn on notifications for this phone. Check your internet; we’ll try again when you open the app. | Couldn’t turn on notifications |
| To change your number, log out and sign in with the new one. | Log out to change your number |
| Telugu and Hindi come once a native speaker has checked the words. | Telugu and Hindi: not yet |
| Fair Play rules accepted. Welcome to Hostelzy. | Fair Play rules accepted |
| ${c.resident} now shows as came from the app. Case closed, no strike. | Case closed · no strike |
| Write what happened, or fix the resident. | Add your reply or a fix |
| Photos open from the server in the real app. This is sample data. | Photo: sample data |
| Couldn’t open the photo. Check your internet and try again. | Couldn’t open. Check your internet. |
| Couldn’t save your answer. Check your internet and try again. | Couldn’t save. Check your internet. |
| Reports are about a hostel you held a bed at. Hold one first. | Hold a bed there first |
| Report sent to the Hostelzy team. The owner never sees your name. | Report sent |
| Report saved for the Hostelzy team. The owner never sees your name. | Report saved |
| Bed ${hold.bed} has been taken. See other beds. | Bed ${hold.bed} has been taken |
| Couldn’t release it. Check your internet and try again. | Couldn’t release. Check your internet. |
| Sharing isn’t available here. The text is copied. | Copied |
| Message and call the owner after you hold a bed | Hold a bed first |
| That mobile number doesn’t look right (10 digits, 6–9 first). | 10 digits, starting 6 to 9 |
| Add a ${r.share} sharing AC price first. | ${r.share} sharing AC price needed |
| Add a ${r.share} sharing non-AC price first. | ${r.share} sharing non-AC price needed |
| Set a price for ${r.share} sharing ${acDraft![r.n]! ? 'AC' : 'non-AC'} (₹1,000 or more). | ${r.share} sharing price: ₹1,000 or more |
| You can hold ${AppState.maxHolds} beds at a time. Release one in Holds first. | Limit: ${AppState.maxHolds} holds |
| Hold placed on this phone. Tell ${h0.owner} on WhatsApp so they keep the bed. | Hold placed on this phone |
| Bed $bedLabel isn’t on the server. Pull down to refresh and try again. | Bed $bedLabel not on the server |
| Hold confirmed. The tenant sees it in Hostelzy. | Hold confirmed |
| Hold confirmed. Let $first know on WhatsApp. | Hold confirmed |
| This bed isn’t on the server. Pull down to refresh and try again. | Bed not on the server |
| Hold placed. ${h0.owner} sees it in Hostelzy and gets a notification. | Hold placed |
| Your owner hasn’t added you yet. Complaints open once you’re a resident here. | Not a resident here yet |
| Your stay isn’t on Hostelzy yet. Ask $stayOwner to add you. | Stay not on Hostelzy yet |
| $stayOwner hasn’t set your rent on Hostelzy yet. Ask them on WhatsApp. | Rent not set yet |
| This is a sample listing, so it has no real UPI ID. Don’t pay it. | Sample listing · no real UPI |
| Saved. ${h.owner} confirms once they see the money. | Sent to ${h.owner} |
| $c isn’t in this account. Sign in with the account that sent or got it. | $c: another account |
| New code $c. The old link and poster stop working. | New code $c |
| Couldn’t get your invite code. Check your internet. | Couldn’t load. Check your internet. |
| Enter the invite code from your owner, like ANJ-7Q2. | Invite code needed, like ANJ-7Q2 |
| Sign in with Google to join with a code. | Sign in with Google first |
| Invites work in the real Hostelzy app. This is sample data. | Invites: sample data |
| You’re a manager at $h now. Pick “I run a PG” to start. | Manager at $h |
| Asked to join $h. Your owner approves it, then your stay opens here. | Asked to join $h |
| Open your phone camera and point it at the poster. It opens the invite link. | Scan the poster with your camera |
| That QR isn’t a Hostelzy invite. Scan the poster at your PG. | Not a Hostelzy invite |
| This is a sample listing, so there’s no real number yet. | Sample listing · no number |
| Deals can be picked in Manage → Deals once the hostel is live. | Deals: after go-live |
| Add a price for $nrShare sharing ${nrAc ? 'AC' : 'Non-AC'} in Manage → Rates first. | $nrShare sharing ${nrAc ? 'AC' : 'Non-AC'} price needed |
| Floor $floor can’t be removed: room ${blocked.map((r) => r.label).join(', ')} ${blocked.length == 1 ? 'has' : 'have'} a resident or hold. | Room ${blocked.map((r) => r.label).join(', ')}: resident or hold |
| Thanks. Tenants see your free beds as confirmed today. | Free beds confirmed today |
| Thanks. Tenants see your rates as confirmed today. | Rates confirmed today |
| Invite pending. The manager joins by signing in with this number. | Invite pending |
| Pin moved to where you are. Check it sits on the gate. | Pin moved to you |
| Move the map so the pin sits on the gate, or use your location. | Put the pin on the gate |
| Couldn’t save ${r.name}. Check your internet and try again. | Couldn’t save ${r.name} |
| Sample data: the owner shows as linked. | Owner linked · sample data |
| Couldn’t check. Check your internet and try again. | Couldn’t check. Check your internet. |
| ${d.name} is live. The 30-day trial starts today. | ${d.name} is live · trial started |
| ${d.name.trim()} is live. The 30-day trial starts today. | ${d.name.trim()} is live · trial started |
| Room ${x.room}: the reading is lower than last month’s (${grouped(last)}). | Room ${x.room}: lower than ${grouped(last)} |
| Added to $month rent for ${rows.length} room${rows.length == 1 ? '' : 's'}. Residents see their share on their rent. | Added to $month rent · ${rows.length} room${rows.length == 1 ? '' : 's'} |
| We’ll tell you when ${h.name} is verified. | You get a notification when verified |
| Couldn’t save that. Check your internet and try again. | Couldn’t save. Check your internet. |
| Sent. The Hostelzy team will call you on ${phoneSpaced(phone)}. | Sent · we call ${phoneSpaced(phone)} |
| UPI ID saved. Tenants pay you here. | UPI ID saved |
| That file isn’t a photo. Pick another. | Not a photo |
| Photos upload in the real Hostelzy app. This is sample data. | Photos: sample data |
| Couldn’t save the new order. Check your internet. | Couldn’t save. Check your internet. |
| Only the owner adds managers. | Only the owner adds managers |
| Couldn’t make the invite. Check your internet and try again. | Couldn’t invite. Check your internet. |
| Enter your friend’s code, like ASHA-4K7Q. | Code needed, like ASHA-4K7Q |

**Toasts, second pass** (texts inside `? :` ternaries and returned error strings, found by the test run):
| Old | New |
|---|---|
| You have 3 fixes waiting here. Send this one once $owner answers one. | Limit: 3 fixes waiting |
| Only residents of ${hostelById(hid).name} can fix its rooms. | Residents only |
| This layout doesn’t pass the checks. Look at the list above Send. | Fix the checks first |
| Couldn’t send it. Check your internet and try again. | Couldn’t send. Check your internet. |
| Copied to rooms ${same.map((r) => r.label).join(', ')} as new versions for the owner to approve. | Copied to rooms ${same.map((r) => r.label).join(', ')} |
| Accepted. Bed ${m.bed} shows free from ${dayMon(m.lastDay ?? appToday)}. | Accepted · bed ${m.bed} free from ${dayMon(m.lastDay ?? appToday)} |
| Marked ${fmt(r.amt)} refunded. ${r.name.split(' ').first} is asked to confirm. | ${fmt(r.amt)} marked refunded |
| You already reviewed this stay. Open your review to change it. | Already reviewed · open it to change |
| Only residents with a confirmed stay can review. Ask your owner to confirm your stay. | Confirmed residents only |
| You already replied to this review. Each review gets one reply. | Already replied |
| Hostelzy hid this review, so it can’t be changed. | Hidden by Hostelzy |
| This is your review. Change it instead of reporting it. | Your own review |
| That code isn’t valid. Check it with your friend. | Code not valid |
| That’s your own code. Share it with a friend instead. | That’s your own code |
| Codes are for your first stay through Hostelzy. | First Hostelzy stay only |
| Menu saved. Meal times save once Hostelzy updates the server; residents keep the usual times till then. | Menu saved · meal times after the next server update |
| Meal times saved. Residents’ meal reminders ring at them. | Meal times saved |
| Menu cleared. Residents see “no menu yet”. | Menu cleared |
| Menu saved. Residents see it in their Food tab now. | Menu saved |
| The count for ${mealWord(k).toLowerCase()} on ${dayName(d).split(' ').first} has closed. | Count closed · ${mealWord(k).toLowerCase()} ${dayName(d).split(' ').first} |
| Thanks. Your ₹100 Member reward unlocks once your owner confirms your stay. | Saved · ₹100 unlocks once confirmed |
| Thanks. Your ₹100 Member reward is unlocked for your next stay. | Saved · ₹100 unlocked |
| Added, ${res.lateDays} days after moving in: that’s past the 3-day limit and goes to Fair Play. | Added · ${res.lateDays} days late · Fair Play check |
| Booked bed ${res.bed}. Send them a welcome on WhatsApp. | Booked bed ${res.bed} |
| Added. ${name.split(' ')[0]} confirms by joining with your invite code. | Added · waits for ${name.split(' ')[0]}’s invite |
| Room $room’s layout has no AC unit. Add it in the room’s layout and publish, then make the room AC. | Room $room: no AC in its layout |
| Only the owner can change rates and AC rooms. | Owner only |
| Your hostel is live now, so only the Hostelzy team can mark someone as joined before Hostelzy. Message the team. | Live hostel: ask the Hostelzy team |
| Booked bed $bedLabel. Send them a welcome on WhatsApp. | Booked bed $bedLabel |
| Someone just took this bed. Pick another one. | Bed just taken |
| You can hold ${AppState.maxHolds} beds at a time. Release one in Holds first. | Limit: ${AppState.maxHolds} holds |
| Couldn’t place the hold. Check your internet and try again. | Couldn’t hold. Check your internet. |
| That owner link isn’t valid any more. Ask Hostelzy for a new one. | Link no longer valid |
| This hostel already has an owner account. Ask Hostelzy. | Already has an owner account |
| Couldn’t join. Check your internet and try again. | Couldn’t join. Check your internet. |
| That code isn’t valid any more. Ask your owner for the new one. | Code no longer valid |
| You already asked. Your owner will approve it. | Already asked · waiting for approval |
| Add your name and 10-digit phone in Settings first. | Name and phone needed in Settings |
| Not saved: room $ac’s layout has no AC unit. Add it in the layout and publish first. | Not saved: room $ac has no AC in its layout |
| WhatsApp opened with ${name.split(' ')[0]}’s invite. They join once they open it and sign in. | Invite sent on WhatsApp |
| Trusted tenants get the first hour on this bed. It opens to you at ${clock(opens.hour * 60 + opens.minute)}. | Trusted tenants first · opens to you at ${clock(opens.hour * 60 + opens.minute)} |
| Publish this room’s layout first, then mark it. | Publish this layout first |
| Couldn’t save it. Check your internet and try again.' (every ternary / returned copy) | Couldn’t save. Check your internet. |
| ${c.resident} now shows as came from the app. Case closed. That’s 3 fixes in 6 months… (strike $now of 3). | Case closed · strike $now of 3 |
| ${c.resident} now shows as came from the app. Case closed, no strike. | Case closed · no strike |
| The 48 hours are over. Reply instead and the Hostelzy team decides. | 48 hours over · reply instead |
| The count for that meal has closed. Your answer counts from the next meal. | Count closed for that meal |
| ${lockedBy.name} is editing this room. Try again when they’re done. | ${lockedBy.name} is editing this room |
| Electricity by meter starts after Hostelzy’s next server update. | Meter: after the next server update |
| Room ${r.label}’s layout has no AC unit. Add it in the room’s layout and publish, then make the room AC. | Room ${r.label}: no AC in its layout |
| Added (came through Hostelzy) / as joined before Hostelzy. $first confirms by joining with your invite code. | Added · came through Hostelzy / joined before Hostelzy · waits for $first’s invite |
| Enter your friend’s code, like ASHA-4K7Q. | Code needed, like ASHA-4K7Q |
| Couldn’t make the invite. Check your internet and try again. | Couldn’t invite. Check your internet. |

**Two more Rule A lines found after the audit table was written:** Trusted-tenant sheet (`stay_tools_screens.dart:242`)
"You keep it with 6 months in Hostelzy hostels and rent paid on time. We never tell owners where you stayed before." /
"You get it after 6 months… (2 of 6 so far)…" → "6 months · rent on time" / "6 months · rent on time · 2 of 6 so far";
bed first-look line (`rewards.dart:71`) "Trusted tenants get the first hour on this bed. It opens to you at 4:05 pm." →
"Trusted tenants first · opens to you at 4:05 pm".

**Push bodies (new migration `supabase/migrations/20261018150000_f31_push_copy.sql`, bundles regenerated with `tools/sql-bundle.sh`).**
| Function | Old body | New body |
|---|---|---|
| `send_layout_fix` | "Compare it with the current layout and decide." | "Room N" |
| `decide_layout_fix` | "Room N is live for tenants now. Thanks for helping." / "Thanks for telling them about Room N." | "Room N is live" / "Room N" |
| `send_shape_drawing` | "Check it and publish. Tenants see it straight away." | "Room N · ready to publish" |
| `save_meter` | "70 units ÷ 4 · ₹8/unit. It’s on your rent in Hostelzy." | "70 units ÷ 4 · ₹8/unit" |
| `decide_signup` | "Your owner approved you. Open Hostelzy to see your stay." | "Your stay is open" |
| `join_with_invite` | "Approve them in Manage → Residents" | "Manage → Residents" |
The migration ships itself from `main` (DECISIONS 2026-10-18); no founder step.

**Web + console:** `app/index.html`, `app/r/`, `app/j/`, `app/console/console.js` per the audit table. `app/delete-account/` untouched
(store-required page).

**Tests:** 46 assertions updated to the new texts / orders (each marked `// F31` in the test), the two offer-sheet tests replaced by
one "no offer sheet on the 3rd app open" test, the Headcount position test now expects it under This month.

**Side effects the spec forces**
- S-strike notice (`oStrike`) was reachable only from the Fair Play card on Today; with the card shown only while a case is open,
  an owner with a strike and no open case has no way to open `oStrike` from the app (the push still deep-links). Hub to decide
  where it lives (suggest: a "Fair Play" row under Manage › Your plan, or the strike count on the plan screen).
- Hold-option cards in the hold sheet lose their subtitles ("Go and see it first" / "Sure already"); the tick lines stay.
- Settings kicker names changed to the spec's words: "You" → "Account", "App" split into "Language" and "About".

## Design (Design 3, boards)
Apply Rule A to **every** board (remove the helper lines; keep values/states) and Rule B to S36, S23, Manage, Me, Settings;
retire the waterOffer board (archive row). Ship `docs/design/v26/project/*.dc.html` (changed boards, same file names) +
`docs/design/v26/parts/f31.json` (`{"boards": {...changed entries if size changes...}, "retire": ["<waterOffer file>"]}`)
on branch `design/f31-clean`. When Build 5's table lands, re-check the boards against it and push again. The hub assembles v26.

## Not in the spec
Build 5 and Design 3 list extras here; the hub decides within the day.

### Build 5 extras (hub to decide)
- **Owner Manage keeps "Reviews and ranking"** (between House rules and Team): it is not in the F31 Manage list but removing a row
  is not in the spec either. Say the word and it goes.
- **Tenant IDs (F29) row** is Build 2's; the order above leaves its slot between House rules and Team.
- **Plan banner** stays above the money strip (the spec doesn't mention it; it only shows when the plan is late).
- **"Help on WhatsApp"** stays last in Me (not in the F31 Me order; not removed).
- **Delete-account "Why are you leaving?" field** lost its placeholder ("Helps us improve"); the field itself stays.
- Toast wording is Build 5's: the table above is the full list; change any line freely.

## Hub decisions on Build 5's extras (2026-10-18 21:05)
All accepted: Manage keeps "Reviews and ranking" (between House rules and Team); Tenant IDs row between House rules and Team;
the Plan banner stays above the money strip (it shows only when the plan is late, which is money); "Help on WhatsApp" stays last
in Me; the delete-account field keeps no placeholder; Build 5's toast table stands.
