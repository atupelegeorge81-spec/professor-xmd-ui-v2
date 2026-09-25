import type { AgentId } from "@/lib/agents";
import type { Source } from "@/lib/mock";
import type { AgendaDef, Signal, TaskKind } from "./types";

/* ---------------------------------------------------------------------------
 * DEMO SESSION — "beats" zinazochezwa na usePlayback. Hadithi hii imeundwa
 * kupitia KILA tukio la engine halisi (angalia research EVENT-INVENTORY):
 * cache hit/miss, search retry, relevance stale, memory hit, proposal reset,
 * chair challenge, code + review reject + patch, objection → supersede,
 * objection rejected, agenda OPEN, validator, assembly, report repair,
 * memory checkpoints / reflection / consolidation.
 * ------------------------------------------------------------------------- */

const S = (title: string, url: string, snippet?: string): Source => ({ title, url, snippet });

export type Beat =
  | { do: "convene"; title: string; sessionId: string }
  | { do: "task"; task: TaskKind; agent: AgentId; text: string; ms: number; result?: string }
  | { do: "scope"; text: string }
  | { do: "agendaBuild"; items: AgendaDef[] }
  | { do: "agendaStart"; index: number }
  | {
      do: "evidence"; agent: AgentId; variant: "gate" | "research" | "objection"; query: string;
      cache: "hit" | "miss" | "skip"; similarity?: number; matched?: string;
      stale?: boolean; memoryHit?: boolean; engineFails?: number; sources: Source[];
    }
  | {
      do: "turn"; agent: AgentId; role: "owner" | "observer" | "responder" | "chair" | "writer";
      thinking: string[]; content: string; target?: string; seconds: number;
      retry?: { model: string; rotateTo?: string; stage?: string };
      skill?: { name: string; found: boolean };
    }
  | { do: "consensus"; event: "proposed" | "reset" | "agreed" | "reached" | "exhausted"; by: AgentId; version: number; approvals: AgentId[] }
  | { do: "chair"; target: AgentId; reason: Signal; text: string }
  | { do: "script"; agent: AgentId; file: string; lang: string; parts: string[] }
  | { do: "review"; agent: AgentId; verdict: "approve" | "reject"; round: number; notes: string[] }
  | { do: "patch"; agent: AgentId; file: string; reason: "review" | "objection"; hunks: { line: number; old: string[]; new: string[] }[] }
  | { do: "deliverable"; agent: AgentId; file: string; agenda: string }
  | { do: "memory"; scope: "agenda" | "reflection" | "consolidate"; agenda?: number; none?: AgentId[] }
  | {
      do: "seal"; index: number; status: "LOCKED" | "OPEN"; version: number; decision: string;
      rationale?: string; tradeoff?: string; constraints: string[]; sources: number; ledgerId: string; supersedes?: string;
    }
  | { do: "observers"; index: number; observers: AgentId[]; objection?: { agent: AgentId; concern: string } }
  | { do: "supersede"; index: number; objector: AgentId; responder: AgentId; from: { ledgerId: string; text: string }; to: { ledgerId: string; text: string } }
  | { do: "overruled"; objector: AgentId; responder: AgentId; concern: string; reason: string }
  | { do: "validator"; scope: "ledger" | "report"; rows: { index: number; title: string; final: "locked" | "open" | "missing" | "ok" | "stitched" }[] }
  | { do: "notice"; tone: "retry" | "rotate" | "warn" | "error" | "halt" | "info"; agent?: AgentId; text: string; detail?: string }
  | { do: "assembly"; file: string; pieces: { agenda: number; agent: AgentId; file: string; lines: number }[]; parts: string[] }
  | { do: "report"; title: string; reportId: string; parts: { sections: number[]; text: string }[]; missing: number[]; repairText: string }
  | { do: "summary" };

export const STAGE_TITLE = "Wallet ya Wafanyabiashara Wadogo";
export const STAGE_PROMPT =
  "Tunataka kujenga app ya wallet ya simu kwa wafanyabiashara wadogo Tanzania — malipo ya M-Pesa, Airtel Money na risiti za kidijitali.";

export const STAGE_AGENDA: AgendaDef[] = [
  { index: 1, title: "Upeo wa bidhaa & MVP", owners: ["optimus", "ultron"], requiresCode: false },
  { index: 2, title: "Muunganiko wa malipo (M-Pesa + Airtel)", owners: ["megatron", "cybertron"], requiresCode: true },
  { index: 3, title: "Utambulisho wa muonekano", owners: ["ultron", "vextron"], requiresCode: false },
  { index: 4, title: "Bei ya huduma kwa mfanyabiashara", owners: ["optimus", "megatron"], requiresCode: false },
];

