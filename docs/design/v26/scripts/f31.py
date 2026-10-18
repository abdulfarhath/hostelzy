"""F31 · No explanations anywhere, everything in priority order.

Reads the main canvas boards (docs/design/main-canvas/project), applies Rule A (helper lines out,
values and states stay) and Rule B (S36, S23, Manage, Me, Settings orders), retires the water offer
boards, and writes only the changed boards to docs/design/v26/project plus parts/f31.json.

Run from the repo root:  python3 docs/design/v26/scripts/f31.py
"""
import json, os, re, sys, html as H
sys.path.insert(0, os.path.dirname(__file__))
from hz import Doc, apply

SRC = 'docs/design/main-canvas/project/'
OUT = 'docs/design/v26/project/'
PARTS = 'docs/design/v26/parts/'
LIVE = 'docs/design/v25/project/canvas.json'   # the published v25 index (461 boards)
canvas = json.load(open(LIVE))
changed = {}
titles = {}            # file -> new canvas title
retire = []            # files moved to the archive row

def load(f):
    return changed[f] if f in changed else open(SRC + f).read()

def save(f, raw):
    changed[f] = raw

def _check(ops):
    ops = sorted(ops)
    for a, b in zip(ops, ops[1:]):
        if b[0] < a[1]:
            raise ValueError(f'overlapping edits {a[:2]} {b[:2]}')
    return ops

def rm(f, *texts, many=False):
    """Remove the innermost element whose text contains each snippet."""
    raw = load(f); d = Doc(raw); ops = []
    for t in texts:
        els = d.find(text=t, all=True)
        if not els:
            raise KeyError(f'{f}: {t!r} not found')
        if len(els) > 1 and not many:
            raise KeyError(f'{f}: {t!r} x{len(els)}')
        ops += [(e.start, e.end, '') for e in els]
    save(f, apply(raw, _check(ops)))

def rt(f, old, new, many=False):
    """Replace the inner HTML of the innermost element containing `old` with plain `new`."""
    raw = load(f); d = Doc(raw)
    els = d.find(text=old, all=True)
    if not els:
        raise KeyError(f'{f}: {old!r} not found')
    if len(els) > 1 and not many:
        raise KeyError(f'{f}: {old!r} x{len(els)}')
    save(f, apply(raw, _check([(e.cstart, e.cend, H.escape(new, quote=False)) for e in els])))

def sub(f, old, new, count=1):
    """Literal substring replacement (for text that sits beside child tags)."""
    raw = load(f)
    n = raw.count(old)
    if n != count:
        raise KeyError(f'{f}: {old!r} x{n}, expected {count}')
    save(f, raw.replace(old, new))

def title(f, t):
    titles[f] = t

def upd(f, note=None):
    """Mark a board Updated (F31) in its canvas title."""
    if f in titles:
        return
    t = canvas['boards'][f]['title']
    t = re.sub(r' · (Updated|New|Redesigned|Added)( \([^)]*\))?( · (Updated|New|Redesigned|Added)( \([^)]*\))?)*$', '', t)
    titles[f] = t + (f' · {note}' if note else '') + ' · Updated (F31)'

KICK = ('<span style="font-size: 11px; font-weight: 600; letter-spacing: .1em; text-transform: uppercase; '
        'line-height: 1.3; color: var(--mu);">{}</span>')
CHEV = ('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" '
        'stroke-linecap="square" style="flex: none;"><path d="m9 18 6-6-6-6"/></svg>')
MU13 = '<span style="font-size: 13px; color: var(--mu);">{}</span>'

# ---------------------------------------------------------------------------------------------
# Rule A · helper lines out (values and states stay)
# ---------------------------------------------------------------------------------------------
A = {}   # file -> list of str (remove) | (old, new) (retext)

def a(files, *items):
    for f in files.split():
        A.setdefault(f, []).extend(items)

a('about.dc.html about-dark.dc.html w1-aboutEmpty.dc.html',
  'We’ll check it by SMS later.', 'Owners use this to call or WhatsApp you.')
a('w1-aboutEmpty.dc.html', 'Type the name owners should see.')
a('role.dc.html', 'You can switch later in Me.')
a('gateRes.dc.html w2-qrCamera.dc.html f24-mgrJoin.dc.html', 'Your owner gives you a code, or scan the Hostelzy poster')
a('gateOwn.dc.html', 'We visit, take photos and set it up with you.', 'Join it with the MGR- code your owner sent you.')
a('permN.dc.html', 'Your phone asks next.', 'Only about your hold, booking and rent.')
a('gateUp.dc.html', 'This version is too old to work with Hostelzy')
a('gateMt.dc.html', ('We’re making Hostelzy better.', 'Back by 6:30 pm.'))
a('r-filters.dc.html', 'Hide listed hostels the team hasn’t visited yet')
a('r-detail.dc.html r-detailDark.dc.html',
  'Green = with Hostelzy.',
  ('Same price for every bed of a type. Food included.', 'Food included. Electricity extra, by meter. Confirmed by the owner · 3 Oct'))
