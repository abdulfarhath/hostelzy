# Hostelzy: rules for every Claude chat working on this repo

Hostelzy is a Hyderabad PG/hostel app: tenants find and hold beds, residents
manage their stay, owners run their hostel. The Flutter app is in `hostelzy/`.
The original Claude Design handoff is in `project/` and `chats/`.

Three chats work on this repo at the same time. Each has one role.

| Chat | Role | Writes to |
|---|---|---|
| **Hostelzy · Ideas** | Founder's product partner: ideas, specs, status | `docs/` only |
| **Hostelzy · Design** | Designer: mockups for spec-ready features | `docs/features/*` (Design section), artifacts |
| **Hostelzy · Build** | Developer: builds design-approved features | `hostelzy/` code, `docs/features/*` (Build section), `docs/BOARD.md` status |

## Always, first

1. `git pull` then read `docs/BOARD.md`, `docs/DECISIONS.md` and the feature
   file you are working on in `docs/features/`.
2. Never contradict `docs/DECISIONS.md`. If something there seems wrong, ask
   the founder; don't change it on your own.
3. Before you finish a turn, commit and push what you changed (docs or code),
   so the other chats see it. The repo is the shared memory: chats do not see
   each other's conversations.

## Standing approval (founder, 2026-10-02)

The founder has approved every design and every merge in advance. Design marks finished designs
**Design approved** itself; Build merges its own PR to `main` once `flutter analyze` is clean and
`flutter test` passes. Accounts, money and changes to business rules still need the founder.
This overrides the "only the founder approves" lines below until the founder says otherwise.

## Feature stages (`docs/BOARD.md`)

`Idea → Spec ready → Designing → Design ready → Design approved → Building → Built → Shipped`

- Only the **founder** approves. "Spec approved", "Design approved" and
  "Merge" happen only when the founder says so in the chat. Record it in the
  board with the date.
- Ideas chat moves features up to **Spec ready**.
- Design chat takes **Spec ready / approved** features, moves them to
  **Designing → Design ready**, adds the design link to the feature file.
- Build chat only starts features marked **Design approved** (or marked
  "no design needed" in the spec), moves them **Building → Built**.

## Design chat rules

- Match the existing app exactly: Archivo font, `#ec3013` red for actions,
  green `#1f7a3d` / `#dcefe0` only for savings and Hostelzy deals, 2px rules,
  square corners, light + dark. Tokens: `hostelzy/lib/ui/kit.dart` (`Pal`).
- Phone screens are 390×844. Use the Claude Design canvas artifact type.
  Existing mockups: https://claude.ai/artifact/F4zedqxzj4cfsrJe6Y92Wn
- Put the link and a short screen list in the feature file's **Design**
  section. Ask the founder to approve.

## Build chat rules

- Work on a branch `feature/<id>-<name>` (e.g. `feature/f05-enquiries`).
  Never push unapproved work to `main`: pushes to `main` publish an APK.
- Keep the design fidelity rules in `hostelzy/README.md` (use `T`, `CssLine`,
  `Pal` tokens, `Cta`, `Seg`, etc. from `lib/ui/kit.dart` and `common.dart`).
- Every feature gets a flow test in `hostelzy/test/`. Before saying done:
  `flutter analyze` clean and `flutter test` passing.
- Open a pull request, write what changed in the feature file's **Build**
  section, set the board to **Built**, and ask the founder to merge.
- Until the backend exists, features run on sample data in `AppState`.

## Ideas chat rules

- Discuss, then write a short spec in `docs/features/<id>-<name>.md`
  (problem, user stories per role, screens, rules, open questions).
- Record agreed decisions in `docs/DECISIONS.md` with the date.
- When asked for status, read the board and the other chats' progress.