export const REPORT_SECTIONS = [
  "Muhtasari", "Utafiti", "Mjadala", "Maamuzi", "Rangi",
  "Kurasa & Menu", "Safari ya Mteja", "Tech Stack", "Hatari", "Action Plan",
];

const PAY_TS_1 = `import { createHmac, timingSafeEqual } from "node:crypto";
import { db } from "./db";

export type Provider = "mpesa" | "airtel";
export interface PaymentProvider {
  collect(phone: string, amount: number, ref: string): Promise<string>;
  verify(raw: string, signature: string): boolean;
}

/** Callback moja kwa kila muamala — idempotency key ni lazima */
export async function onCallback(p: Provider, raw: string, sig: string) {
  const evt = JSON.parse(raw) as { txId: string; amount: number; status: string };`;
const PAY_TS_2 = `
  const key = \`\${p}:\${evt.txId}\`;
  const seen = await db.callback.findUnique({ where: { key } });
  if (seen) return { ok: true, duplicate: true };
  await db.callback.create({ data: { key, raw, status: evt.status } });
  await db.ledger.credit(evt.txId, evt.amount);
  return { ok: true, duplicate: false };
}

export async function reconcile(p: Provider) {
  const statement = await fetchStatement(p);
  return db.ledger.diff(statement); // kila dakika 15
}`;

const TEST_TS = `import { describe, it, expect } from "vitest";
import { onCallback } from "./payments";

describe("callbacks", () => {
  it("haipokei callback mara mbili", async () => {
    const raw = JSON.stringify({ txId: "MP-771", amount: 5000, status: "SUCCESS" });
    const a = await onCallback("mpesa", raw, sign(raw));
    const b = await onCallback("mpesa", raw, sign(raw));
    expect(a.duplicate).toBe(false);
    expect(b.duplicate).toBe(true);
  });
  it("inakataa signature batili", async () => {
    await expect(onCallback("airtel", "{}", "bad")).rejects.toThrow("signature");
  });
});`;

const FINAL_1 = `// wallet-payments.ts — script moja kamili (Agenda 2 · v2)
import { createHmac, timingSafeEqual } from "node:crypto";
import { db } from "./db";

export type Provider = "mpesa" | "airtel";
export type TxStatus = "PENDING" | "SUCCESS" | "FAILED";
`;
const FINAL_2 = `
export async function onCallback(p: Provider, raw: string, sig: string) {
  if (!verifySignature(p, raw, sig)) throw new Error("signature");
  const evt = JSON.parse(raw) as { txId: string; amount: number; status: TxStatus };
  const key = \`\${p}:\${evt.txId}\`;
  if (await db.callback.findUnique({ where: { key } })) return { ok: true, duplicate: true };
  await db.callback.create({ data: { key, raw, status: evt.status } });
  if (evt.status === "SUCCESS") await db.ledger.credit(evt.txId, evt.amount);
  return { ok: true, duplicate: false };
}

export const statusOf = (txId: string) => db.tx.status(txId); // PENDING kwa PWA offline`;

/* ---------------- ripoti (inastreamiwa live kwenye Board Room) ---------------- */
const REPORT_PART_1 = `## 1. Muhtasari
Wallet ya simu kwa **wafanyabiashara wadogo Tanzania**: kupokea malipo ya M-Pesa na Airtel Money, kuthibitisha kila muamala papo hapo, na kutoa risiti ya kidijitali inayoshirikiwa WhatsApp. Lengo la MVP ni kazi tatu tu — **Pokea, Thibitisha, Muhtasari** — kwenye simu za bei nafuu na mtandao usio imara.

## 2. Utafiti
- Malipo ya simu kwa wafanyabiashara yanakua kwa kasi Afrika Mashariki; wengi bado wanathibitisha kwa SMS peke yake [1].
- Simu nyingi ni Android za bei nafuu — skrini ndogo, mwanga mkali wa nje, operesheni ya kidole kimoja [2].
- Callback za malipo zinaweza kufika mara mbili au kuchelewa — idempotency ni lazima [3].

## 3. Mjadala
Optimus alianza na MVP ya kazi tatu; Ultron akapinga risiti za SMS peke yake na kuleta **risiti-kadi** inayoshirikiwa WhatsApp. Megatron na Cybertron walikubaliana kwenye muunganiko wa moja kwa moja badala ya aggregator. Vextron aliwasilisha pingamizi la PWA offline — likakubaliwa na uamuzi wa Agenda 2 ukasasishwa hadi v2.

## 4. Maamuzi
| Agenda | Uamuzi | Hali |
| --- | --- | --- |
| A1 · MVP | Pokea · Thibitisha · Muhtasari + risiti-kadi | LOCKED |
| A2 · Malipo | PaymentProvider + idempotency + PENDING (v2) | LOCKED |
| A3 · Muonekano | Emerald · Gold · Ink · Mist, CSS variables | LOCKED |
| A4 · Bei | Flat TSh 5,000 dhidi ya 0.8% | Inajadiliwa |

## 5. Rangi
- \`#0F9D6B\` Emerald — rangi kuu, vitufe na hali ya SUCCESS.
- \`#F2B233\` Gold — highlight tu, maandishi makubwa (≥ 24px).
- \`#0B1220\` Ink na \`#F4F6F8\` Mist — msingi wa dark / light.`;