a('f24-detailOwner.dc.html f26-detailScroll.dc.html f27-hostelChip.dc.html', 'Talking through Hostelzy keeps your deal')
a('f24-detailOwner.dc.html', 'No contact before a hold.')
a('reviews.dc.html', 'Only people who stayed here can review.')
a('f12-Compare.dc.html', 'Comparing the two free beds.')
a('r-holdSheet.dc.html r-holdSheetMember.dc.html', 'Go and see it first')
a('r-signin.dc.html', 'Then your name and phone number.', 'So Srinivas knows who’s coming.')
a('r-notify.dc.html', 'Turn on notifications so Srinivas’s reply reaches you')
a('payAdv.dc.html', 'Hostelzy never holds your money.', ('Your price ₹5,800 is fixed', '₹2,000 back when you leave.'))
a('r-utr.dc.html', '12 digits, in your UPI app under the payment')
a('f07-Report.dc.html', 'The owner never sees your name.')
a('f09-MoveIn.dc.html', 'Ramesh gives you ₹100 off.')
a('me.dc.html', ('Owner’s phone needed · ₹200', '₹200 when it’s verified'))
a('me.dc.html w1-meRefund.dc.html f28-meYourHostel.dc.html add-meOwner.dc.html', 'Language, notifications, log out')
a('add-meOwner.dc.html', 'Ask the Hostelzy team')
a('settings.dc.html settings-dark.dc.html add-lang.dc.html w1-editName.dc.html w2-waSheet.dc.html', 'Owner replies, hold ending')
a('w1-notifSwitches.dc.html', 'When the owner confirms or replies', 'In areas you searched.', 'Saved to your account.')
a('w1-editName.dc.html', 'Owners see this name on your holds')
a('w2-waSheet.dc.html', 'Only if you chat on a different number')
a('add-lang.dc.html', 'Words not checked yet show in English.', ('Telugu and Hindi come once', 'Telugu and Hindi · not available yet'))
a('swap.dc.html', 'New rent starts next month.')
a('review.dc.html', 'Shown with your first name')
a('exitReview.dc.html', 'Shown as “Former resident”.')
a('hold.dc.html', 'Go and see it. Tell Srinivas', 'You sent the UPI reference. It says Booked',
  ('Srinivas didn’t see this payment.', 'Srinivas didn’t see this payment.'))
a('rent.dc.html rent-dark.dc.html',
  ('You sent UPI reference 4021 8834 1297.', 'You sent UPI reference 4021 8834 1297.'),
  ('Srinivas confirmed on 3 Oct. Thank you.', 'Srinivas confirmed on 3 Oct.'))
a('w3-noticeGiven.dc.html', ('Sent to Srinivas. They accept it', 'Sent to Srinivas.'),
  ('Advance minus ₹1,000 maintenance', 'Advance minus ₹1,000 maintenance, within 7 days of leaving.'))
a('r-today.dc.html r-todayDark.dc.html f29-todayJoining.dc.html f29-joinReview.dc.html f29-joinReviewDark.dc.html '
  'f29-joinReviewTick.dc.html f29-joinReviewDrive.dc.html f26-todayEmpty.dc.html', '33 of 40 beds have a resident.')
a('r-today.dc.html r-todayDark.dc.html f29-todayJoining.dc.html', ('Reply in 47 h · pinned until you answer', 'Reply in 47 h'))
a('f26-todayEmpty.dc.html', 'New holds, payments and fixes show up here.')
a('f19-Today.dc.html', 'Not on this list = not from Hostelzy.')
a('w1-oTodayMoves.dc.html', 'Accept frees the bed from the last day.')
a('f24-oTodayCards.dc.html', ('Last confirmed 3 days ago. Fresh beds rank higher.', 'Last confirmed 3 days ago'),
  'Not confirmed for 7 days:', ('Last confirmed 92 days ago.', 'Last confirmed 92 days ago'))
a('w2-oTodayRates.dc.html', ('Last confirmed 3 Sep. Tenants see', 'Last confirmed 3 Sep'), 'Not confirmed for a month:')
a('f09-Owner.dc.html', 'Hostelzy checks this from real stays.')
a('f14-Switcher.dc.html', 'Each hostel has its own plan')
a('invite.dc.html', 'Residents scan or type this code', ('Make a new code (the old one stops working)', 'Make a new code'))
a('oLayouts.dc.html', 'You edit and publish your own layouts.')
a('oRooms.dc.html', 'Add or remove rooms and floors.')
a('oLayout.dc.html oLayout-dark.dc.html w2-layoutWrong.dc.html', 'Tenants see “Not working”. A complaint is raised.')
a('w2-layoutWrong.dc.html', ('2 residents answered “No” in the 30-day review.', '2 residents answered “No” in the 30-day review.'))
a('oEditor.dc.html', ('Rectangle · drag walls to resize, 1 ft steps. Changing', 'Rectangle'), 'Never draw gates, CCTV or exits.',
  'Pick Custom and send a photo and a sketch.')
a('f12-Admin.dc.html', ('Rectangle · drag walls to resize, 1 ft steps', 'Rectangle'), 'Never draw gates, CCTV or exits.')
a('oPhotos.dc.html', 'Drag to reorder. The first is the cover.', 'Daylight, from the door, whole room in view.')
a('oPublished.dc.html', 'Tenants see this layout in the Room tab right away.')
a('deals.dc.html', ('Pick up to 3. Hostels with a deal', '2 of 3 on'), 'From the exit maintenance')
a('rates.dc.html', 'Advances and rent go straight here.')
a('menu.dc.html', ('Not set. Residents’ meal reminders use the usual times', 'Not set'), 'Residents and tenants see it after you tap Save.',
  'Fill Monday, then copy it to the other days.', ('No menu yet. Tenants see', 'No menu yet.'))
