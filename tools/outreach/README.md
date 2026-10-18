# Hostelzy outreach: the WhatsApp sender (F28 28-60)

One message to each listed hostel's owner, from **your own laptop and a separate SIM**, at a human pace. Not part of the
app. Nothing is sent from Hostelzy's servers.

## The message (word for word)
> Hi, this is <your name> from Hostelzy, a free app where tenants find PGs in Hyderabad. <Hostel> is listed as unverified.
> Reply 1 to add your rent and get verified, 2 to remove it. – Hostelzy
> Reply STOP to never hear from us

## The limits (built in; you can't raise them from the command line)
| Rule | Value |
|---|---|
| Messages an hour | 25, with a random 60–180 s gap between two |
| Messages a day | 150 |
| Same number twice | Never (`sent.json` remembers every number, including the ones not on WhatsApp) |
| Someone replies | The run **stops**. You answer by hand on the phone, then start the script again: it carries on with the rest |
| Someone replies STOP | That number is marked and never messaged again |

## The ban risk, in plain words
WhatsApp bans numbers that send the same text to many strangers. These limits lower the chance; they don't remove it.
So: **never your main number.** Buy a SIM for this, put it in a spare phone, use it like a normal person for a week
(a few chats with people you know, a profile photo, a name "Hostelzy · <your name>"), then link it here. If the number is
banned, you lose that SIM, not your own number and not the app. Keep the replies human: the owner is talking to you.

## Run it
1. Node 22 on the laptop. `cd tools/outreach && npm install` (this pulls a headless Chromium, ~300 MB, once).
2. Console › Listed › **To call** → **Export CSV** (columns name, phone, area, id). Save it outside the repo, e.g.
   `~/to-call.csv` (it has phone numbers; `.gitignore` here refuses `*.csv` anyway).
3. See the messages without sending: `node send.mjs --csv ~/to-call.csv --name "Farhath" --dry`
4. Send: `node send.mjs --csv ~/to-call.csv --name "Farhath"` → a QR code → on the spare phone WhatsApp › Linked devices
   › Link a device → scan. The session is kept in `.wwebjs_auth/` (not committed), so the next run won't ask again.
5. Leave the laptop open. The script prints each number as it goes: `98… · sent · Sri Balaji PG · next in 112 s`.
   It stops by itself at the hour limit (waits), the day limit (exits: run again tomorrow) or the first reply.

`sent.json` next to the script is the only record. Delete a number from it only if you really want to message it again.

## What it never does
No groups, no images, no links to anything but the app, no reading of chats except to notice a reply, no second
message to a number, no sending while you're not watching (every run is you starting it).
