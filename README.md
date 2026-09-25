# PROFESSOR-XMD — UI v2 ("Obsidian × Prism")

A full front-end redesign of **professor-xmd-company**. Front-end only: all data is mocked in `src/lib/mock.ts` so the UI can be previewed without the API/DB.

## Run
```bash
npm install
npm run dev     # http://localhost:3000
```

## Screens
| Route | What it is |
| --- | --- |
| `/` | Bento overview: hero composer, stats, team portraits, latest report, live activity, sessions, templates |
| `/board` | Board Room empty state (agent orbit + templates) |
| `/board?prompt=…` | Live simulated session — thinking steps, evidence search, sources, locked decisions, report |
| `/board?session=s-wallet` | Transcript (history) mode |
| `/agents` | Character cards for the 5 agents + "How the board works" |
| `/agents/[id]` | Private 1:1 room with profile column |
| `/reports` | Report library (grid/list, filter, search) + full-screen reader with TOC & PDF export |
| `/sessions` | Session history grouped by date |

Global: sidebar with live agent status, ⌘K command palette, Activity panel (log + token usage), mobile drawer + bottom tabs.

## Design tokens
- Surfaces: `#07080B` → `#1F2430` (obsidian)
- Prism brand gradient (from the logo): `#3D7BFF → #8B5CF6 → #D946EF`
- Agent identity: Optimus `#3B82F6`, Ultron `#A855F7`, Vextron `#F97316`, Megatron `#EF4444`, Cybertron `#84CC16`
- Type: Geist Sans / Geist Mono

## Wiring the real backend
Replace the playback engine in `src/components/board/BoardRoom.tsx` (`run()`) with the NDJSON stream from `/api/boardroom`; the `BoardEvent` types map 1:1 to the items rendered (`round`, `msg_start`, `think`, `search`, `sources`, `token`, `report`).
Original images are kept untouched in `public/original/`; optimized WebP copies are used in the UI.