a('w4-oMenuWeek.dc.html', 'Today is highlighted. Tap a day to edit it.', ('Sunday dinner is not set. Tenants see', 'Sunday dinner not set.'))
a('rules.dc.html f24-oLaundry.dc.html', 'Tenants see these under House rules')
a('f24-oLaundry.dc.html', 'Residents who turn on the Laundry reminder')
a('oReviews.dc.html add-rank.dc.html w2-reportAbuse.dc.html', 'To rank higher: reply to reviews')
a('w2-reportAbuse.dc.html', 'Reviews can’t be removed for being low.')
a('plan.dc.html plan-dark.dc.html', ('Then ₹999 a month for 40 beds. No commission, ever.', 'Then ₹999 a month for 40 beds.'),
  ('October paid on 3 Oct. Thank you.', 'October paid on 3 Oct.'))
a('plan.dc.html', ('Pay by 20 Oct to keep your deals showing.', 'Pay by 20 Oct.'))
a('w4-planMore.dc.html', 'The plan changes with your bed count.')
a('case.dc.html', 'Explain or fix it. No reply counts against you.')
a('f24-oCasePhoto.dc.html', ('Bed 102-B, taken 19 Sep. Shown only', 'Bed 102-B, taken 19 Sep.'))
a('f07-Strike.dc.html', '*Strikes come only from a decided case.')
a('team.dc.html add-addMgr.dc.html', 'Managers can’t see your plan, deals, rates')
a('add-addMgr.dc.html', 'They get a link on WhatsApp and sign in with Google.')
a('f19-Lock.dc.html f19-Try.dc.html f19-Edit.dc.html f19-EditCheck.dc.html f19-Limit.dc.html f19-EditDark.dc.html '
  'f19-Send.dc.html f26-tryMode.dc.html', 'Wrong size? Change the width or length by 1 ft.')
a('f19-LockDark.dc.html', 'Stay here to help others see the real room.', 'Already staying here?')
a('f19-Main.dc.html', 'You live in Anjani Residency, so you can fix any room here.', 'Residents of Anjani Residency can see and fix every room here.')
a('f19-EditCheck.dc.html', 'Bed A has a resident, so it stays.')
a('f19-QuickFix.dc.html', 'It’s somewhere else in the room', 'There’s no AC unit in this room', 'Also goes to Srinivas as a repair',
  'Take it off the layout', 'Bigger change? Close this')
a('f19-Limit.dc.html', 'That’s the most at one time.')
a('f19-Send.dc.html', 'Only Srinivas and the Hostelzy team see it.', 'Srinivas sees your name and that you live in 204.')
a('f19-After.dc.html', ('Your suggestion · only you and Srinivas see it', 'Your suggestion'),
  ('Sent today, 6:40 pm · “Cupboard is on the left wall, next to the window.” Tenants still see',
   'Sent today, 6:40 pm · “Cupboard is on the left wall, next to the window.”'))
a('f19-Checked.dc.html', '3 different residents fixed this room')
a('f19-Compare.dc.html f19-Reject.dc.html f19-Mute.dc.html f19-CompareDark.dc.html',
  ('Beds, fan, AC, window, door and size are the same. All checks pass.', 'All checks pass.'),
  ('1 photo · sent today, 6:40 pm · only you see who sent it', '1 photo · sent today, 6:40 pm'))
a('f19-Reject.dc.html', 'The current layout stays live.')
a('f19-Mute.dc.html', 'Unmute any time in Manage', 'You won’t get Rahul’s layout fixes')
a('f19-Push.dc.html', ('Rahul (lives in 204) suggested a fix for Room 207', 'Layout fix for Room 207 · Rahul, 204'))
a('f20-Main.dc.html f20-MainDark.dc.html', '*Reminders ring from this phone, even offline.')
a('f20-Water.dc.html f20-Add.dc.html', 'Reminders ring from this phone, even offline.')
a('f20-Notify.dc.html f20-NotifyDark.dc.html', 'The app icon shows on every one.', ('5 of 8 today. Tap Done', '5 of 8 today'))
a('f23-DetailDark.dc.html', 'Shared by everyone on that floor.')
a('f23-Room.dc.html f23-Floor.dc.html f23-Add.dc.html f24-roomLayersOn.dc.html w1-acRepair.dc.html w1-notifyReady.dc.html',
  'Same price for every bed here')
a('f23-Floor.dc.html', 'Residents can add or fix this list.')
a('f23-Owner.dc.html f24-oShape.dc.html f24-oShapeReq.dc.html', 'Broken things also show on Today as a repair.')
a('f24-oShape.dc.html', 'Not on the list, or no time? Tap Custom.')
a('f24-oShapeReq.dc.html', ('Free. The Hostelzy team draws it within 48 hours.', 'Free · within 48 hours'))
a('f24-oShapeBack.dc.html', ('You asked on 2 Oct, 10:12. Drawn in 26 hours.', 'Asked 2 Oct, 10:12 · drawn in 26 hours'))
a('add-utr.dc.html', 'We match the UPI reference with our bank record', 'in your UPI app, open this payment')
a('add-addR.dc.html', 'Sai confirms by joining with your invite code.')
a('add-addRoom.dc.html', ('₹7,000 a month per bed, from your rate card.', '₹7,000 a month per bed'))
a('add-meOwner.dc.html', 'Looking for a bed, or live in a PG?')
a('f24-oMeter.dc.html', 'Type each room’s meter now.', 'Residents see “Electricity · 70 units · ₹140”')
a('f24-oRefund.dc.html', ('Rahul confirms in the app.', 'Due by 8 Nov'))
a('f24-mgrJoin.dc.html', 'Manager codes start with MGR.', ('You’re a manager at Anjani Residency now.', 'You’re a manager at Anjani Residency now.'))
a('f24-trustedPerks.dc.html', 'You keep it with 6 months in Hostelzy hostels')
a('f24-rRefund.dc.html', 'Check your bank app for the UPI reference above.')
a('teamSheet.dc.html', 'For the Hostelzy team only.', 'The founder adds team accounts.')
a('aHome.dc.html', 'On a visit: basics, rooms floor by floor', 'Lead → Visited → Signed up', 'Payments and Fair Play cases are in the team console.',
  'Draw and move beds, fans, AC, windows', 'Who helps with visits, layouts and payments')