const REPORT_PART_2 = `## 6. Kurasa & Menu
- **Nyumbani** — salio la leo, kitufe kikubwa cha *Pokea Malipo*.
- **Pokea Malipo** — QR / till number, hali ya PENDING → SUCCESS kwa wakati halisi.
- **Historia** — kila muamala na risiti yake, utafutaji kwa namba ya simu.
- **Muhtasari wa siku** — jumla, idadi ya miamala, tofauti za reconciliation.

## 8. Tech Stack
Next.js PWA (offline-first) · Postgres · \`PaymentProvider\` kwa M-Pesa Open API na Airtel Collection API · HMAC + timestamp + IP allow-list kwa callbacks · reconciliation kila dakika 15 · risiti-kadi kama picha ya PNG kwa WhatsApp.

## 9. Hatari
- **Uptime ya callbacks** ni jukumu letu — tunahitaji monitoring na alert ya mismatch > 0.5%.
- **Double-submit offline** — imezuiwa na hali ya PENDING na endpoint ya status.
- **Bei (A4) haijafungwa** — pilot ya wafanyabiashara 50 kabla ya kuamua.

## 10. Action Plan
1. Wiki 1–2: payments core, idempotency na callbacks salama.
2. Wiki 3: risiti-kadi na kushiriki WhatsApp.
3. Wiki 4: muhtasari wa siku na reconciliation.
4. Wiki 5–6: pilot ya wafanyabiashara 50, kisha kufunga bei.`;

const REPORT_REPAIR = `## 7. Safari ya Mteja
Mteja anachanganua QR ya mfanyabiashara → analipa kwa M-Pesa au Airtel Money → skrini ya mfanyabiashara inaonyesha **PENDING** → callback inathibitishwa → **SUCCESS** → risiti-kadi inatumwa WhatsApp ndani ya sekunde chache. Mtandao ukikatika, muamala unabaki PENDING na unathibitishwa mtandao ukirudi.`;

