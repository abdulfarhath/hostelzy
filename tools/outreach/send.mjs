#!/usr/bin/env node
// Hostelzy outreach (F28 28-60): the founder's WhatsApp sender for listed hostels.
// Runs on a laptop with a SEPARATE SIM linked to WhatsApp Web. Read README.md first:
// ≤ 25 messages an hour with random 60–180 s gaps, ≤ 150 a day, never twice to a number,
// stops on the first reply (the founder answers by hand), "STOP" is final. Nothing here
// touches the app or the database: the list comes from the console's CSV, the record
// of what was sent stays in sent.json next to this file.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pkg from 'whatsapp-web.js';
import qrcode from 'qrcode-terminal';
import { LIMITS, chatId, cleanPhone, gapMs, limitHit, message, msUntilHourSlot, onReply, parseArgs, parseCsv, pending } from './lib.mjs';

const { Client, LocalAuth } = pkg;
const here = path.dirname(fileURLToPath(import.meta.url));
const args = parseArgs(process.argv.slice(2));
const csvPath = typeof args.csv === 'string' ? args.csv : '';
const founder = typeof args.name === 'string' ? args.name : process.env.OUTREACH_NAME || '';
const dry = args.dry === true;
if (!csvPath || !founder) {
  console.log('Usage: node send.mjs --csv to-call.csv --name "Your name" [--dry]');
  process.exit(1);
}

const sentPath = path.join(here, 'sent.json');
const sent = fs.existsSync(sentPath) ? JSON.parse(fs.readFileSync(sentPath, 'utf8')) : {};
const save = () => fs.writeFileSync(sentPath, JSON.stringify(sent, null, 2));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const rows = pending(parseCsv(fs.readFileSync(csvPath, 'utf8')), sent);
console.log(`To send: ${rows.length} · on record: ${Object.keys(sent).length} · limits: ${LIMITS.perHour}/hour, ${LIMITS.perDay}/day`);
if (Object.keys(sent).length === 0) console.log('First run on this SIM · warm it up for a week first (README.md)');
if (!rows.length) process.exit(0);
if (dry) {
  for (const r of rows.slice(0, 3)) console.log(`--- ${r.phone} · ${r.name}\n${message(founder, r.name)}`);
  console.log(`Dry run · ${rows.length} messages · none sent`);
  process.exit(0);
}

const client = new Client({
  authStrategy: new LocalAuth({ dataPath: path.join(here, '.wwebjs_auth') }),
  puppeteer: { args: ['--no-sandbox', '--disable-setuid-sandbox'] },
});
let stopped = '';

client.on('qr', (qr) => {
  qrcode.generate(qr, { small: true });
  console.log('Scan with the outreach SIM · WhatsApp › Linked devices › Link a device');
});

// Any reply from a number we messaged stops the run; the founder answers by hand.
client.on('message', (m) => {
  const from = cleanPhone(String(m.from || '').replace(/@.*$/, ''));
  if (!from) return;
  const e = onReply(sent, from, m.body || '');
  if (!e) return;
  save();
  stopped = `Stopped · reply from ${from}${e.stop ? ' · STOP' : ''}: "${e.reply.slice(0, 60)}"`;
  console.log(stopped);
});

client.on('ready', async () => {
  console.log('Linked · sending');
  for (const r of rows) {
    if (stopped) break;
    const why = limitHit(sent);
    if (why === 'day') {
      console.log(`Day limit ${LIMITS.perDay} · run again tomorrow`);
      break;
    }
    if (why === 'hour') {
      const w = msUntilHourSlot(sent);
      console.log(`Hour limit ${LIMITS.perHour} · waiting ${Math.ceil(w / 60000)} min`);
      await sleep(w);
      if (stopped) break;
    }
    const id = await client.getNumberId(`91${r.phone}`).catch(() => null);
    if (!id) {
      sent[r.phone] = { checkedAt: new Date().toISOString(), hostel: r.name, skipped: 'not on WhatsApp' };
      save();
      console.log(`${r.phone} · not on WhatsApp`);
      continue;
    }
    await client.sendMessage(id._serialized ?? chatId(r.phone), message(founder, r.name));
    sent[r.phone] = { at: new Date().toISOString(), hostel: r.name };
    save();
    const g = gapMs();
    console.log(`${r.phone} · sent · ${r.name} · next in ${Math.round(g / 1000)} s`);
    await sleep(g);
  }
  console.log(stopped || `Done · ${Object.values(sent).filter((e) => e.at).length} sent on record`);
  await client.destroy().catch(() => {});
  process.exit(0);
});

client.initialize();