a('aTeam.dc.html', 'Visits: add hostels and residents.')
a('aAdd2.dc.html', 'Floors can have different rooms.')
a('f14-Photos.dc.html', 'Taken by Hostelzy, in daylight, from the door.')
a('f14-Residents.dc.html', 'Owner adds the rest within 3 days', 'Residents here before Hostelzy count as Before Hostelzy')
a('f24-aAddOwner.dc.html', 'The owner runs the hostel from their own phone.', 'Srinivas opens the link on his phone', 'Linked shows here as soon as he signs in')
a('aAdd6.dc.html aAdd6-dark.dc.html', ('Optional: 4 residents added. Goes live with', 'Optional · 4 residents added'))
a('cSignin.dc.html', 'Not on the team? Use the Hostelzy app instead.')
a('cSignin.dc.html cNotTeam.dc.html', 'Onboarding, payments, Fair Play and layout help.')
a('cOnb.dc.html cOnb-dark.dc.html', 'The rest (rooms, rates, photos, residents) is done on the visit')
a('cPay.dc.html', ('Pay to 9059790014@axl · match every UTR', 'Pay to 9059790014@axl'))
a('cCases.dc.html', 'A report never strikes an owner by itself.')
a('f24-cLayoutHelp.dc.html', 'The owner checks it and publishes.')
a('f24-cRewards.dc.html', 'Every grant, spend and reversal.')
a('f24-cLayoutFixes.dc.html', 'Owners decide first. After 7 days')
a('w1-cStrikes.dc.html', 'Strikes: 1 warning · 2 deals hidden')
a('w2-cReported.dc.html', 'Hide a review only if it breaks the rules')
a('w3-cLayoutEditor.dc.html', 'The owner’s app places the beds, fans and windows')
a('w1-cError.dc.html', 'Still stuck? Send this message to the founder')
a('f26-c14.dc.html', 'Shown as UNVERIFIED with an expected rent range.')
a('f26-c15.dc.html f28-c15-addedBy.dc.html', 'Owners who tapped “Claim this hostel”.')
a('f28-c14-torefresh.dc.html', 'After 60 days a listed hostel shows')
a('wHome.dc.html', 'Hostelzy is an Android app for tenants, residents and hostel owners')
a('wR.dc.html', 'Hostelzy doesn’t take enquiries any more')
a('wJ.dc.html wJ-dark.dc.html', 'Pay rent by UPI, see the food menu and raise complaints')
a('wJ.dc.html wJ-dark.dc.html w3-wJNoCode.dc.html', ('Then open Hostelzy, sign in and pick', 'Then open Hostelzy, sign in and pick I live in a Hostelzy PG.'))
a('f28-wList.dc.html', 'Tenants in Hyderabad find PGs on Hostelzy.', ('We’ll call you within 2 days to confirm. Nothing is listed', 'We’ll call you within 2 days to confirm.'))
a('f28-wListSent.dc.html', ('We call +91 98490 11223. Nothing is listed', 'We call +91 98490 11223.'))
a('w1-holdsEnded.dc.html', 'Ended and released holds stay here for 7 days.')
a('w1-rNotYet.dc.html', 'Joined with a code? Your owner still has to approve you.', 'Once your owner adds you, your rent shows here')
a('w3-stayNotYet.dc.html', ('Your stay isn’t on Hostelzy yet. Once Srinivas adds you', 'Your stay isn’t on Hostelzy yet.'))
a('w1-bedSheetLeaving.dc.html', 'Tap “Rahul moved out” on the day he leaves.')
a('w1-oPriceFixed.dc.html', 'Ravi’s price and deal stay the same')
a('w1-dealsPaused.dc.html', 'This hostel’s deals are paused for a while.', ('Everyone pays the walk-in price while deals are paused.', 'Advance ₹3,000.'),
  ('Same price for every bed of a type. Food included.', 'Food included. Electricity extra, by meter.'))
