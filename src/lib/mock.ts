import type { AgentId } from "./agents";

/* ---------------------------------------------------------------------------
 * Front-end only demo data. No backend — everything here is static so the
 * new UI can be previewed and iterated independently of the API layer.
 * ------------------------------------------------------------------------- */

export interface Source {
  title: string;
  url: string;
  snippet?: string;
}

export interface Session {
  id: string;
  title: string;
  project: string;
  status: "complete" | "live" | "unresolved";
  when: string;
  group: "Today" | "Yesterday" | "This week" | "Earlier";
  rounds: number;
  decisions: number;
  agents: AgentId[];
  tokens: number;
}

export interface Report {
  id: string;
  title: string;
  project: string;
  summary: string;
  created: string;
  readMins: number;
  agents: AgentId[];
  tag: "Fintech" | "EdTech" | "Commerce" | "Health" | "Logistics";
  decisions: number;
  content: string;
}

export interface LogEntry {
  id: string;
  time: string;
  type: "info" | "success" | "warning" | "error" | "api" | "search" | "system";
  message: string;
}


export const DEMO_TITLE = "Mobile wallet for Tanzanian micro-merchants";

export const REPORT_WALLET_MD = `# Ripoti: Wallet ya Wafanyabiashara Wadogo

## 1. Muhtasari
Bodi imekubaliana kujenga **wallet ya simu** kwa wafanyabiashara wadogo Tanzania inayolenga kazi tatu tu kwenye MVP: **kupokea malipo**, **kutoa risiti ya kidijitali**, na **ripoti ya mauzo ya kila siku**.

## 2. Utafiti
- Malipo ya wafanyabiashara ndiyo matumizi ya mobile money yanayokua kwa kasi zaidi Afrika Mashariki.
- Wafanyabiashara wengi wanatumia simu za Android za bei nafuu, mara nyingi wakiwa nje kwenye mwanga mkali.

## 3. Mjadala
Optimus alipendekeza wigo mdogo; Ultron akaongeza sharti la **matumizi kwa kidole kimoja**; Megatron na Cybertron wakakubaliana juu ya integration ya moja kwa moja kwa masharti ya usalama.

## 4. Maamuzi
| Uamuzi | Hali | Wamiliki |
| --- | --- | --- |
| Wigo wa MVP: Pokea · Risiti · Ripoti | LOCKED | Optimus, Ultron, Megatron |
| M-Pesa + Airtel moja kwa moja | LOCKED | Megatron, Cybertron |
| Next.js PWA kwa v1 | LOCKED | Vextron, Ultron |
| Rangi za brand | Inajadiliwa | Ultron |

## 5. Rangi
| Rangi | HEX | Matumizi |
| --- | --- | --- |
| 🟢 Emerald | \`#0F9D6B\` | Vitendo vikuu |
| 🟡 Gold | \`#F2B233\` | Jumla za mauzo |
| ⚫ Ink | \`#0B1220\` | Maandishi |

## 6. Kurasa & Menu
- **Nyumbani** — jumla ya leo na kitufe kikubwa cha *Pokea Malipo*
- **Historia** — miamala yote, utafutaji na vichujio
- **Ripoti** — muhtasari wa siku, wiki na mwezi

## 7. Safari ya Mteja
1. Mfanyabiashara anapokea link kwa SMS na ku-install PWA.
2. Anaunganisha namba yake ya M-Pesa au Airtel.
3. Mteja analipa kupitia QR; risiti inatumwa papo hapo.

## 8. Tech Stack
| Layer | Technology | Purpose |
| --- | --- | --- |
| Frontend | Next.js PWA | App ya mfanyabiashara |
| Backend | Node + Postgres | API na ledger |
| Payments | M-Pesa, Airtel | Kupokea malipo |

## 9. Hatari
| Hatari | Athari | Kinga |
| --- | --- | --- |
| Callback kufika mara mbili | Juu | Idempotency keys |
| Mtandao hafifu | Wastani | Offline queue |

## 10. Action Plan
- **Wiki 1–2:** Design system na prototypes
- **Wiki 3–5:** Payments service na PWA
- **Wiki 6:** Pilot na wafanyabiashara 30 Kariakoo`;

