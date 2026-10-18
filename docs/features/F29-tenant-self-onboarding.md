# F29 · Tenant adds their own ID (Aadhaar) + contact buttons for every resident (ideating, 2026-10-18)

**Founder (2026-10-18 05:20):** the owner should not keep the mess of Aadhaar copies. Like the notify / message / call buttons,
the owner taps one button for a tenant who is not yet in the app → a link goes to the tenant on WhatsApp from the owner's
number → the tenant uploads a photo of their Aadhaar → the owner checks and approves → the tenant is in the app. Also: in the
owner's rent list the notify / message / call buttons must be on **every** resident, not only the unpaid ones. Ideate only.

## What exists
- Owner › Manage › Residents: invite code, QR, share, poster (S47 `oInvite`); tenant joins with the code (S5 `roleGate`, S7 scan).
- Owner adds a resident by hand (`addTenant`), typing everything.
- Owner › Rent (S37 `oRent`): Call + WhatsApp only on unpaid rows (F26 #19/#20).
- No ID / Aadhaar anywhere in the app today.

## Idea A · "Ask to join" link, tenant does the typing
| Step | Who | What |
|---|---|---|
| 1 | Owner | Residents › **Ask to join** (same style as Call / WhatsApp). Picks the bed, taps → WhatsApp opens from the owner's phone with a ready message + link |
| 2 | Tenant | Opens the link → signs in (Google / phone) → name, photo of Aadhaar, move-in date; bed already chosen by the owner |
| 3 | Owner | Today shows "Ravi wants to join, bed 203 · check ID" → sees the Aadhaar photo, **Approve** or **Ask again** |
| 4 | App | Approved → resident row, rent card, invite done. Nothing typed by the owner |

Works for new tenants and for the owner's existing tenants (bulk: "Ask all to join" sends one link per bed, owner forwards).

## Idea B · The Aadhaar photo, done carefully
Why careful: Hyderabad police ask PG owners to keep tenant IDs, so owners want it. But a full Aadhaar image is sensitive
(Aadhaar Act 2016 limits storing the number; DPDP Act 2023 makes us responsible for leaks). Plan that keeps owners happy and us safe:
| Rule | How |
|---|---|
| Masked by default | Tenant takes the photo in the app; we blur the first 8 digits before upload (UIDAI's own "masked Aadhaar" idea). Owner sees name, photo, last 4 digits, address |
| Seen only by the two of them | Stored in a private bucket; only this owner's staff and the tenant can open it; never in the team console |
| Gone when they leave | Deleted 30 days after move-out (owner can download a copy before, for the police file) |
| Tenant's choice | Aadhaar or any one government ID (DL, voter ID, passport); Aadhaar is the default |
| Later | DigiLocker / UIDAI offline KYC gives a verified result with no image at all; keep as a v2 |

## Idea C · Contact buttons for everyone
Owner › Rent and Owner › Residents: **Call · WhatsApp · Notify** on every resident row, not only unpaid. Message text
changes with status (Paid: plain hello; Due: rent reminder as today; Late: as today). One sheet, same as F26 D built.

## Not in this spec (kept)
Police verification form export · Rent agreement e-sign · Tenant's own copy of their ID in My stay.

## Questions for the founder
| # | Question | My pick |
|---|---|---|
| 1 | Masked Aadhaar (last 4 digits visible) is enough for the owner? | Yes |
| 2 | Delete the ID 30 days after move-out? | Yes |
| 3 | Any government ID allowed, Aadhaar default? | Yes |

## Founder round 2 (2026-10-18 05:30): no PII storage, use the owner's own cloud
Founder: pre-launch, no money for DPDP exposure. Store nothing of the tenant's ID on Hostelzy; put it straight into the
owner's Google Drive (or Outlook/OneDrive). Showing it back in the app is optional.

**Possible: yes.** Design:
| Piece | How |
|---|---|
| Owner connects Drive once | Owners already sign in with Google. One extra consent screen with the `drive.file` scope (the app can only see files it created; a non-sensitive scope, no Google audit). The app makes `Hostelzy / <hostel name> / Tenant IDs` in the owner's Drive. Owner can disconnect any time |
| Tenant uploads | The tenant's link opens our page; the photo goes to a Supabase Edge Function that uploads it **on the owner's behalf** into that folder and returns the Drive file id. The image passes through in memory only; nothing written to our storage or database |
| What Hostelzy keeps | The owner's Google refresh token (encrypted, it is the owner's own data) and per resident: `drive_file_id` + "ID received on <date>". No image, no Aadhaar number |
| Showing it in the app | Yes, optional: the app asks our function for a short-lived view link via the owner's token and shows the image; the owner can also just open Drive. Only the owner's staff can call it |
| Masking | The tenant's phone blurs the first 8 digits **before** upload (on the device), so even the owner's Drive holds a masked copy by default; owner can switch masking off for their hostel if the police need the full copy |
| Deleting | The file is the owner's; we only drop our pointer at move-out. Optional "Delete from my Drive" button |
| Other clouds | OneDrive/Outlook via Microsoft Graph works the same way; v2. Zero-tech fallback: tenant sends the ID to the owner on WhatsApp, owner taps "ID received ✓" in the app and we store only that tick |

Honest DPDP note for the founder: we already hold tenant names, phones and rent, which is personal data too, so DPDP applies to
Hostelzy regardless; keeping ID images out of our systems removes the most sensitive part and that is the right move now.
Hostelzy acts as the owner's processor for the upload in transit; the owner is the data fiduciary for the file.

Cost: Google Drive API is free at this scale. Needs the Google Cloud project's OAuth consent screen to list the Drive scope
(founder step, 5 minutes, no card).