a('w1-acRepair.dc.html', ('AC under repair. Complaint raised 1 Oct.', 'AC under repair · complaint raised 1 Oct'))
a('w1-walkInHold.dc.html', 'Someone at the gate? A walk-in hold')
a('w1-walkInHeld.dc.html', 'Tenants see this bed as “On hold” until the hour ends.')
a('w1-didJoin.dc.html', ('Your hold on bed 102-C ended on 30 Sep. One tap', 'Your hold on bed 102-C ended on 30 Sep.'), 'Only the Hostelzy team sees your answer')
a('w1-notifyReady.dc.html', 'Layouts are drawn by the owner, or by Hostelzy after a visit', 'The owner hasn’t published this room’s layout yet.')
a('w2-ownerOnly.dc.html', 'You manage Anjani Residency: beds, residents')
a('w2-qrScan.dc.html w3-scanOff.dc.html w3-scanError.dc.html', 'Point it at the QR on the Hostelzy poster')
a('w3-scanOff.dc.html', 'Allow it in your phone’s Settings')
a('w3-scanError.dc.html', 'Type the code from the poster instead.')
a('w2-exploreNoMatch.dc.html', 'Try a higher budget or any room type.')
a('exploreEmpty.dc.html w1-mapEmpty.dc.html', 'We add hostels area by area')
a('r-offline.dc.html', 'Hostels show again when you’re back online.')
a('holdsEmpty.dc.html', 'Hold any free bed for 1 hour while you go and see it.')
a('savedEmpty.dc.html', 'Tap the heart on any hostel to keep it here.')
a('delBlocked.dc.html', 'Once it’s settled, come back to Settings')
a('delConfirm.dc.html', 'Sign in with Google once more.')
a('delDone.dc.html', 'Thanks for using Hostelzy.')
a('w3-roomError.dc.html', 'Check your internet and try again. You can still pick a bed')
a('w3-rRoomNoLayout.dc.html', 'The owner draws this room first.')
a('w3-oLayoutNone.dc.html', 'Draw it yourself in a few minutes')
a('w3-oLayoutDrawing.dc.html', ('You asked on 2 Oct, 10:12 · L shape · 14 × 12 ft. Done within', 'You asked on 2 Oct, 10:12 · L shape · 14 × 12 ft'))
a('w3-oRules.dc.html', 'Tenants trust Hostelzy because every hostel plays by the same rules.')
a('f26-unverified.dc.html f26-h47.dc.html', ('Expected, not confirmed. The owner hasn’t joined', 'Expected, not confirmed'),
  'No free beds, holds or owner contact yet.')
a('f26-h47.dc.html', ('Our team calls you within 2 days to check', 'Our team calls you within 2 days.'))
a('f26-detailBig.dc.html', 'Big hostels open the building on its own page')
a('f26-contactOpen.dc.html', 'Both lock again if the hold expires')
a('f26-savedHolds.dc.html', ('Ramesh kept your bed. Visit before the hold ends', 'Ramesh kept your bed.'))
a('f26-holdsKept.dc.html', ('Srinivas kept your bed. Visit before the hold ends', 'Srinivas kept your bed.'))
a('f26-holdsDeclined.dc.html', ('The owner couldn’t keep this bed. Call and WhatsApp', 'The owner couldn’t keep this bed.'))
a('f26-myStay.dc.html f26-h45.dc.html f26-h46.dc.html', 'Wi-Fi, water, electricity, cleaning, food')
a('w4-building.dc.html f26-detailScroll.dc.html', 'Shared things sit on each floor; red = not working.')
a('f27-week.dc.html', 'Tap a meal to switch between eating and skip.', 'Each meal closes 3 h before it is served.')
a('f27-saved.dc.html', '1 skip = 1 plate the kitchen didn’t cook.')
a('f27-push.dc.html', 'Sent 1 h before the count closes', ('Chapati, dal. Tap Skip if you won’t be here.', 'Chapati, dal · closes at 5:00 pm'))
a('f28-addHostel.dc.html f28-addHostelDark.dc.html', ('Owner’s phone is never shown to tenants. ₹200', '₹200 when verified'))
a('f28-addHostelPartner.dc.html', ('Owner’s phone is never shown to tenants. ₹20', '₹20 after the team check'))
a('f28-myAdd.dc.html f28-myAddDark.dc.html f28-myAddAsked.dc.html f28-myAddAgreed.dc.html f28-myAddVerified.dc.html '
  'f28-myAddPaid.dc.html f28-myAddWaiting.dc.html f28-myAddQueued.dc.html', 'Paid only when the owner agrees')
a('f28-myAddWaiting.dc.html', ('Still waiting. You can ask again.', 'Still waiting.'))
a('f28-myAddQueued.dc.html', ('This month’s ₹2,000 cap for added hostels is reached.', 'Your ₹200 is queued for 5 Dec.'))
a('f29-askJoin.dc.html', 'The link works once, for 7 days, for this bed.')
a('f29-joinForm.dc.html f29-joinFormDark.dc.html', 'Opens WhatsApp to Srinivas with', 'Srinivas approves, then you’re in.')
a('f29-joinReview.dc.html f29-joinReviewDark.dc.html', 'Tick when Ravi’s photo arrives on WhatsApp.')
a('f29-joinReviewTick.dc.html', ('Ticked 18 Oct · Hostelzy stores only this tick', 'Ticked 18 Oct'))
a('f29-drive.dc.html f29-driveConnected.dc.html f29-driveNA.dc.html', 'Keep tenant IDs in your own Google Drive.', 'Hostelzy never stores them.',
  'Off: the tenant covers the first 8 digits', 'Hostelzy sees only the files it made')
a('f29-driveNA.dc.html', ('Not available yet. Google hasn’t approved', 'Not available yet.'))
a('oRent.dc.html oRent-dark.dc.html', 'WhatsApp opens with')   # the message-preview note block (its parent div)