export const REPORTS: Report[] = [
  {
    id: "r-wallet",
    title: "Wallet ya Wafanyabiashara Wadogo",
    project: "Merchant Wallet",
    summary: "MVP ya kupokea malipo ya M-Pesa na Airtel, risiti za kidijitali na ripoti za kila siku kupitia PWA.",
    created: "Today · 14:32",
    readMins: 6,
    agents: ["optimus", "ultron", "vextron", "megatron", "cybertron"],
    tag: "Fintech",
    decisions: 3,
    content: REPORT_WALLET_MD,
  },
  {
    id: "r-school",
    title: "Mfumo wa Ada za Shule",
    project: "SchoolPay",
    summary: "Jukwaa la wazazi kulipa ada kwa awamu, na dashboard ya uhasibu kwa shule binafsi.",
    created: "Yesterday · 18:05",
    readMins: 8,
    agents: ["optimus", "ultron", "megatron", "cybertron"],
    tag: "EdTech",
    decisions: 5,
    content: REPORT_WALLET_MD.replace("Wallet ya Wafanyabiashara Wadogo", "Mfumo wa Ada za Shule"),
  },
  {
    id: "r-duka",
    title: "Duka Online kwa Wajasiriamali",
    project: "DukaLink",
    summary: "Storefront ya WhatsApp-first yenye catalog, oda na malipo ya simu kwa biashara ndogo.",
    created: "Mon · 11:20",
    readMins: 7,
    agents: ["optimus", "vextron", "megatron"],
    tag: "Commerce",
    decisions: 4,
    content: REPORT_WALLET_MD.replace("Wallet ya Wafanyabiashara Wadogo", "Duka Online kwa Wajasiriamali"),
  },
  {
    id: "r-clinic",
    title: "Miadi ya Kliniki kwa SMS",
    project: "AfyaQueue",
    summary: "Kupanga miadi na foleni za kliniki kwa SMS/USSD bila smartphone, na dashboard ya daktari.",
    created: "Sep 18",
    readMins: 5,
    agents: ["optimus", "ultron", "cybertron"],
    tag: "Health",
    decisions: 3,
    content: REPORT_WALLET_MD.replace("Wallet ya Wafanyabiashara Wadogo", "Miadi ya Kliniki kwa SMS"),
  },
  {
    id: "r-boda",
    title: "Usafirishaji wa Vifurushi Mjini",
    project: "BodaSend",
    summary: "Kuunganisha wafanyabiashara na madereva wa boda kwa usafirishaji wa haraka, tracking ya live.",
    created: "Sep 15",
    readMins: 9,
    agents: ["optimus", "ultron", "vextron", "megatron", "cybertron"],
    tag: "Logistics",
    decisions: 6,
    content: REPORT_WALLET_MD.replace("Wallet ya Wafanyabiashara Wadogo", "Usafirishaji wa Vifurushi Mjini"),
  },
  {
    id: "r-sacco",
    title: "Digital SACCO Ledger",
    project: "VICOBA+",
    summary: "Kidijitali cha vikundi vya kuweka akiba: michango, mikopo na uwazi wa hesabu kwa kila mwanachama.",
    created: "Sep 11",
    readMins: 6,
    agents: ["optimus", "megatron", "cybertron"],
    tag: "Fintech",
    decisions: 4,
    content: REPORT_WALLET_MD.replace("Wallet ya Wafanyabiashara Wadogo", "Digital SACCO Ledger"),
  },
];

export const SESSIONS: Session[] = [
  { id: "s-wallet", title: DEMO_TITLE, project: "Merchant Wallet", status: "complete", when: "14:32", group: "Today", rounds: 4, decisions: 3, agents: ["optimus", "ultron", "vextron", "megatron", "cybertron"], tokens: 48210 },
  { id: "s-brand", title: "Brand refresh for DukaLink storefront", project: "DukaLink", status: "unresolved", when: "09:10", group: "Today", rounds: 3, decisions: 1, agents: ["optimus", "ultron", "vextron"], tokens: 21904 },
  { id: "s-school", title: "School fee instalments platform", project: "SchoolPay", status: "complete", when: "18:05", group: "Yesterday", rounds: 5, decisions: 5, agents: ["optimus", "ultron", "megatron", "cybertron"], tokens: 61337 },
  { id: "s-auth", title: "Phone-number auth without SMS costs", project: "SchoolPay", status: "complete", when: "10:44", group: "Yesterday", rounds: 2, decisions: 2, agents: ["megatron", "cybertron", "optimus"], tokens: 15820 },
  { id: "s-duka", title: "WhatsApp-first storefront MVP", project: "DukaLink", status: "complete", when: "Mon", group: "This week", rounds: 4, decisions: 4, agents: ["optimus", "vextron", "megatron"], tokens: 39455 },
  { id: "s-clinic", title: "USSD clinic queue system", project: "AfyaQueue", status: "complete", when: "Sep 18", group: "Earlier", rounds: 3, decisions: 3, agents: ["optimus", "ultron", "cybertron"], tokens: 27102 },
  { id: "s-boda", title: "Last-mile delivery with boda riders", project: "BodaSend", status: "complete", when: "Sep 15", group: "Earlier", rounds: 6, decisions: 6, agents: ["optimus", "ultron", "vextron", "megatron", "cybertron"], tokens: 70221 },
];

export const LOGS: LogEntry[] = [
  { id: "l1", time: "14:31:02", type: "system", message: "Board convened · 5 agents · 4 rounds planned" },
  { id: "l2", time: "14:31:04", type: "api", message: "Optimus → deepseek-v4-pro · 1,284 tokens" },
  { id: "l3", time: "14:31:05", type: "search", message: "Evidence gate: “Tanzania mobile money 2026” · 3 sources" },
  { id: "l4", time: "14:31:19", type: "success", message: "Round 1 decision LOCKED — MVP scope" },
  { id: "l5", time: "14:31:40", type: "search", message: "Megatron searched M-Pesa Open API docs · 4 sources" },
  { id: "l6", time: "14:31:52", type: "warning", message: "Airtel docs rate-limited — retried after 2s" },
  { id: "l7", time: "14:32:10", type: "success", message: "Round 2 decision LOCKED — payments" },
  { id: "l8", time: "14:32:22", type: "api", message: "Vextron → qwen3.6-coder · 2,011 tokens" },
  { id: "l9", time: "14:32:30", type: "success", message: "Report filed · Ripoti: Wallet ya Wafanyabiashara" },
];

export const USAGE: Record<AgentId, { requests: number; tokens: number }> = {
  optimus: { requests: 14, tokens: 15420 },
  ultron: { requests: 9, tokens: 8904 },
  vextron: { requests: 7, tokens: 9311 },
  megatron: { requests: 8, tokens: 10288 },
  cybertron: { requests: 6, tokens: 4287 },
};

export const WEEK_ACTIVITY = [4, 7, 5, 9, 6, 11, 8, 12, 9, 14, 10, 16];
