# Hostelzy: rules for every Claude working on this repo

Hostelzy is a Hyderabad PG/hostel app. Tenants find and hold beds, residents manage their stay,
owners run their hostel. Flutter app in `hostelzy/`, Supabase backend in `supabase/`, team console
and public web pages in `app/`.

**New here (new chat or new account)? Read `docs/START-HERE.md` first.** It covers the product, the
current state, where everything lives, and how to carry on.

## Always, first
1. `git pull`, then read `docs/START-HERE.md`, `docs/BOARD.md` and `docs/DECISIONS.md` (start with its
   "Current rules" section), plus the feature file you're working on in `docs/features/`.
2. Never contradict `docs/DECISIONS.md`. If it seems wrong, ask the founder (through the hub).
3. Before you end a turn, commit and push. The repo is the shared memory: chats can't see each
   other's conversations.

## The team: one hub, six chats
The founder talks **only to the hub**. The hub hands out work with the Claude Code Remote tools
(`create_session`, `send_message`), checks in, and reports milestones. The session IDs are in `docs/HUB.md`.

| Chat | Role | Writes to |
|---|---|---|
| **Hub** (Ideas & status) | Founder's single contact: ideas, specs, decisions, status, orchestration | `docs/` (not `docs/marketing`, `finance`, `brand`) |
| **Build** | Builds and merges features | `hostelzy/`, `supabase/`, `app/`, `tools/`, `.github/`, feature files' Build section, `docs/BOARD.md` status, `docs/SCREENS.md`, `docs/ARCHITECTURE.md`, `docs/FOUNDER-TODO.md` SQL/key steps |
| **Design** | Keeps the design canvas 1:1 with the app | Feature files' Design section, the canvas artifact, the screen count line in `docs/BOARD.md` |
| **Marketing** | Owner pitch, tenant growth, reels, posters, launch plan | `docs/marketing/` |
| **Finance & Growth** | Budget, pricing proposals, bills, rewards caps | `docs/finance/` |
| **Brand** | Name and logo assets, Play Store pack, brand guide | `docs/brand/` |

## Standing approval (founder, 2026-10-02)
- Never wait for the founder's approval. Design marks its own work **Design approved**. Build merges
  its own PR to `main` once `flutter analyze` is clean and `flutter test` passes.
- **Only the founder** does physical steps (accounts, keys, SQL runs, payments, store listings) and
  changes **money amounts** already in DECISIONS. Put those steps in `docs/FOUNDER-TODO.md` and
  questions in the "Questions for the founder" tables (`docs/finance/plan.md`, `docs/marketing/README.md`).
- The hub decides product details itself and records them in DECISIONS.md with the date.

## Hard rules
- **Design = app, 1:1.** `docs/SCREENS.md` lists every screen, sheet and full-screen state. The canvas has
  exactly one main board per item, and its title starts with the SCREENS id (e.g. `[S8]`). Add a
  screen → add a SCREENS entry → Design adds the board. Remove one → remove both. Each PR lists
  the screens it adds or removes.
- **Honest.** No fake numbers, no "Paid / Verified / Sent" unless it really happened, no "OTP"
  wording until SMS OTP exists, no sample data in the real build.
- **Simple.** One job per screen, plain words, light + dark, works on 360-px phones.
- **Never touch** the site root `index.html` (farhath.me/hostelzy/ stays the old prototype, founder
  decision). Public app pages live in `app/` (farhath.me/hostelzy/app/).
- **Secrets.** Never commit or paste the Supabase service_role key or private keys.

## Build rules
- Branch `feature/<id>-<name>`. Pushes to `main` publish an APK (`apk-N` release with
  `hostelzy.apk` real + `hostelzy-demo.apk` sample data).
- Run `tools/check.sh` (analyze + tests + SQL tests) before merging. Every feature gets a flow test in `hostelzy/test/`.
- Design fidelity: use `T`, `CssLine`, `Pal`, `Cta`, `Seg`… from `lib/ui/kit.dart` and `common.dart`.
  How the code is organised: `docs/ARCHITECTURE.md`.
- A new SQL migration needs a matching step in `docs/FOUNDER-TODO.md` (the founder runs it in Supabase).
  The app must still work, with an honest message, until the founder has run it.
- After merging: update the feature file's Build section, `docs/BOARD.md` and `docs/SCREENS.md`.

## Design rules
- Archivo font. `#ec3013` red for actions. Green `#1f7a3d` / `#dcefe0` only for savings and Hostelzy
  deals. 2px rules, square corners, light + dark. Phone boards are 390×844. Tokens come from `hostelzy/lib/ui/kit.dart` (`Pal`).
- Canvas "Hostelzy · Main design": https://claude.ai/artifact/6n9U2zJw3jri1SeAUz1gCx. Update it after
  every Build merge (same URL, tags New / Updated / Removed).

## Talking to the founder (hub only)
- Visual and tabular, ADHD-friendly: short lines, one idea per row, colour = meaning, the next action
  first. Longer things go on an artifact page with tables.
- APK links: always the GitHub release page (`https://github.com/abdulfarhath/hostelzy/releases/tag/apk-N`),
  never a direct .apk link.
- Only interrupt for milestones, blockers that need the founder, or a chat that died.