def apply_rule_a():
    sub('w1-cError.dc.html', 'WhatsApp.</p>p>', 'WhatsApp.</p>')   # stray text in the source board
    errs = []; gone = []
    for f, items in A.items():
        for it in items:
            try:
                if isinstance(it, tuple):
                    rt(f, it[0], it[1])
                elif it.startswith('*'):      # '*text' = remove every copy
                    rm(f, it[1:], many=True)
                else:
                    rm(f, it)
            except KeyError as e:
                if 'not found' in str(e):
                    gone.append(str(e))        # already removed upstream (v25 "Rule A applied"); fine
                else:
                    errs.append(str(e))
        if f in changed:
            upd(f)
    if errs:
        raise SystemExit('\n'.join(errs))
    print(len(gone), 'lines were already gone upstream')
    # elements that need a wider cut than the innermost text element
    for f in ('oRent.dc.html', 'oRent-dark.dc.html'):
        pass

# oRent: "WhatsApp opens with" is a kicker inside a 3-span note block; drop the whole block instead.
def fix_orent():
    for f in ('oRent.dc.html', 'oRent-dark.dc.html'):
        raw = open(SRC + f).read(); d = Doc(raw)
        k = d.find(text='WhatsApp opens with', exact=True)
        blk = k.parent
        save(f, apply(raw, [(blk.start, blk.end, '')]))
        A[f] = [x for x in A[f] if x != 'WhatsApp opens with']

# r-utr: the mock UPI receipt and its sentence share one wrapper div; drop the wrapper.
def fix_utr():
    f = 'r-utr.dc.html'
    raw = load(f); d = Doc(raw)
    e = d.find(text='Open the payment in your UPI app.')
    save(f, apply(raw, [(e.parent.start, e.parent.end, '')]))

# beds: keep the Layouts › link, drop the coach-mark sentence around it.
def fix_beds():
    for f in ('beds.dc.html', 'beds-dark.dc.html'):
        raw = load(f); d = Doc(raw)
        e = d.find(text='Tap a bed for its bed sheet.')
        link = [c for c in e.children if c.tag == 'a'][0]
        save(f, apply(raw, [(e.cstart, e.cend, d.outer(link))]))
        upd(f)

# ---------------------------------------------------------------------------------------------
# Rule B · S36 Owner Today
# ---------------------------------------------------------------------------------------------
def money_strip(due='₹6,000', late='₹16,300'):
    return ('<button style="margin: 0 16px 10px; padding: 10px 12px; display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) 16px; '
            'gap: 10px; align-items: center; border: 2px solid var(--tx); text-align: left;">'
            '<span style="display: grid; gap: 1px;">' + KICK.format('Due today') + f'<b style="font-size: 20px;">{due}</b></span>'
            '<span style="display: grid; gap: 1px;">' + KICK.format('Late').replace('var(--mu)', 'var(--ad)') +
            f'<b style="font-size: 20px; color: var(--ad);">{late}</b></span>' + CHEV + '</button>')

def tab(n, label, on=False):
    st = 'padding: 8px 2px; display: grid; justify-items: center; gap: 1px; ' + ('background: var(--tx); color: var(--bg);' if on else 'color: var(--tx);')
    return f'<button style="{st}"><b style="font-size: 18px; line-height: 1.1;">{n}</b><span style="font-size: 11px; font-weight: 600;">{label}</span></button>'

def tabs(items):
    return (f'<div style="margin: 0 16px; display: grid; grid-template-columns: repeat({len(items)}, minmax(0, 1fr)); border: 2px solid var(--tx);">'
            + ''.join(tab(n, l, i == 0) for i, (n, l) in enumerate(items)) + '</div>')

def scroll_children(d):
    root = [e for e in d.els if 'data-hz' in e.attrs][0]
    body = [c for c in root.children if c.tag == 'div'][1]
    return root, body, [c for c in body.children]

def restructure_today(f, tab_items, empty=False):
    raw = load(f); d = Doc(raw); root, body, kids = scroll_children(d)
    def pick(pred):
        for k in kids:
            if pred(k):
                return k
        return None
    fair = pick(lambda k: k.text.startswith('Fair Play'))
    head = pick(lambda k: 'Dinner tonight' in k.text)
    kick = pick(lambda k: k.text.startswith('Needs you'))
    tabs_el = pick(lambda k: k.children and k.children[0].tag == 'button' and 'Holds' in k.text)
    lst = pick(lambda k: ('Hold on bed' in k.text or 'wants to join' in k.text) and k is not tabs_el)
    nothing = pick(lambda k: 'Nothing needs you now' in k.text)
    month = pick(lambda k: k.text.startswith('This month'))
    stats = pick(lambda k: 'beds taken' in k.text)
    bar = pick(lambda k: k.attrs.get('aria-label', '').startswith('83%'))
    order = []
    if not empty:
        order += [money_strip(), d.outer(kick), tabs(tab_items), d.outer(lst)]
        if fair:
            order.append(d.outer(fair).replace('margin: 0 16px 10px;', 'margin: 12px 16px 0;'))
    else:
        order += [d.outer(nothing)]
    order += [d.outer(month), d.outer(stats), d.outer(bar)]
    if head:
        order.append(d.outer(head).replace('margin: 0 16px 10px;', 'margin: 16px 16px 10px;'))
    save(f, apply(raw, [(body.cstart, body.cend, ''.join(order))]))

def today_variants_strip(f):
    """Older S36 variants: the money strip goes first, the rest stays."""
    raw = load(f); d = Doc(raw); root, body, kids = scroll_children(d)
    save(f, apply(raw, [(body.cstart, body.cstart, money_strip())]))