export const STAGE_BEATS: Beat[] = [
  /* ================= OPENING ================= */
  { do: "convene", title: STAGE_TITLE, sessionId: "6f1c2a9e" },
  { do: "task", task: "agenda", agent: "optimus", text: "Optimus anaunda agenda ya mradi…", ms: 2200 },
  {
    do: "scope",
    text: "Mkuu anataka wallet rahisi ya kupokea malipo ya M-Pesa na Airtel Money, yenye risiti ya kidijitali inayoaminika — kwa simu za bei nafuu na mtandao usio imara.",
  },
  { do: "agendaBuild", items: STAGE_AGENDA },

  /* ================= AGENDA 1 — MVP (proposal reset, cache hit/miss, search retry) ================= */
  { do: "agendaStart", index: 1 },
  {
    do: "evidence", agent: "optimus", variant: "gate", query: "merchant mobile money adoption East Africa 2026 small business",
    cache: "hit", similarity: 91.4, matched: "mobile money merchant payments growth east africa",
    sources: [
      S("Mobile money in East Africa 2026", "https://www.gsma.com/mobilefordevelopment", "Merchant payments ndio matumizi yanayokua kwa kasi zaidi."),
      S("Communications Statistics — Q2 2026", "https://www.tcra.go.tz/publications", "Akaunti za mobile money zinaendelea kukua."),
    ],
  },
  {
    do: "evidence", agent: "ultron", variant: "gate", query: "low-end android outdoor readability one-thumb UX fintech",
    cache: "miss", similarity: 62.8, engineFails: 1,
    sources: [
      S("Designing for one-handed use", "https://www.nngroup.com/articles/mobile-ux", "Thumb zone na vitendo vikuu chini ya skrini."),
      S("Outdoor contrast guidelines", "https://m3.material.io/foundations/accessible-design", "Contrast ya juu kwa jua kali."),
      S("Android Go device profile 2026", "https://developer.android.com/guide/topics/androidgo", "RAM ndogo, storage ndogo."),
    ],
  },
  {
    do: "turn", agent: "optimus", role: "owner", seconds: 6,
    thinking: [
      "Kazi kuu ya mfanyabiashara ni kupokea pesa na kuthibitisha amepokea.",
      "Evidence: merchant payments ndio matumizi yanayokua zaidi — MVP iwe nyembamba.",
    ],
    content:
      "Napendekeza MVP iwe na kazi tatu tu — **Pokea**, **Thibitisha**, **Muhtasari**. Mikopo na stoo ni awamu ya pili [1].\n\nPROPOSED DECISION: MVP = kupokea malipo (QR/till moja kwa M-Pesa + Airtel), risiti ya papo hapo kwa SMS, na muhtasari wa mauzo wa kila siku.\nRATIONALE: Ndio kazi inayolipa mfanyabiashara kila siku; evidence inaonyesha merchant payments zinaongoza ukuaji.\nTRADE-OFF: Mikopo na stoo vinasubiri awamu ya 2.\nEVIDENCE: GSMA 2026, TCRA Q2 2026.",
  },
  { do: "consensus", event: "proposed", by: "optimus", version: 1, approvals: ["optimus"] },
  {
    do: "turn", agent: "ultron", role: "owner", seconds: 5,
    thinking: ["Risiti kwa SMS pekee haiwezi kusambazwa kama picha — wateja wanatumia WhatsApp."],
    content:
      "DISAGREE: Risiti kwa SMS pekee haitoshi — wateja wengi wanashare kwenye WhatsApp, na SMS haionyeshi chapa ya mfanyabiashara.\n\nPROPOSED DECISION: MVP = kupokea malipo (QR/till moja), **risiti kama kadi inayoshirikiwa** (WhatsApp + SMS fallback), muhtasari wa kila siku, na skrini kuu yenye kitufe kimoja kikubwa *Pokea Malipo*.\nRATIONALE: One-thumb operation kwenye simu za bei nafuu [1][3].\nTRADE-OFF: Kazi ya ziada ya kutengeneza kadi ya risiti.\nEVIDENCE: NN/g one-handed use, Android Go profile.",
  },
  { do: "consensus", event: "reset", by: "ultron", version: 2, approvals: ["ultron"] },
  {
    do: "turn", agent: "optimus", role: "owner", seconds: 3,
    thinking: ["Pendekezo la Ultron linaboresha bila kupanua upeo sana."],
    content: "AGREE: Nakubali v2 — kwa sharti kwamba kadi ya risiti ifanye kazi hata bila data (itengenezwe kwenye simu, itumwe mtandao ukirudi).",
  },
  { do: "consensus", event: "reached", by: "optimus", version: 2, approvals: ["ultron", "optimus"] },
  { do: "task", task: "mini", agent: "optimus", text: "Optimus anaandika mini report…", ms: 2000 },
  { do: "task", task: "lock", agent: "optimus", text: "Optimus anafunga agenda kwenye Ledger…", ms: 1300, result: "LOCKED" },
  {
    do: "seal", index: 1, status: "LOCKED", version: 2, ledgerId: "a1f3c9",
    decision: "MVP = kupokea malipo (QR/till moja), risiti kama kadi inayoshirikiwa (WhatsApp + SMS fallback), muhtasari wa kila siku, skrini kuu yenye kitufe kimoja *Pokea Malipo*.",
    rationale: "One-thumb operation kwenye simu za bei nafuu; merchant payments zinaongoza ukuaji.",
    tradeoff: "Mikopo na stoo — awamu ya 2.",
    constraints: ["Kadi ya risiti lazima itengenezwe offline", "Kiswahili kwanza, Kiingereza pili"],
    sources: 5,
  },
  { do: "memory", scope: "agenda", agenda: 1, none: ["cybertron"] },
  { do: "observers", index: 1, observers: ["vextron", "megatron", "cybertron"] },

  /* ================= AGENDA 2 — PAYMENTS (stale cache, memory hit, retry+rotation, code, review, patch, objection → supersede) ================= */
  { do: "agendaStart", index: 2 },
  {
    do: "evidence", agent: "megatron", variant: "gate", query: "mobile money C2B API callback idempotency reconciliation",
    cache: "hit", similarity: 84.2, matched: "payment api idempotency keys", stale: true,
    sources: [
      S("M-Pesa Open API — Developer Portal", "https://openapiportal.m-pesa.com", "C2B, callbacks na query transaction."),
      S("Airtel Africa Developers", "https://developers.airtel.africa", "Collection API na callbacks."),
      S("Idempotency keys in payment APIs", "https://stripe.com/docs/api/idempotent_requests", "Retry bila kulipisha mara mbili."),
    ],
  },
  {
    do: "evidence", agent: "cybertron", variant: "gate", query: "webhook signature verification IP allowlist payment callbacks",
    cache: "miss", similarity: 71.0,
    sources: [
      S("Verifying webhook signatures", "https://docs.github.com/webhooks/using-webhooks/validating-webhook-deliveries", "HMAC + timing-safe compare."),
      S("OWASP — Payment callbacks", "https://owasp.org/www-project-api-security", "Allow-list na replay protection."),
    ],
  },
  {
    do: "turn", agent: "megatron", role: "owner", seconds: 8,
    thinking: [
      "Njia mbili: M-Pesa na Airtel — kila moja ina API na callback yake.",
      "Callbacks zinaweza kufika mara mbili au kuchelewa — idempotency ni lazima.",
    ],
    content:
      "PROPOSED DECISION: Muunganiko wa moja kwa moja na M-Pesa Open API + Airtel Collection API nyuma ya interface moja `PaymentProvider`; kila callback ina idempotency key; reconciliation kila dakika 15.\nRATIONALE: Aggregator ana ada zinazoumiza wafanyabiashara wadogo [1][2].\nTRADE-OFF: Tunabeba jukumu la uptime na usalama wenyewe.\nEVIDENCE: M-Pesa Open API, Airtel docs, Stripe idempotency [3].",
  },
  { do: "consensus", event: "proposed", by: "megatron", version: 1, approvals: ["megatron"] },
  {
    do: "turn", agent: "cybertron", role: "owner", seconds: 4, retry: { model: "qwen3-coder-plus", rotateTo: "glm-5-air", stage: "Groq" },
    thinking: ["Nahitaji kuthibitisha kama signature za callback zinaweza kurudiwa (replay)."],
    content:
      "INSUFFICIENT_EVIDENCE: Sijaona ushahidi wa jinsi ya kuzuia replay ya callback iliyosainiwa.\n\nRESEARCH_REQUEST: webhook replay protection timestamp signature",
  },
  {
    do: "evidence", agent: "cybertron", variant: "research", query: "webhook replay protection timestamp signature",
    cache: "skip", memoryHit: true,
    sources: [S("Verifying webhook signatures", "https://docs.github.com/webhooks/using-webhooks/validating-webhook-deliveries", "HMAC + timing-safe compare.")],
  },
  {
    do: "turn", agent: "cybertron", role: "owner", seconds: 3,
    thinking: ["Memory ya mjadala ina jibu — timestamp window + HMAC."],
    content: "AGREE: Nakubali, kwa sharti: kila callback ithibitishwe kwa HMAC + timestamp (dirisha la dakika 5) + IP allow-list, na alert ikiwa reconciliation mismatch > 0.5%.",
  },
  { do: "consensus", event: "reached", by: "cybertron", version: 1, approvals: ["megatron", "cybertron"] },
  { do: "script", agent: "megatron", file: "payments.ts", lang: "typescript", parts: [PAY_TS_1, PAY_TS_2] },
  { do: "script", agent: "cybertron", file: "payments.test.ts", lang: "typescript", parts: [TEST_TS] },
  {
    do: "review", agent: "optimus", verdict: "reject", round: 1,
    notes: ["onCallback haithibitishi signature (HMAC + timestamp) kama ilivyofungwa", "Hakuna status PENDING/FAILED — credit inafanyika hata status ikiwa FAILED"],
  },
  {
    do: "patch", agent: "megatron", file: "payments.ts", reason: "review",
    hunks: [
      { line: 13, old: ["  const evt = JSON.parse(raw) as { txId: string; amount: number; status: string };"], new: ["  if (!verifySignature(p, raw, sig)) throw new Error(\"signature\");", "  const evt = JSON.parse(raw) as { txId: string; amount: number; status: TxStatus };"] },
      { line: 18, old: ["  await db.ledger.credit(evt.txId, evt.amount);"], new: ["  if (evt.status === \"SUCCESS\") await db.ledger.credit(evt.txId, evt.amount);"] },
    ],
  },
  { do: "review", agent: "optimus", verdict: "approve", round: 2, notes: [] },
  { do: "deliverable", agent: "megatron", file: "payments.ts", agenda: "Muunganiko wa malipo" },
  { do: "deliverable", agent: "cybertron", file: "payments.test.ts", agenda: "Muunganiko wa malipo" },
  { do: "task", task: "mini", agent: "optimus", text: "Optimus anaandika mini report…", ms: 1800 },
  { do: "task", task: "lock", agent: "optimus", text: "Optimus anafunga agenda kwenye Ledger…", ms: 1200, result: "LOCKED" },
  {
    do: "seal", index: 2, status: "LOCKED", version: 1, ledgerId: "b7e210",
    decision: "M-Pesa Open API + Airtel Collection API nyuma ya `PaymentProvider`; idempotency key kwa kila callback; HMAC + timestamp + IP allow-list; reconciliation kila dakika 15.",
    rationale: "Ada za aggregator zinaumiza wafanyabiashara wadogo.",
    tradeoff: "Jukumu la uptime na usalama ni letu.",
    constraints: ["Callback bila signature halali = kataa", "Alert mismatch > 0.5%"],
    sources: 6,
  },
  { do: "memory", scope: "agenda", agenda: 2 },
  {
    do: "observers", index: 2, observers: ["ultron", "vextron", "optimus"],
    objection: { agent: "vextron", concern: "PWA inafanya kazi offline — bila endpoint ya status PENDING mteja atabonyeza 'Pokea' mara mbili na risiti itatoka kabla malipo hayajathibitishwa." },
  },
  { do: "task", task: "query", agent: "optimus", text: "Optimus anatengeneza search query ya pingamizi…", ms: 1400 },
  {
    do: "evidence", agent: "megatron", variant: "objection", query: "offline PWA payment pending state double submit prevention",
    cache: "skip", engineFails: 0,
    sources: [
      S("Background Sync API", "https://developer.mozilla.org/docs/Web/API/Background_Synchronization_API", "Actions zinasubiri mtandao."),
      S("Designing payment status UX", "https://www.smashingmagazine.com/payment-status-ux", "Pending state inazuia double submit."),
    ],
  },
  {
    do: "turn", agent: "megatron", role: "responder", seconds: 5,
    thinking: ["Pingamizi ni halali — PWA offline inahitaji hali ya PENDING."],
    content:
      "UPDATED DECISION: Ongeza hali ya muamala `PENDING → SUCCESS | FAILED` na endpoint `GET /tx/:id/status`; risiti inatolewa **tu** baada ya SUCCESS.\nRATIONALE: Inazuia double-submit kwenye PWA offline na risiti za uongo [2].",
  },
  {
    do: "patch", agent: "megatron", file: "payments.ts", reason: "objection",
    hunks: [{ line: 22, old: [], new: ["export const statusOf = (txId: string) => db.tx.status(txId); // PENDING kwa PWA offline"] }],
  },
  { do: "task", task: "mini", agent: "optimus", text: "Optimus anaandika mini report…", ms: 1500 },
  { do: "task", task: "relock", agent: "optimus", text: "Optimus anafunga upya agenda kwenye Ledger…", ms: 1300, result: "RE-LOCKED" },
  {
    do: "supersede", index: 2, objector: "vextron", responder: "megatron",
    from: { ledgerId: "b7e210", text: "M-Pesa + Airtel nyuma ya `PaymentProvider`; idempotency; HMAC + timestamp; reconciliation dak. 15." },
    to: { ledgerId: "c04d5b", text: "…yote ya v1 **+** hali `PENDING → SUCCESS | FAILED`, endpoint `GET /tx/:id/status`; risiti baada ya SUCCESS tu." },
  },

  /* ================= AGENDA 3 — VISUAL (chair challenge, skill, objection rejected) ================= */
  { do: "agendaStart", index: 3 },
  {
    do: "evidence", agent: "ultron", variant: "gate", query: "fintech brand color trust prosperity emerald gold contrast",
    cache: "hit", similarity: 88.9, matched: "fintech colour psychology trust",
    sources: [S("Colour & trust in fintech", "https://www.figma.com/resource-library/color-psychology", "Kijani = ukuaji, dhahabu = thamani.")],
  },
  {
    do: "evidence", agent: "vextron", variant: "gate", query: "design tokens css variables dark light theme performance",
    cache: "hit", similarity: 86.1, matched: "design tokens css variables",
    sources: [S("Design tokens", "https://m3.material.io/foundations/design-tokens", "Tokens moja kwa themes zote.")],
  },
  {
    do: "turn", agent: "ultron", role: "owner", seconds: 5, skill: { name: "design-critique", found: true },
    thinking: ["Chapa lazima iwe tofauti na nyekundu ya M-Pesa na Airtel."],
    content:
      "SKILL_REQUEST: design-critique\n\nPROPOSED DECISION: Palette — Emerald `#0F9D6B` (vitendo vikuu), Gold `#F2B233` (jumla/highlights), Ink `#0B1220` (maandishi), Mist `#F4F6F8` (background). Hakuna nyekundu.\nRATIONALE: Kijani = ukuaji na uaminifu; tunajitenga na rangi za providers.\nTRADE-OFF: Status ya kosa itatumia rangi ya chungwa badala ya nyekundu.\nEVIDENCE: Figma colour psychology.",
  },
  { do: "consensus", event: "proposed", by: "ultron", version: 1, approvals: ["ultron"] },
  {
    do: "turn", agent: "vextron", role: "owner", seconds: 4,
    thinking: ["Next.js 16 na server components zitarahisisha dashboard…"],
    content: "Nadhani tuanze kwa kuchagua framework — Next.js 16 na server components zitafanya dashboard iwe haraka zaidi, na tunaweza kutumia edge runtime…",
  },
  {
    do: "chair", target: "vextron", reason: "OFF_TOPIC",
    text: "Vextron, agenda hii ni **utambulisho wa muonekano**, si framework. Eleza msimamo wako kuhusu palette ya Ultron — unakubali, au kuna tatizo la kiufundi kwenye rangi hizi?",
  },
  {
    do: "turn", agent: "vextron", role: "owner", seconds: 3,
    thinking: ["Mwenyekiti yuko sahihi — narudi kwenye palette."],
    content: "I_WAS_WRONG: Nilitoka nje ya agenda.\n\nAGREE: Palette inafaa — kwa sharti rangi zote ziwe design tokens (CSS variables) ili dark mode iongezwe bila kubadilisha components.",
  },
  { do: "consensus", event: "reached", by: "vextron", version: 1, approvals: ["ultron", "vextron"] },
  { do: "task", task: "mini", agent: "optimus", text: "Optimus anaandika mini report…", ms: 1600 },
  { do: "task", task: "lock", agent: "optimus", text: "Optimus anafunga agenda kwenye Ledger…", ms: 1100, result: "LOCKED" },
  {
    do: "seal", index: 3, status: "LOCKED", version: 1, ledgerId: "d93a07",
    decision: "Emerald `#0F9D6B` · Gold `#F2B233` · Ink `#0B1220` · Mist `#F4F6F8` — hakuna nyekundu; rangi zote ni design tokens.",
    rationale: "Ukuaji + uaminifu; tofauti na providers.",
    tradeoff: "Kosa = chungwa badala ya nyekundu.",
    constraints: ["Rangi zote kupitia CSS variables", "Contrast ≥ 4.5:1 nje ya jua"],
    sources: 2,
  },
  { do: "memory", scope: "agenda", agenda: 3, none: ["megatron"] },
  {
    do: "observers", index: 3, observers: ["megatron", "cybertron", "optimus"],
    objection: { agent: "cybertron", concern: "Gold #F2B233 juu ya Mist haifikii contrast 4.5:1 kwa maandishi madogo." },
  },
  { do: "task", task: "query", agent: "optimus", text: "Optimus anatengeneza search query ya pingamizi…", ms: 1200 },
  {
    do: "evidence", agent: "ultron", variant: "objection", query: "WCAG contrast large text highlight color usage",
    cache: "skip",
    sources: [S("WCAG 2.2 — Contrast (Minimum)", "https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum", "Large text inahitaji 3:1 tu.")],
  },
  {
    do: "turn", agent: "ultron", role: "responder", seconds: 3,
    thinking: ["Gold inatumika kwa jumla kubwa tu — si maandishi madogo."],
    content: "OBJECTION REJECTED: Gold inatumika kwa namba kubwa za jumla (≥ 24px) pekee, ambazo zinahitaji contrast 3:1 tu kwa WCAG 2.2 [1] — tayari tunafikia 3.4:1.",
  },
  {
    do: "overruled", objector: "cybertron", responder: "ultron",
    concern: "Gold juu ya Mist haifikii 4.5:1",
    reason: "Gold ni kwa namba kubwa (≥ 24px) pekee — WCAG inahitaji 3:1, tuna 3.4:1.",
  },

  /* ================= AGENDA 4 — PRICING (no consensus → OPEN) ================= */
  { do: "agendaStart", index: 4 },
  {
    do: "evidence", agent: "optimus", variant: "gate", query: "merchant payment fees east africa percentage flat pricing",
    cache: "miss", similarity: 55.3,
    sources: [S("Merchant fees in East Africa", "https://www.cgap.org/research", "Ada za 0.5%–1.5% ni za kawaida.")],
  },
  {
    do: "evidence", agent: "megatron", variant: "gate", query: "payment infrastructure cost per transaction small volume",
    cache: "hit", similarity: 82.7, matched: "transaction processing cost",
    sources: [S("Unit economics of payments", "https://a16z.com/payments-unit-economics", "Gharama kwa muamala mdogo.")],
  },
  {
    do: "turn", agent: "optimus", role: "owner", seconds: 4,
    thinking: ["Wafanyabiashara wadogo wanaogopa asilimia — bei ya kila mwezi ni rahisi kuelewa."],
    content: "PROPOSED DECISION: Bei ya kila mwezi TSh 5,000 bila ada ya muamala.\nRATIONALE: Inatabirika kwa mfanyabiashara.\nTRADE-OFF: Mapato madogo kwa wauzaji wakubwa.",
  },
  { do: "consensus", event: "proposed", by: "optimus", version: 1, approvals: ["optimus"] },
  {
    do: "turn", agent: "megatron", role: "owner", seconds: 4,
    thinking: ["Gharama zetu ni kwa kila muamala — flat fee itatupa hasara kwa wauzaji wakubwa."],
    content: "CONTRADICTION: Gharama zetu za reconciliation na SMS zinapanda kwa kila muamala, lakini bei ni flat.\n\nPROPOSED DECISION: 0.8% kwa kila muamala, kiwango cha juu TSh 2,000.\nRATIONALE: Gharama inafuata matumizi.",
  },
  { do: "consensus", event: "reset", by: "megatron", version: 2, approvals: ["megatron"] },
  {
    do: "turn", agent: "optimus", role: "owner", seconds: 3,
    thinking: ["Hakuna evidence ya kutosha ya bei ambayo wafanyabiashara wa Tanzania wataikubali."],
    content: "WAIT: Tunahitaji data ya majaribio (pilot) ya wafanyabiashara 50 kabla ya kufunga bei — siwezi kukubali 0.8% bila ushahidi.",
  },
  { do: "consensus", event: "exhausted", by: "optimus", version: 2, approvals: ["megatron"] },
  { do: "task", task: "lock", agent: "optimus", text: "Optimus anafunga agenda kwenye Ledger…", ms: 1100, result: "OPEN" },
  {
    do: "seal", index: 4, status: "OPEN", version: 2, ledgerId: "e1b882",
    decision: "UNRESOLVED — hakuna consensus ya kutosha (flat TSh 5,000 dhidi ya 0.8% / max TSh 2,000).",
    constraints: ["Pilot ya wafanyabiashara 50 kabla ya kufunga bei"],
    sources: 2,
  },
  { do: "memory", scope: "agenda", agenda: 4 },

  /* ================= FINALE ================= */
  { do: "task", task: "validate", agent: "optimus", text: "Optimus anakagua Ledger (agenda 1–4)…", ms: 900 },
  {
    do: "validator", scope: "ledger",
    rows: [
      { index: 1, title: STAGE_AGENDA[0].title, final: "locked" },
      { index: 2, title: STAGE_AGENDA[1].title, final: "locked" },
      { index: 3, title: STAGE_AGENDA[2].title, final: "locked" },
      { index: 4, title: STAGE_AGENDA[3].title, final: "open" },
    ],
  },
  { do: "notice", tone: "warn", text: "Agenda 4 haikufungwa kwa consensus — itaandikwa kama UNRESOLVED kwenye ripoti." },
  {
    do: "assembly", file: "wallet-payments.ts",
    pieces: [
      { agenda: 2, agent: "megatron", file: "payments.ts", lines: 23 },
      { agenda: 2, agent: "cybertron", file: "payments.test.ts", lines: 15 },
    ],
    parts: [FINAL_1, FINAL_2],
  },
  {
    do: "report", title: `Ripoti: ${STAGE_TITLE}`, reportId: "r-wallet",
    parts: [
      { sections: [1, 2, 3, 4, 5], text: REPORT_PART_1 },
      { sections: [6, 8, 9, 10], text: REPORT_PART_2 },
    ],
    missing: [7],
    repairText: REPORT_REPAIR,
  },
  { do: "task", task: "reportCheck", agent: "optimus", text: "Optimus anakagua agenda zote kwenye ripoti…", ms: 1000 },
  {
    do: "validator", scope: "report",
    rows: [
      { index: 1, title: STAGE_AGENDA[0].title, final: "ok" },
      { index: 2, title: STAGE_AGENDA[1].title, final: "ok" },
      { index: 3, title: STAGE_AGENDA[2].title, final: "ok" },
      { index: 4, title: STAGE_AGENDA[3].title, final: "stitched" },
    ],
  },
  { do: "memory", scope: "reflection" },
  { do: "memory", scope: "consolidate", none: ["cybertron"] },
  { do: "summary" },
];
