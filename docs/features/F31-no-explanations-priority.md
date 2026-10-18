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

## Design (Design 3, boards)
Apply Rule A to **every** board (remove the helper lines; keep values/states) and Rule B to S36, S23, Manage, Me, Settings;
retire the waterOffer board (archive row). Ship `docs/design/v26/project/*.dc.html` (changed boards, same file names) +
`docs/design/v26/parts/f31.json` (`{"boards": {...changed entries if size changes...}, "retire": ["<waterOffer file>"]}`)
on branch `design/f31-clean`. When Build 5's table lands, re-check the boards against it and push again. The hub assembles v26.

## Not in the spec
Build 5 and Design 3 list extras here; the hub decides within the day.