def rule_b_today():
    main = [(2, 'Holds'), (1, 'Payments'), (1, 'Fixes')]
    restructure_today('r-today.dc.html', main)
    restructure_today('r-todayDark.dc.html', main)
    restructure_today('f29-todayJoining.dc.html', [(2, 'Holds'), (1, 'Payments'), (1, 'Joining'), (1, 'Fixes')])
    restructure_today('f26-todayEmpty.dc.html', [], empty=True)
    for f in ('f19-Today.dc.html', 'f23-Today.dc.html', 'f24-oTodayCards.dc.html', 'w1-oTodayMoves.dc.html', 'w2-oTodayRates.dc.html'):
        today_variants_strip(f)
    title('r-today.dc.html', '[S36] oToday · Money strip (Due today · Late → Rent), then Holds · Payments · Joining · Fixes; Fair Play only while a case is open; This month; headcount near the bottom · Updated (F31)')
    title('r-todayDark.dc.html', '[dark] oToday · Today in the F31 order (dark) · Updated (F31)')
    title('f29-todayJoining.dc.html', '[variant of S36] oToday · Joining tab (only when non-empty): “Ravi wants to join · bed 203-B · moves in 1 Nov” → H49 · Updated (F31)')
    title('f26-todayEmpty.dc.html', '[T33] oToday · Nothing needs you now (no strip, no tabs when all zero) · Updated (F31)')
    for f in ('f19-Today.dc.html', 'f23-Today.dc.html', 'f24-oTodayCards.dc.html', 'w1-oTodayMoves.dc.html', 'w2-oTodayRates.dc.html'):
        upd(f, 'money strip first')

# ---------------------------------------------------------------------------------------------
# Rule B · S23 Resident Home
# ---------------------------------------------------------------------------------------------
ICON = {
    'notice': '<path d="M15 3h6v18h-6M10 17l5-5-5-5M15 12H3"/>',
    'swap': '<path d="M7 4 3 8l4 4M3 8h14M17 20l4-4-4-4M21 16H7"/>',
    'fix': '<path d="M14 7a4 4 0 0 0 5 5l-9 9-3-3 9-9a4 4 0 0 0-2-2z"/>',
}

def action(label, icon):
    return ('<button style="height: 72px; padding: 10px; display: grid; gap: 6px; align-content: center; justify-items: start; '
            'border: 2px solid var(--tx); font-size: 13px; font-weight: 800; text-align: left;">'
            '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--ad)" stroke-width="2" stroke-linecap="square" style="flex: none;">'
            + ICON[icon] + '</svg>' + label + '</button>')

def review_card():
    return ('<div style="margin: 14px 16px 0; padding: 14px; border: 2px solid var(--tx); display: grid; grid-template-columns: minmax(0, 1fr) auto; '
            'gap: 10px; align-items: center;"><span style="display: grid; gap: 2px;">' + KICK.format('30-day review') +
            '<b style="font-size: 18px;">How is your stay?</b>' + MU13.format('Open till 2 Nov') + '</span>'
            '<button style="height: 44px; padding: 0 16px; display: flex; justify-content: space-between; align-items: center; gap: 10px; '
            'font-weight: 800; font-size: 15px; border: 2px solid var(--tx);">Review' + CHEV + '</button></div>')

def restructure_home(f):
    """Home has no scroll wrapper: the blocks sit directly under the root, between the header and the nav."""
    raw = load(f); d = Doc(raw)
    root = [e for e in d.els if 'data-hz' in e.attrs][0]
    kids = [c for c in root.children if c.tag != 'nav'][1:]
    rent = kids[0]
    acts = [k for k in kids if 'Pay rent' in k.text and 'Raise complaint' in k.text][0]
    meal = [k for k in kids if 'Next meal' in k.text][0]
    fk = [k for k in kids if k.text.startswith('Food this week')][0]
    table = [k for k in kids if 'Breakfast · 7:30' in k.text][0]
    tail = [k for k in kids if k.start > table.start]
    acts_html = ('<div style="margin: 14px 16px 0; display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px;">'
                 + action('Give notice', 'notice') + action('Swap bed', 'swap') + action('Raise complaint', 'fix') + '</div>')
    meal_html = d.outer(meal).replace('margin: 14px 16px 0;', 'margin: 10px 16px 0;', 1)
    order = [d.outer(rent), meal_html, d.outer(fk), d.outer(table), acts_html, review_card()] + [d.outer(t) for t in tail]
    save(f, apply(raw, [(kids[0].start, kids[-1].end, ''.join(order))]))

def rule_b_home():
    restructure_home('r-home.dc.html')
    restructure_home('f26-homeDark.dc.html')
    title('r-home.dc.html', '[S23] rHome · Rent → next meal → food week → 3 actions (notice, swap, fix) → 30-day review; no water card · Updated (F31)')
    title('f26-homeDark.dc.html', '[dark] rHome · Home in the F31 order (dark) · Updated (F31)')

# ---------------------------------------------------------------------------------------------
# Rule B · Owner Manage, Me, Settings
# ---------------------------------------------------------------------------------------------
MANAGE_ORDER = ['Residents', 'Rates and UPI', 'Room layouts', 'Meals', 'Photos', 'Deals', 'Complaints', 'Food menu', 'House rules',
                'Reviews and ranking', 'Tenant IDs', 'Team', 'Your plan']
ID_ICON = '<rect x="3" y="5" width="18" height="14"/><circle cx="9" cy="11" r="2"/><path d="M14 10h4M14 14h4M6 17c0-2 1.5-3 3-3s3 1 3 3"/>'
MEAL_ICON = '<path d="M4 15h16a8 8 0 0 0-16 0zM3 19h18M12 7V5"/>'

def manage_row(src_row_html, label, subtitle, icon_paths):
    row = re.sub(r'(<svg width="18"[^>]*>).*?</svg>', lambda m: m.group(1) + icon_paths + '</svg>', src_row_html, count=1, flags=re.S)
    row = re.sub(r'<b style="font-size: 16px;">[^<]*</b>', f'<b style="font-size: 16px;">{label}</b>', row, count=1)
    row = re.sub(r'<span style="font-size: 13px; color: var\(--mu\);">[^<]*</span>', MU13.format(subtitle), row, count=1)
    return row

def reorder_manage(f):
    raw = load(f); d = Doc(raw); root, body, kids = scroll_children(d)
    rows = {}
    for k in kids:
        if k.tag != 'button':
            continue
        lab = [c for c in d.els if c.tag == 'b' and c.start > k.start and c.end < k.end][0].text
        rows[lab] = d.outer(k)
    base = rows['Food menu']
    rows['Meals'] = manage_row(base, 'Meals', 'Dinner · 34 of 40 eating', MEAL_ICON)
    rows['Tenant IDs'] = manage_row(base, 'Tenant IDs', 'Drive not connected', ID_ICON)
    missing = [x for x in MANAGE_ORDER if x not in rows]
    if missing:
        raise KeyError(f'{f}: manage rows missing {missing}')
    save(f, apply(raw, [(body.cstart, body.cend, ''.join(rows[x] for x in MANAGE_ORDER))]))
    upd(f, 'F31 order: Residents · Rates and UPI · Layouts · Meals · Photos · Deals · Complaints · Food menu · House rules · Reviews · Tenant IDs · Team · Plan')

def reorder_me_f20():
    f = 'f20-Me.dc.html'
    raw = load(f); d = Doc(raw); root, body, kids = scroll_children(d)
    rows = {k.text.split(' ·')[0].strip(): d.outer(k) for k in kids if k.tag == 'button'}
    order = ['Saved hostels', 'Stay Rewards', 'Reminders', 'Settings', 'Switch role', 'Log out']
    save(f, apply(raw, [(body.cstart, body.cend, ''.join(rows[x] for x in order))]))
    upd(f, 'F31 order')

ABOUT_ROW = ('<div style="display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 12px; align-items: center; min-height: 52px; '
             'padding: 8px 16px; border-bottom: 1px solid var(--hl);"><b style="font-size: 16px; color: var(--tx);">About</b>'
             '<span style="font-size: 14px; color: var(--mu);">Hostelzy 1.0.0 (1)</span></div>')

def settings_order(f):
    raw = load(f); d = Doc(raw)
    you = d.find(text='You', exact=True, tag='span')
    team = d.find(text='Hostelzy team', exact=True, tag='b').parent
    save(f, apply(raw, [(you.cstart, you.cend, 'Account'), (team.end, team.end, ABOUT_ROW)]))
    upd(f, 'Account · Notifications · Language · About · Delete account last')

def rule_b_lists():
    for f in ('r-manage.dc.html', 'f29-drive.dc.html', 'f29-driveConnected.dc.html', 'f29-driveNA.dc.html'):
        reorder_manage(f)
    reorder_me_f20()
    for f in ('settings.dc.html', 'settings-dark.dc.html', 'w1-notifSwitches.dc.html', 'add-lang.dc.html', 'w1-editName.dc.html'):
        settings_order(f)
    for f in ('me.dc.html', 'w1-meRefund.dc.html', 'f28-meYourHostel.dc.html'):
        sub(f, 'Live in a PG or run one? <a', '<a')
        upd(f)

# ---------------------------------------------------------------------------------------------
# Retire the water offer sheet (and the Home / Explore water-card variants it opened)
# ---------------------------------------------------------------------------------------------
def retire_boards():
    for f in ('f20-Offer.dc.html', 'f20-Home.dc.html', 'f20-HomeDark.dc.html', 'f20-HomeTenant.dc.html'):
        retire.append(f)
        changed.pop(f, None); titles.pop(f, None)

# ---------------------------------------------------------------------------------------------
def write_out():
    os.makedirs(OUT, exist_ok=True); os.makedirs(PARTS, exist_ok=True)
    parts = {'boards': {}, 'retire': retire}
    arch_x = 5170
    for f in sorted(set(changed) | set(titles)):
        if f in retire:          # the hub deletes retired files from the artifact; nothing to publish
            continue
        raw = load(f)
        b = dict(canvas['boards'][f])
        if f in titles:
            b['title'] = titles[f]
            raw = re.sub(r'<title>.*?</title>', '<title>' + H.escape(titles[f], quote=False) + '</title>', raw, count=1, flags=re.S)
            if f in retire:
                b['x'], b['y'] = arch_x, 47747
                arch_x += 470
            parts['boards'][f] = {'x': b['x'], 'y': b['y'], 'w': b['w'], 'h': b['h'], 'title': b['title']}
        open(OUT + f, 'w').write(raw)
    json.dump(parts, open(PARTS + 'f31.json', 'w'), indent=1, ensure_ascii=False)
    return parts

if __name__ == '__main__':
    fix_orent()
    apply_rule_a()
    fix_beds()
    fix_utr()
    rule_b_today()
    rule_b_home()
    rule_b_lists()
    retire_boards()
    parts = write_out()
    print(len(changed), 'boards changed,', len(parts['boards']), 'title/position entries,', len(retire), 'retired')
