#!/usr/bin/env bash
# =============================================================================
# surgery-fix-v3.sh — Board Room v2: marekebisho manne
#   1) CRASH "Something went wrong" ripoti inapoanza — Markdown.tsx ilikuwa na
#      infinite loop kwenye mstari uliokatika wakati wa streaming ("##", ">"),
#      tab ikaishiwa memory. Sasa: mstari huo unarukwa + kinga isiyokwama.
#      Pia StageNode ni React.memo (item iliyobadilika tu ndiyo inarender).
#   2) Ripoti — muundo mpya "hati hai": LIVE badge, mstari wa sehemu 10,
#      "Sasa: n. Sehemu", maneno yanastream neno kwa neno kwenye ukurasa
#      unaofuata mstari wa mwisho, vipande 1+2+marekebisho vinaongezana,
#      takwimu (maneno · herufi · maneno/s), kisha "Report filed · Open".
#   3) Rail ya juu (A1 v2 · A2 · … · Finale) — mstari wa scrollbar umeondolewa.
#   4) Zoom lock kwenye simu (viewport + touch-action + iOS gesture guard).
#
# Faili zinazoguswa (11):
#   src/components/ui/Markdown.tsx
#   src/lib/stage/types.ts
#   src/lib/stage/script.ts
#   src/components/board/stage/usePlayback.ts
#   src/components/board/stage/Finale.tsx
#   src/components/board/stage/StageStream.tsx
#   src/components/board/stage/StageRail.tsx
#   src/components/board/stage/stage.css
#   src/app/layout.tsx
#   src/app/mobile.css   (MPYA)
#   src/components/shell/ZoomLock.tsx   (MPYA)
#
# Matumizi (kutoka root ya repo professor-xmd-ui-v2, baada ya surgery-fix-v2):
#   bash surgery-fix-v3.sh
# Backup: <faili>.bak-<tarehe>. Kurudisha yote: bash surgery-fix-v3.sh --undo
# Baada ya hapo: rm -rf .next && npm run build
# =============================================================================
set -euo pipefail

STAGE="src/components/board/stage"
FILES=("src/components/ui/Markdown.tsx" "src/lib/stage/types.ts" "src/lib/stage/script.ts" "src/components/board/stage/usePlayback.ts" "src/components/board/stage/Finale.tsx" "src/components/board/stage/StageStream.tsx" "src/components/board/stage/StageRail.tsx" "src/components/board/stage/stage.css" "src/app/layout.tsx" "src/app/mobile.css" "src/components/shell/ZoomLock.tsx")

if [[ ! -d "$STAGE" || ! -f "src/app/layout.tsx" ]]; then
  echo "❌ Endesha script hii kutoka root ya repo professor-xmd-ui-v2 (hakuna $STAGE)." >&2; exit 1
fi

if [[ "${1:-}" == "--undo" ]]; then
  for f in "${FILES[@]}"; do
    last=$(ls -1t "$f".bak-* 2>/dev/null | head -n1 || true)
    if [[ -z "$last" ]]; then echo "⚠️  Hakuna backup ya $f"; continue; fi
    if [[ "$last" == *.absent ]]; then rm -f "$f" "$last"; echo "🗑️  $f (ilikuwa mpya) imeondolewa"
    else cp "$last" "$f"; echo "↩️  $f ← $last"; fi
  done
  exit 0
fi

# Inahitaji toleo la stage la v2 (ScriptBox + ThinkTrace + ReportWriter)
for need in "$STAGE/ScriptBox.tsx" "$STAGE/ThinkTrace.tsx" "$STAGE/kit.tsx" "$STAGE/Finale.tsx" "src/components/ui/Markdown.tsx"; do
  if [[ ! -f "$need" ]]; then
    echo "❌ $need haipo — weka kwanza ZIP ya v2 iliyopita, kisha endesha tena." >&2; exit 1
  fi
done

TS=$(date +%Y%m%d-%H%M%S)
for f in "${FILES[@]}"; do
  if [[ -f "$f" ]]; then cp "$f" "$f.bak-$TS" && echo "🗂️  backup: $f.bak-$TS"
  else mkdir -p "$(dirname "$f")"; : > "$f.bak-$TS.absent"; fi
done

echo "✍️  src/components/ui/Markdown.tsx"
cat > "src/components/ui/Markdown.tsx" <<'XMD_SURGERY_EOF_0'
import { Fragment, type ReactNode } from "react";

/**
 * Tiny, dependency-free markdown renderer for the demo: headings, bold,
 * italics, inline code, citations [n], bullet/numbered lists, tables, quotes.
 */
function inline(text: string, key = ""): ReactNode[] {
  const out: ReactNode[] = [];
  const re = /(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`|\[\d+\])/g;
  let last = 0;
  let m: RegExpExecArray | null;
  let i = 0;
  while ((m = re.exec(text))) {
    if (m.index > last) out.push(text.slice(last, m.index));
    const t = m[0];
    const k = `${key}-${i++}`;
    if (t.startsWith("**")) out.push(<strong key={k}>{t.slice(2, -2)}</strong>);
    else if (t.startsWith("`")) out.push(<code key={k}>{t.slice(1, -1)}</code>);
    else if (t.startsWith("[")) out.push(<sup key={k} className="cite">{t.slice(1, -1)}</sup>);
    else out.push(<em key={k}>{t.slice(1, -1)}</em>);
    last = m.index + t.length;
  }
  if (last < text.length) out.push(text.slice(last));
  return out;
}

export function slug(s: string) {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
}

export function Markdown({ text, accent }: { text: string; accent?: string }) {
  const lines = text.split("\n");
  const blocks: ReactNode[] = [];
  let i = 0;
  let k = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (!line.trim()) { i++; continue; }
    // Streaming: heading/quote iliyokatika ("#", "##", ">") — ruka mpaka maandishi yafike (zamani: infinite loop → tab crash)
    if (/^(#{1,6}|>)\s*$/.test(line)) { i++; continue; }
    if (/^#{4,6} /.test(line)) { blocks.push(<h3 key={k++}>{inline(line.replace(/^#+ /, ""))}</h3>); i++; continue; }
    if (line.startsWith("# ")) { blocks.push(<h1 key={k++}>{inline(line.slice(2))}</h1>); i++; continue; }
    if (line.startsWith("## ")) { const t = line.slice(3); blocks.push(<h2 key={k++} id={slug(t)}>{inline(t)}</h2>); i++; continue; }
    if (line.startsWith("### ")) { blocks.push(<h3 key={k++}>{inline(line.slice(4))}</h3>); i++; continue; }
    if (line.startsWith("> ")) { blocks.push(<blockquote key={k++}>{inline(line.slice(2))}</blockquote>); i++; continue; }
    if (line.startsWith("|")) {
      const tableLines: string[] = [];

      while (i < lines.length && lines[i].startsWith("|")) {
        tableLines.push(lines[i]);
        i++;
      }

      /*
       * Markdown tables can arrive incrementally while the Board Room
       * is streaming an agent response.
       *
       * Example of an incomplete table:
       *
       * | Agent | Status |
       * | --- |
       *
       * or even:
       *
       * | Agent | Status
       *
       * The old parser assumed that `rows[0]` always existed and then
       * called `head.map(...)`, which crashes when the parser receives
       * only a separator/incomplete row.
       */

      const parseCells = (row: string): string[] => {
        const trimmed = row.trim();

        if (!trimmed.startsWith("|")) {
          return [];
        }

        const parts = trimmed.split("|");

        // Remove the empty item caused by the leading "|".
        parts.shift();

        // Remove the empty item caused by a trailing "|".
        if (parts.length && parts[parts.length - 1].trim() === "") {
          parts.pop();
        }

        return parts.map((c) => c.trim());
      };

      const isSeparatorRow = (cells: string[]) =>
        cells.length > 0 &&
        cells.every((c) => /^:?-{3,}:?$/.test(c));

      const parsedRows = tableLines
        .map(parseCells)
        .filter((cells) => cells.length > 0);

      /*
       * Find the real Markdown separator row.
       *
       * A valid table needs:
       *   1. Header row
       *   2. Separator row
       *
       * Do not assume the first parsed row is a header.
       */
      const separatorIndex = parsedRows.findIndex(isSeparatorRow);

      /*
       * If there is no valid separator yet, the table is probably still
       * streaming. Render it as normal text instead of constructing a
       * malformed table.
       */
      if (separatorIndex < 1) {
        const fallbackText = tableLines.join("\n");

        blocks.push(
          <p key={k++}>
            {inline(fallbackText)}
          </p>,
        );

        continue;
      }

      const head = parsedRows[separatorIndex - 1];

      /*
       * Defensive guard.
       *
       * Even if the parser receives malformed Markdown, NEVER allow
       * `head.map(...)` to execute with undefined.
       */
      if (!head || head.length === 0) {
        const fallbackText = tableLines.join("\n");

        blocks.push(
          <p key={k++}>
            {inline(fallbackText)}
          </p>,
        );

        continue;
      }

      const body = parsedRows
        .slice(separatorIndex + 1)
        .filter((row) => row.length > 0);

      blocks.push(
        <div key={k++} className="overflow-x-auto">
          <table>
            <thead>
              <tr>
                {head.map((c, j) => (
                  <th key={j}>{inline(c)}</th>
                ))}
              </tr>
            </thead>

            <tbody>
              {body.map((r, ri) => (
                <tr key={ri}>
                  {r.map((c, j) => (
                    <td key={j}>
                      {c === "LOCKED" ? (
                        <span className="inline-flex items-center gap-1 rounded-md bg-[rgb(52_211_153/0.12)] px-1.5 py-0.5 font-mono text-[10.5px] font-semibold text-[var(--color-ok)]">
                          ● LOCKED
                        </span>
                      ) : /^Inajadiliwa$/.test(c) ? (
                        <span className="inline-flex items-center gap-1 rounded-md bg-[rgb(251_191_36/0.12)] px-1.5 py-0.5 font-mono text-[10.5px] font-semibold text-[var(--color-warn)]">
                          ◌ {c}
                        </span>
                      ) : (
                        inline(c, `${ri}${j}`)
                      )}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>,
      );

      continue;
    }
    if (/^- /.test(line)) {
      const items: string[] = [];
      while (i < lines.length && /^- /.test(lines[i])) { items.push(lines[i].slice(2)); i++; }
      blocks.push(<ul key={k++}>{items.map((t, j) => <li key={j}>{inline(t, `${j}`)}</li>)}</ul>);
      continue;
    }
    if (/^\d+\. /.test(line)) {
      const items: string[] = [];
      while (i < lines.length && /^\d+\. /.test(lines[i])) { items.push(lines[i].replace(/^\d+\. /, "")); i++; }
      blocks.push(<ol key={k++}>{items.map((t, j) => <li key={j}>{inline(t, `${j}`)}</li>)}</ol>);
      continue;
    }
    const para: string[] = [];
    while (i < lines.length && lines[i].trim() && !/^(#|>|\||- |\d+\. )/.test(lines[i])) { para.push(lines[i]); i++; }
    // Kinga: mstari usiotambulika (mf. "#Kichwa", ">maneno") — usikwame, uchukue kama aya
    if (!para.length) { para.push(lines[i]); i++; }
    blocks.push(<p key={k++}>{para.map((p, j) => <Fragment key={j}>{j > 0 && " "}{inline(p, `${j}`)}</Fragment>)}</p>);
  }
  return (
    <div className="prose-xmd" style={accent ? ({ ["--bullet" as string]: accent } as React.CSSProperties) : undefined}>
      {blocks}
    </div>
  );
}
XMD_SURGERY_EOF_0

echo "✍️  src/lib/stage/types.ts"
cat > "src/lib/stage/types.ts" <<'XMD_SURGERY_EOF_1'
import type { AgentId } from "@/lib/agents";
import type { Source } from "@/lib/mock";

/* ---------------------------------------------------------------------------
 * STAGE ITEMS — kila kitu kinachotokea Board Room kina render yake.
 * Kila aina hapa ina ramani (mapping) ya tukio halisi la engine ya
 * professor-xmd-company (boardRunner.ts + brain/*) — angalia maoni `engine:`.
 * Integration ya baadaye = reducer inayogeuza BoardEvent → StageItem hizi.
 * ------------------------------------------------------------------------- */

export type Step = "wait" | "run" | "done" | "fail" | "skip";

export interface AgendaDef {
  index: number;
  title: string;
  owners: AgentId[];
  requiresCode: boolean;
}

/** engine: user prompt (CEO) */
export interface UserItem { kind: "user"; id: string; text: string }

/** engine: addChip("🏛️ Board Room — …") / resume "♻️ …imeendelea" / reattach · title_done · "💾 Conversation imeundwa" */
export interface ConveneItem {
  kind: "convene"; id: string;
  mode: "new" | "resume" | "reattach";
  project: string;
  title: string; titleShown: number;
  sessionId?: string;
}

/** engine: addChip("🧭 Optimus ameelewa: …") */
export interface ScopeItem { kind: "scope"; id: string; text: string; shown: number }

/** engine: addChip("📋 Agenda (N vipengele): …") */
export interface AgendaBuildItem { kind: "agendaBuild"; id: string; items: AgendaDef[]; shown: number }

/** engine: bcast({type:"round"}) + addChip(" Agenda i/N: … — owners: …") */
export interface AgendaStartItem { kind: "agendaStart"; id: string; agenda: AgendaDef; total: number }

/** engine: runMandatoryEvidenceGate / handleResearchRequest (search, sources, msg_done) + search.ts logs.
 * Inaonyeshwa NDANI ya ThinkingBlock ya zamu inayofuata ya agent huyo (Searched row + badges). */
export interface SearchTrace {
  variant: "gate" | "research" | "objection";
  query: string; queryShown: number;
  /** Appwrite semantic cache */
  cache: Step; similarity?: number; matched?: string;
  /** session memory (research requests baada ya search ya kwanza) */
  memory?: Step;
  /** cache hit lakini si relevant → fresh verification */
  relevance?: Step;
  /** SearXNG */
  engine: Step; attempt: number; maxAttempts: number; waitLeft?: number; failures: number;
  /** save vector + results */
  save: Step;
  sources: Source[];
  done: boolean;
}

/** Fallback: evidence isiyo na zamu inayofuata (render ya peke yake) */
export interface EvidenceItem { kind: "evidence"; id: string; agent: AgentId; trace: SearchTrace }

export type Signal =
  | "CLARIFY" | "OFF_TOPIC" | "CONTRADICTION" | "DISAGREE"
  | "INSUFFICIENT_EVIDENCE" | "I_WAS_WRONG" | "WAIT" | "SKILL_REQUEST";

/** engine: msg_start → think* → token* → msg_done (msg_reset = retry) · brain parseSignals */
export interface TurnItem {
  kind: "turn"; id: string;
  agent: AgentId;
  role: "owner" | "observer" | "responder" | "chair" | "writer";
  thinking: string[]; thinkShown: number;
  content: string; target: string;
  phase: "thinking" | "searching" | "answering" | "retrying" | "done";
  /** evidence gate / research ya zamu hii (engine: kabla ya jibu) */
  search?: SearchTrace;
  retry?: { n: number; max: number; model: string };
  seconds: number;
  skill?: { name: string; found: boolean };
}

/** engine: proposal parser / agrees Set / consensus gate / MAX_TURNS */
export interface ConsensusItem {
  kind: "consensus"; id: string;
  event: "proposed" | "reset" | "agreed" | "reached" | "exhausted";
  by: AgentId; version: number;
  owners: AgentId[]; approvals: AgentId[];
}

/** engine (brain): chairReview → Optimus anaongea kama mwenyekiti */
export interface ChairItem { kind: "chair"; id: string; target: AgentId; reason: Signal; text: string; shown: number }

export interface Hunk { line: number; old: string[]; new: string[] }

/** engine: code-writing phase streamTurn (continuation attempts 1..3).
 *  Patch (script_diff) = toleo jipya la box; la zamani linabaki kama mstari mfupi (dissolveMessage). */
export interface ScriptItem {
  kind: "script"; id: string;
  agent: AgentId; file: string; lang: string;
  code: string; shown: number;
  attempt: number; maxAttempts: number;
  /** "resume" = inasubiri kuendelea pale ilipoishia */
  state: "writing" | "resume" | "patching" | "done";
  version: number;
  patch?: { reason: "review" | "objection"; add: number; del: number; hunks: Hunk[]; changed: number[] };
  replaced?: { add: number; del: number };
}

/** engine: reviewer APPROVE / REJECT: … (round 1..2) */
export interface ReviewItem {
  kind: "review"; id: string; agent: AgentId;
  verdict: "pending" | "approve" | "reject";
  round: number; maxRounds: number; notes: string[];
}

/** engine: "Deliverable ya mwisho — item" */
export interface DeliverableItem { kind: "deliverable"; id: string; agent: AgentId; file: string; lines: number; agenda: string }

export type TaskKind = "agenda" | "mini" | "lock" | "relock" | "query" | "validate" | "reportCheck";
/** engine: activityStart/activityEnd (shimmer — si ujumbe wa chat) */
export interface TaskItem { kind: "task"; id: string; task: TaskKind; agent: AgentId; text: string; state: "run" | "done"; result?: string; ms?: number }

export type MemState = "wait" | "run" | "saved" | "none" | "fail";
/** engine (brain): agendaCheckpoints / finalReflection / consolidation — SHIMMER TU, maudhui hayaonyeshwi */
export interface MemoryItem {
  kind: "memory"; id: string;
  scope: "agenda" | "reflection" | "consolidate";
  agenda?: number;
  agents: { id: AgentId; state: MemState }[];
  done: boolean;
}

/** engine: saveLedgerEntry → addChip("🔒 LOCKED" | "🟠 OPEN") · re-lock (supersedes) */
export interface SealItem {
  kind: "seal"; id: string;
  agenda: AgendaDef;
  status: "LOCKED" | "OPEN";
  version: number;
  decision: string;
  rationale?: string; tradeoff?: string;
  constraints: string[];
  owners: AgentId[];
  sources: number;
  ledgerId: string;
  supersedes?: string;
  superseded?: boolean;
}

/** engine: observers loop (SILENT | OBJECTION + SEVERITY) — max 1 objection */
export interface ObserversItem {
  kind: "observers"; id: string; agenda: number;
  checks: { agent: AgentId; state: "wait" | "check" | "silent" | "objection" | "skipped" }[];
  objection?: { agent: AgentId; concern: string; severity: "high" };
}

/** engine: UPDATED DECISION → re-lock + markSuperseded(entryId) + "🔁 SUPERSEDED" */
export interface SupersedeItem {
  kind: "supersede"; id: string; agenda: number;
  objector: AgentId; responder: AgentId;
  from: { ledgerId: string; text: string; version: number };
  to: { ledgerId: string; text: string; version: number };
}

/** engine: "↩️ Objection imekataliwa: …" */
export interface OverruledItem { kind: "overruled"; id: string; objector: AgentId; responder: AgentId; concern: string; reason: string }

/** engine: HATUA 6.4 Ledger validator · report validator [A1..AN] + stitch */
export interface ValidatorItem {
  kind: "validator"; id: string; scope: "ledger" | "report";
  rows: { index: number; title: string; state: "wait" | "check" | "locked" | "open" | "missing" | "ok" | "stitched" }[];
  done: boolean;
}

/** engine: HATUA 6.5 assembleFinalScript (collectLockedPieces → stream 1..6) */
export interface AssemblyItem {
  kind: "assembly"; id: string;
  pieces: { agenda: number; agent: AgentId; file: string; lines: number }[];
  merged: number; // vipande vilivyounganishwa
  file: string; code: string; shown: number;
  attempt: number; maxAttempts: number; done: boolean;
}

export type SectionState = "wait" | "writing" | "done" | "missing" | "repairing" | "repaired";
/** engine: HATUA 7 report parts 1/2, 2/2 · repair loop · saveReport */
export interface ReportItem {
  kind: "report"; id: string;
  title: string;
  part: 0 | 1 | 2 | 3; // 3 = repair
  sections: { n: number; title: string; state: SectionState; chars: number }[];
  /** hati nzima inayokua (kipande 1 + 2 + marekebisho) — inastreamiwa neno kwa neno */
  doc: string; shown: number;
  /** herufi ambapo marekebisho (repair) yanaanzia */
  repairFrom?: number;
  startedAt: number;
  saved: "wait" | "saving" | "saved" | "failed";
  reportId: string;
}

/** engine: system chips za retry/rotation/error/halt */
export interface NoticeItem {
  kind: "notice"; id: string;
  tone: "retry" | "rotate" | "warn" | "error" | "halt" | "info";
  agent?: AgentId; text: string; detail?: string;
}

/** engine: bcast({type:"summary"}) + done */
export interface SummaryItem {
  kind: "summary"; id: string;
  seconds: number;
  usage: { agent: AgentId; requests: number; tokens: number }[];
  locked: number; superseded: number; open: number; sources: number; memories: number;
}

export type StageItem =
  | UserItem | ConveneItem | ScopeItem | AgendaBuildItem | AgendaStartItem
  | EvidenceItem | TurnItem | ConsensusItem | ChairItem
  | ScriptItem | ReviewItem | DeliverableItem
  | TaskItem | MemoryItem | SealItem | ObserversItem | SupersedeItem | OverruledItem
  | ValidatorItem | AssemblyItem | ReportItem | NoticeItem | SummaryItem;

/* ---------------- live stage (StageRail) ---------------- */
export type AgendaPhase = "evidence" | "discussion" | "code" | "lock" | "review" | "relock" | "memory";
export type FinalePhase = "validate" | "assemble" | "report" | "reflect" | "done";

export interface LiveStage {
  scope: "opening" | "agenda" | "finale" | "done";
  agenda?: AgendaDef;
  total: number;
  phase?: AgendaPhase;
  finale?: FinalePhase;
  hadCode: boolean;
  hadObjection: boolean;
  owners: AgentId[];
  approvals: AgentId[];
  version: number;
  ledger: Record<number, { status: "LOCKED" | "OPEN" | "SUPERSEDED+LOCKED"; version: number }>;
  background: string | null; // shimmer text ya kazi ya background inayoendelea
}
XMD_SURGERY_EOF_1

echo "✍️  src/lib/stage/script.ts"
cat > "src/lib/stage/script.ts" <<'XMD_SURGERY_EOF_2'
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
XMD_SURGERY_EOF_2

echo "✍️  src/components/board/stage/usePlayback.ts"
cat > "src/components/board/stage/usePlayback.ts" <<'XMD_SURGERY_EOF_3'
"use client";
import { useCallback, useRef, useState } from "react";
import { AGENTS, getAgent, type AgentId } from "@/lib/agents";
import { useApp } from "../../shell/AppState";
import { STAGE_AGENDA, STAGE_BEATS, REPORT_SECTIONS, STAGE_PROMPT, type Beat } from "@/lib/stage/script";
import type { Hunk, LiveStage, SearchTrace, StageItem, TurnItem } from "@/lib/stage/types";

/* ---------------------------------------------------------------------------
 * usePlayback — inacheza STAGE_BEATS kama session halisi (demo, frontend-only).
 * Integration ya baadaye: badala ya beats, NDJSON ya /api/boardroom inapita
 * kwenye reducer inayotoa StageItem zilezile (angalia lib/stage/types.ts).
 *
 * Dev hooks (hazionekani kwa mtumiaji): ?speed=2 · ?hold=<beat>&holdMs=<ms>
 * ------------------------------------------------------------------------- */

const nid = () => Math.random().toString(36).slice(2, 9);
class Abort extends Error {}

const EMPTY_STAGE: LiveStage = {
  scope: "opening", total: STAGE_AGENDA.length, hadCode: false, hadObjection: false,
  owners: [], approvals: [], version: 0, ledger: {}, background: null,
};

export type PlayPhase = "idle" | "running" | "done";

type EvBeat = Extract<Beat, { do: "evidence" }>;

function newTrace(b: EvBeat): SearchTrace {
  return {
    variant: b.variant, query: b.query, queryShown: 0,
    cache: "wait", engine: "wait", attempt: 0, maxAttempts: 11, failures: 0, save: "wait", sources: [], done: false,
  };
}

/** Tumia hunks za script_diff kwenye code (kwa kulinganisha maudhui; line ni makadirio). */
function applyHunks(code: string, hunks: Hunk[]): { code: string; changed: number[] } {
  const lines = code.split("\n");
  const changed: number[] = [];
  for (const h of hunks) {
    let at = -1;
    if (h.old.length) at = lines.findIndex((l) => l.trim() === h.old[0].trim());
    if (at < 0) at = Math.min(Math.max(0, h.line - 1), lines.length);
    lines.splice(at, h.old.length, ...h.new);
    for (let k = 0; k < h.new.length; k++) changed.push(at + k + 1);
  }
  return { code: lines.join("\n"), changed };
}

export function usePlayback() {
  const { setStatus, resetStatus, addLog, setBoardLive, bumpUsage } = useApp();
  const [items, setItems] = useState<StageItem[]>([]);
  const [stage, setStage] = useState<LiveStage>(EMPTY_STAGE);
  const [phase, setPhase] = useState<PlayPhase>("idle");
  const [title, setTitle] = useState("");
  const token = useRef(0);

  const stop = useCallback(() => {
    token.current++;
    resetStatus();
    setBoardLive(false);
    setStage((s) => ({ ...s, background: null }));
    setItems((l) => l.map((x) =>
      x.kind === "turn" && x.phase !== "done" ? { ...x, phase: "done", thinkShown: x.thinking.length, search: x.search && { ...x.search, done: true } }
      : x.kind === "script" && x.state !== "done" ? { ...x, state: "done" }
      : x.kind === "evidence" && !x.trace.done ? { ...x, trace: { ...x.trace, done: true } }
      : x));
    setPhase("done");
    addLog("warning", "Session stopped by Mkuu");
  }, [addLog, resetStatus, setBoardLive]);

  const reset = useCallback(() => {
    token.current++;
    setItems([]); setStage(EMPTY_STAGE); setPhase("idle"); setTitle("");
  }, []);

  /** opts.instant = history mode (hakuna animation) */
  const run = useCallback(
    async (prompt: string, opts: { instant?: boolean; speed?: number; hold?: number; holdMs?: number } = {}) => {
      const my = ++token.current;
      const instant = !!opts.instant;
      const speed = Math.max(0.25, opts.speed ?? 1);
      let beatIdx = -1;
      let beatStart = 0;
      const usage: Record<string, { requests: number; tokens: number }> = {};
      const pending: Partial<Record<AgentId, EvBeat>> = {};
      const t0 = Date.now();

      const alive = () => token.current === my;
      const wait = async (ms: number) => {
        if (!alive()) throw new Abort();
        if (instant) return;
        if (opts.hold === beatIdx) {
          // dev: simamisha katikati ya beat baada ya holdMs (kwa screenshots za hali hai)
          const left = (opts.holdMs ?? 0) - (Date.now() - beatStart);
          if (ms / speed >= left) {
            if (left > 0) await new Promise((r) => setTimeout(r, left));
            while (alive()) await new Promise((r) => setTimeout(r, 250));
            throw new Abort();
          }
        }
        await new Promise((r) => setTimeout(r, ms / speed));
        if (!alive()) throw new Abort();
      };
      // nakala ya ndani (source of truth ya run hii) → React state
      let local: StageItem[] = [];
      let st: LiveStage = { ...EMPTY_STAGE };
      const commit = () => { if (alive()) setItems(local); };
      const add = (it: StageItem) => { local = [...local, it]; commit(); };
      const patch = <T extends StageItem>(id: string, p: Partial<T> | ((x: T) => Partial<T>)) => {
        local = local.map((x) => (x.id === id ? ({ ...x, ...(typeof p === "function" ? p(x as T) : p) } as StageItem) : x));
        commit();
      };
      const mapItems = (fn: (x: StageItem, i: number, all: StageItem[]) => StageItem) => { local = local.map((x, i, all) => fn(x, i, all)); commit(); };
      const stageSet = (p: Partial<LiveStage> | ((s: LiveStage) => Partial<LiveStage>)) => {
        st = { ...st, ...(typeof p === "function" ? p(st) : p) };
        if (alive()) setStage(st);
      };
      /** reveal text progressively into item[field] */
      const reveal = async (id: string, field: string, len: number, step: number, ms: number) => {
        if (instant) { patch(id, { [field]: len } as never); return; }
        for (let k = step; k < len; k += step) { patch(id, { [field]: k } as never); await wait(ms); }
        patch(id, { [field]: len } as never);
      };
      const use = (a: AgentId, tokens: number) => {
        usage[a] = { requests: (usage[a]?.requests ?? 0) + 1, tokens: (usage[a]?.tokens ?? 0) + tokens };
        if (!instant) bumpUsage(a, tokens);
      };
      const log: typeof addLog = (t, m) => { if (!instant) addLog(t, m); };
      const name = (a: AgentId) => getAgent(a)!.name;
      const agendaOf = (i: number) => STAGE_AGENDA.find((a) => a.index === i)!;

      setPhase("running");
      if (!instant) setBoardLive(true);
      setTitle("");
      setStage(EMPTY_STAGE);
      add({ kind: "user", id: nid(), text: prompt || STAGE_PROMPT });
      log("system", "🏛️ Board Room imefunguliwa · agents 5");

      try {
        for (const beat of STAGE_BEATS) {
          beatIdx++;
          beatStart = Date.now();
          await play(beat);
        }
        setPhase("done");
        stageSet({ scope: "done", finale: "done", background: null });
      } catch (e) {
        if (!(e instanceof Abort)) throw e;
        return;
      } finally {
        if (alive() && !instant) { resetStatus(); setBoardLive(false); }
      }

      async function play(b: Beat) {
        switch (b.do) {
          case "convene": {
            const id = nid();
            add({ kind: "convene", id, mode: "new", project: prompt || STAGE_PROMPT, title: b.title, titleShown: 0, sessionId: b.sessionId });
            await wait(600);
            log("system", `💾 Conversation imeundwa (id: ${b.sessionId}…)`);
            setStatus("optimus", "thinking");
            await wait(300);
            await reveal(id, "titleShown", b.title.length, 2, 30);
            setTitle(b.title);
            setStatus("optimus", "online");
            log("success", `🧠 Jina la conversation: ${b.title}`);
            break;
          }
          case "task": {
            const id = nid();
            add({ kind: "task", id, task: b.task, agent: b.agent, text: b.text, state: "run" });
            stageSet({
              background: b.text,
              ...(b.task === "lock" ? { phase: "lock" as const } : b.task === "relock" ? { phase: "relock" as const } : b.task === "validate" ? { scope: "finale" as const, finale: "validate" as const } : {}),
            });
            setStatus(b.agent, "thinking");
            log("system", `⏳ ${b.text}`);
            await wait(b.ms);
            patch(id, { state: "done", result: b.result, ms: b.ms });
            setStatus(b.agent, "online");
            stageSet({ background: null });
            log("success", `✅ ${b.text.replace("…", "")} · ${(b.ms / 1000).toFixed(1)}s${b.result ? ` · ${b.result}` : ""}`);
            break;
          }
          case "scope": {
            const id = nid();
            add({ kind: "scope", id, text: b.text, shown: 0 });
            await reveal(id, "shown", b.text.length, 4, 18);
            log("info", `🧭 Uelewa wa Optimus: ${b.text.slice(0, 90)}…`);
            await wait(400);
            break;
          }
          case "agendaBuild": {
            const id = nid();
            add({ kind: "agendaBuild", id, items: b.items, shown: 0 });
            for (let k = 1; k <= b.items.length; k++) { await wait(420); patch(id, { shown: k }); }
            if (instant) patch(id, { shown: b.items.length });
            log("system", `📋 Agenda (${b.items.length}): ${b.items.map((a) => a.title).join(" · ")}`);
            await wait(500);
            break;
          }
          case "agendaStart": {
            const a = agendaOf(b.index);
            add({ kind: "agendaStart", id: nid(), agenda: a, total: STAGE_AGENDA.length });
            stageSet({ scope: "agenda", agenda: a, phase: "evidence", owners: a.owners, approvals: [], version: 0, hadCode: false, hadObjection: false });
            log("system", `🎯 Agenda ${a.index}: ${a.title} | owners: ${a.owners.map(name).join(" + ")}`);
            await wait(700);
            break;
          }
          case "evidence": {
            // Engine: gate/research hufanyika kabla ya jibu la agent → tunaionyesha ndani ya
            // ThinkingBlock ya zamu inayofuata ya agent huyo. Isipokuwepo → render ya peke yake.
            if (nextTurnOf(b.agent) >= 0) { pending[b.agent] = b; break; }
            const id = nid();
            add({ kind: "evidence", id, agent: b.agent, trace: newTrace(b) });
            if (b.variant === "objection") stageSet({ phase: "review" });
            setStatus(b.agent, "thinking");
            await runTrace(b, (p) => patch<Extract<StageItem, { kind: "evidence" }>>(id, (x) => ({ trace: { ...x.trace, ...(typeof p === "function" ? p(x.trace) : p) } })));
            setStatus(b.agent, "online");
            await wait(350);
            break;
          }
          case "turn": {
            const id = nid();
            const t: TurnItem = {
              kind: "turn", id, agent: b.agent, role: b.role, thinking: b.thinking, thinkShown: 0,
              content: "", target: b.content, phase: "thinking", seconds: b.seconds, skill: b.skill,
            };
            const ev = pending[b.agent];
            delete pending[b.agent];
            if (ev) t.search = newTrace(ev);
            add(t);
            if (b.role === "owner" && !ev) stageSet({ phase: "discussion" });
            if (ev?.variant === "objection") stageSet({ phase: "review" });
            setStatus(b.agent, "thinking");
            for (let k = 1; k <= b.thinking.length; k++) { await wait(620); patch(id, { thinkShown: k }); }
            if (instant) patch(id, { thinkShown: b.thinking.length });
            if (ev) {
              patch(id, { phase: "searching" });
              await runTrace(ev, (p) => patch<TurnItem>(id, (x) => ({ search: { ...x.search!, ...(typeof p === "function" ? p(x.search!) : p) } })));
              patch(id, { phase: "thinking" });
              if (b.role === "owner") stageSet({ phase: "discussion" });
              await wait(300);
            }
            if (b.retry) {
              patch(id, { phase: "answering", content: b.content.slice(0, 38) });
              await wait(700);
              patch(id, { phase: "retrying", content: "", retry: { n: 1, max: 3, model: b.retry.model } });
              add({ kind: "notice", id: nid(), tone: "retry", agent: b.agent, text: `${name(b.agent)}: jibu tupu/truncated — retry 1/3`, detail: b.retry.model });
              log("warning", `⚠️ ${name(b.agent)}: jibu tupu/truncated — retry 1/3 kwenye ${b.retry.model}`);
              await wait(1600);
              if (b.retry.rotateTo) {
                add({ kind: "notice", id: nid(), tone: "rotate", agent: b.agent, text: `${name(b.agent)}: limit/quota → ${b.retry.stage ?? "stage"}`, detail: `${b.retry.model} → ${b.retry.rotateTo}` });
                log("warning", `🔁 ${name(b.agent)}: limit/quota → ${b.retry.model} → ${b.retry.rotateTo}`);
                await wait(900);
              }
              patch(id, { retry: undefined });
            }
            if (b.skill) log(b.skill.found ? "success" : "warning", `🧩 [BRAIN] skills.request · ${name(b.agent)} · ${b.skill.name} · ${b.skill.found ? "loaded" : "NOT FOUND"}`);
            setStatus(b.agent, "speaking");
            patch(id, { phase: "answering" });
            log("api", `${name(b.agent)} → ${getAgent(b.agent)!.model}`);
            if (instant) patch(id, { content: b.content });
            else {
              const words = b.content.split(/(\s+)/);
              let acc = "";
              for (let w = 0; w < words.length; w += 3) { acc += words.slice(w, w + 3).join(""); patch(id, { content: acc }); await wait(24); }
            }
            patch(id, { content: b.content, phase: "done" });
            use(b.agent, 900 + b.content.length * 3);
            setStatus(b.agent, "online");
            await wait(300);
            break;
          }
          case "consensus": {
            const owners = stageOwners();
            add({ kind: "consensus", id: nid(), event: b.event, by: b.by, version: b.version, owners, approvals: b.approvals });
            stageSet({ approvals: b.approvals, version: b.version });
            const m: Record<string, string> = {
              proposed: `📝 Proposal v${b.version} na ${name(b.by)} — approvals ${b.approvals.length}/${owners.length}`,
              reset: `♻️ Proposal mpya v${b.version} na ${name(b.by)} — approvals za zamani zimefutwa`,
              agreed: `🤝 ${name(b.by)} amekubali`,
              reached: `🤝 Consensus ${owners.length}/${owners.length} — v${b.version}`,
              exhausted: `🟠 Exchanges zimeisha bila consensus (${b.approvals.length}/${owners.length})`,
            };
            log(b.event === "exhausted" ? "warning" : b.event === "reached" ? "success" : "info", m[b.event]);
            await wait(b.event === "reached" ? 900 : 500);
            break;
          }
          case "chair": {
            const id = nid();
            add({ kind: "chair", id, target: b.target, reason: b.reason, text: b.text, shown: 0 });
            log("info", `🧠 [BRAIN] chair.challenge · Optimus → ${name(b.target)} · ${b.reason}`);
            setStatus("optimus", "speaking");
            await wait(500);
            await reveal(id, "shown", b.text.length, 4, 16);
            use("optimus", 600);
            setStatus("optimus", "online");
            await wait(500);
            break;
          }
          case "script": {
            const id = nid();
            const code = b.parts.join("");
            stageSet({ phase: "code", hadCode: true });
            add({ kind: "script", id, agent: b.agent, file: b.file, lang: b.lang, code, shown: 0, attempt: 1, maxAttempts: 3, state: "writing", version: 1 });
            setStatus(b.agent, "speaking");
            log("api", `${name(b.agent)} anaandika ${b.file}`);
            let offset = 0;
            for (let p = 0; p < b.parts.length; p++) {
              if (p > 0) {
                patch(id, { attempt: p + 1, state: "resume" });
                log("info", `♻️ ${name(b.agent)}: script haijakamilika — anaendelea pale alipoishia (${p}/3).`);
                await wait(1100);
                patch(id, { state: "writing" });
              }
              await reveal(id, "shown", offset + b.parts[p].length, 14, 16);
              offset += b.parts[p].length;
            }
            patch(id, { shown: code.length, state: "done" });
            use(b.agent, code.length * 2);
            setStatus(b.agent, "online");
            await wait(400);
            break;
          }
          case "review": {
            const id = nid();
            add({ kind: "review", id, agent: b.agent, verdict: "pending", round: b.round, maxRounds: 2, notes: [] });
            setStatus(b.agent, "thinking");
            await wait(1400);
            patch(id, { verdict: b.verdict, notes: b.notes });
            use(b.agent, 700);
            setStatus(b.agent, "online");
            log(b.verdict === "approve" ? "success" : "warning", b.verdict === "approve" ? `✅ ${name(b.agent)}: script zimekaguliwa na kukubaliwa.` : `🛠️ ${name(b.agent)}: script imerudishwa kwa marekebisho — round ${b.round}/2.`);
            await wait(500);
            break;
          }
          case "patch": {
            // engine: script_diff → ujumbe mpya wa script (surgical patch); wa zamani unadissolve kuwa mstari mfupi
            const prev = [...local].reverse().find((x) => x.kind === "script" && x.agent === b.agent && x.file === b.file && !x.replaced);
            const add_ = b.hunks.reduce((n, h) => n + h.new.length, 0);
            const del_ = b.hunks.reduce((n, h) => n + h.old.length, 0);
            const base = prev && prev.kind === "script" ? prev : undefined;
            const { code, changed } = applyHunks(base?.code ?? "", b.hunks);
            const id = nid();
            add({
              kind: "script", id, agent: b.agent, file: b.file, lang: base?.lang ?? "typescript", code, shown: code.length,
              attempt: 1, maxAttempts: 3, state: "patching", version: (base?.version ?? 1) + 1,
              patch: { reason: b.reason, add: add_, del: del_, hunks: b.hunks, changed },
            });
            setStatus(b.agent, "speaking");
            await wait(1300);
            patch(id, { state: "done" });
            if (base) patch(base.id, { replaced: { add: add_, del: del_ } });
            use(b.agent, 500);
            setStatus(b.agent, "online");
            log("success", `↕️ ${name(b.agent)}: script ilisasishwa ${b.file} (+${add_} −${del_})`);
            await wait(500);
            break;
          }
          case "deliverable": {
            const scr = [...itemsRef()].reverse().find((x) => x.kind === "script" && x.agent === b.agent && x.file === b.file);
            const lines = scr && scr.kind === "script" ? scr.code.split("\n").length : 20;
            add({ kind: "deliverable", id: nid(), agent: b.agent, file: b.file, lines, agenda: b.agenda });
            await wait(350);
            break;
          }
          case "memory": {
            const id = nid();
            const agents = AGENTS.map((a) => ({ id: a.id, state: "wait" as const }));
            add({ kind: "memory", id, scope: b.scope, agenda: b.agenda, agents, done: false });
            if (b.scope === "agenda") stageSet({ phase: "memory" });
            else stageSet({ scope: "finale", finale: "reflect" });
            for (const a of AGENTS) {
              const label = b.scope === "agenda" ? `${a.name} anaandika agenda memory checkpoint…` : b.scope === "reflection" ? `${a.name} anafanya final reflection…` : `Optimus anaunganisha memory ya ${a.name}…`;
              stageSet({ background: label });
              patch<Extract<StageItem, { kind: "memory" }>>(id, (x) => ({ agents: x.agents.map((g) => (g.id === a.id ? { ...g, state: "run" } : g)) }));
              if (b.scope !== "consolidate") setStatus(a.id, "thinking");
              await wait(b.scope === "consolidate" ? 420 : 560);
              const none = b.none?.includes(a.id);
              patch<Extract<StageItem, { kind: "memory" }>>(id, (x) => ({ agents: x.agents.map((g) => (g.id === a.id ? { ...g, state: none ? "none" : "saved" } : g)) }));
              if (b.scope !== "consolidate") setStatus(a.id, "online");
              log(none ? "info" : "success", `🧠 [BRAIN] ${b.scope === "agenda" ? `memory.checkpoint · agenda ${b.agenda}` : b.scope} · ${a.name} · ${none ? "NO_MEMORY" : "OK"}`);
            }
            patch(id, { done: true });
            stageSet({ background: null });
            await wait(300);
            break;
          }
          case "seal": {
            const id = nid();
            const a = agendaOf(b.index);
            add({
              kind: "seal", id, agenda: a, status: b.status, version: b.version, decision: b.decision, rationale: b.rationale, tradeoff: b.tradeoff,
              constraints: b.constraints, owners: a.owners, sources: b.sources, ledgerId: b.ledgerId, supersedes: b.supersedes,
            });
            stageSet((s) => ({ phase: "lock", ledger: { ...s.ledger, [b.index]: { status: b.status, version: b.version } } }));
            log(b.status === "LOCKED" ? "success" : "warning", b.status === "LOCKED" ? `🔒 LOCKED: ${a.title} (ledger #${b.ledgerId})` : `🟠 OPEN: ${a.title} → hakuna consensus ya kutosha`);
            await wait(700);
            break;
          }
          case "observers": {
            const id = nid();
            add({ kind: "observers", id, agenda: b.index, checks: b.observers.map((agent) => ({ agent, state: "wait" as const })) });
            stageSet({ phase: "review" });
            let objected = false;
            for (const ob of b.observers) {
              const set = (state: "check" | "silent" | "objection" | "skipped") =>
                patch<Extract<StageItem, { kind: "observers" }>>(id, (x) => ({ checks: x.checks.map((c) => (c.agent === ob ? { ...c, state } : c)) }));
              if (objected) { set("skipped"); continue; }
              set("check");
              setStatus(ob, "thinking");
              await wait(900);
              setStatus(ob, "online");
              if (b.objection?.agent === ob) {
                set("objection");
                objected = true;
                patch(id, { objection: { agent: ob, concern: b.objection.concern, severity: "high" as const } });
                stageSet({ hadObjection: true });
                log("warning", `🛑 Objection halali kutoka ${name(ob)}: ${b.objection.concern.slice(0, 80)}…`);
                use(ob, 400);
              } else {
                set("silent");
                log("info", `🤫 ${name(ob)}: SILENT accepted — hakuna objection ya domain.`);
                use(ob, 200);
              }
            }
            await wait(600);
            break;
          }
          case "supersede": {
            const id = nid();
            add({ kind: "supersede", id, agenda: b.index, objector: b.objector, responder: b.responder, from: { ...b.from, version: 1 }, to: { ...b.to, version: 2 } });
            mapItems((x) => (x.kind === "seal" && x.agenda.index === b.index ? { ...x, superseded: true } : x));
            stageSet((s) => ({ ledger: { ...s.ledger, [b.index]: { status: "SUPERSEDED+LOCKED", version: 2 } } }));
            log("success", `🔁 SUPERSEDED #${b.from.ledgerId} → RE-LOCKED #${b.to.ledgerId}`);
            await wait(700);
            break;
          }
          case "overruled": {
            add({ kind: "overruled", id: nid(), objector: b.objector, responder: b.responder, concern: b.concern, reason: b.reason });
            log("info", `↩️ Objection imekataliwa: ${b.reason.slice(0, 80)}`);
            await wait(700);
            break;
          }
          case "validator": {
            const id = nid();
            add({ kind: "validator", id, scope: b.scope, rows: b.rows.map((r) => ({ index: r.index, title: r.title, state: "wait" as const })), done: false });
            if (b.scope === "ledger") stageSet({ scope: "finale", finale: "validate" });
            for (const r of b.rows) {
              const set = (state: "check" | typeof r.final) =>
                patch<Extract<StageItem, { kind: "validator" }>>(id, (x) => ({ rows: x.rows.map((y) => (y.index === r.index ? { ...y, state } : y)) }));
              set("check");
              await wait(380);
              set(r.final);
            }
            patch(id, { done: true });
            log("success", b.scope === "ledger" ? `✅ Validator: agenda ${b.rows.length}/${b.rows.length} ziko kwenye Ledger` : `✅ Validator: ripoti ina agenda zote ${b.rows.length}/${b.rows.length}`);
            await wait(500);
            break;
          }
          case "notice": {
            add({ kind: "notice", id: nid(), tone: b.tone, agent: b.agent, text: b.text, detail: b.detail });
            log(b.tone === "error" || b.tone === "halt" ? "error" : "warning", b.text);
            await wait(500);
            break;
          }
          case "assembly": {
            const id = nid();
            const code = b.parts.join("");
            stageSet({ scope: "finale", finale: "assemble" });
            add({ kind: "assembly", id, pieces: b.pieces, merged: 0, file: b.file, code, shown: 0, attempt: 1, maxAttempts: 6, done: false });
            log("system", "🧩 Optimus anaunganisha deliverables kuwa script moja…");
            setStatus("optimus", "speaking");
            for (let k = 1; k <= b.pieces.length; k++) { await wait(700); patch(id, { merged: k }); }
            if (instant) patch(id, { merged: b.pieces.length });
            let offset = 0;
            for (let p = 0; p < b.parts.length; p++) {
              if (p > 0) { patch(id, { attempt: p + 1 }); log("info", `♻️ Optimus: anaunganisha script ya mwisho — inaendelea (${p}/6).`); await wait(800); }
              await reveal(id, "shown", offset + b.parts[p].length, 16, 16);
              offset += b.parts[p].length;
            }
            patch(id, { done: true, shown: code.length });
            use("optimus", code.length * 2);
            setStatus("optimus", "online");
            log("success", `📦 Optimus: script ya mwisho imeunganishwa (${code.length} chars).`);
            await wait(500);
            break;
          }
          case "report": {
            const id = nid();
            type Sec = Extract<StageItem, { kind: "report" }>["sections"][number];
            stageSet({ scope: "finale", finale: "report" });
            add({
              kind: "report", id, title: b.title, part: 1, reportId: b.reportId, doc: "", shown: 0, saved: "wait", startedAt: Date.now(),
              sections: REPORT_SECTIONS.map((t, i) => ({ n: i + 1, title: t, state: "wait" as const, chars: 0 })),
            });
            setStatus("optimus", "speaking");
            const setSecs = (fn: (s: Sec) => Sec) => patch<Extract<StageItem, { kind: "report" }>>(id, (x) => ({ sections: x.sections.map(fn) }));
            let doc = "";
            let shown = 0;
            /** stream doc (shown → doc.length) neno kwa neno; hali ya sehemu inatokana na headings zinazoonekana */
            const stream = async (repair: boolean, from: number) => {
              const heads = [...doc.matchAll(/^## (\d+)\./gm)].map((m) => ({ n: Number(m[1]), at: m.index ?? 0 }));
              const sizeOf = (i: number) => (heads[i + 1]?.at ?? doc.length) - heads[i].at;
              let active = -2;
              const sync = () => {
                let cur = -1;
                heads.forEach((h, i) => { if (h.at < shown) cur = i; });
                if (cur === active) return;
                active = cur;
                setSecs((s) => {
                  const i = heads.findIndex((h) => h.n === s.n);
                  if (i < 0 || heads[i].at < from || heads[i].at >= shown) return s;
                  if (i < cur) return { ...s, state: repair ? "repaired" : "done", chars: sizeOf(i) };
                  if (i === cur) return { ...s, state: repair ? "repairing" : "writing" };
                  return s;
                });
              };
              if (instant) { shown = doc.length; patch(id, { shown }); sync(); return; }
              const re = /\S+\s*/g;
              re.lastIndex = shown;
              while (shown < doc.length) {
                for (let w = 0; w < 2; w++) { const m = re.exec(doc); shown = m ? m.index + m[0].length : doc.length; if (!m) break; }
                patch(id, { shown });
                sync();
                await wait(50); // ~40 maneno/s — kasi ya LLM halisi, macho yanaweza kufuata
              }
            };
            const finish = (ns: number[], repair: boolean) => {
              const heads = [...doc.matchAll(/^## (\d+)\./gm)].map((m) => ({ n: Number(m[1]), at: m.index ?? 0 }));
              setSecs((s) => {
                if (!ns.includes(s.n)) return s;
                const i = heads.findIndex((h) => h.n === s.n);
                const chars = i >= 0 ? (heads[i + 1]?.at ?? doc.length) - heads[i].at : s.chars;
                return { ...s, state: repair ? "repaired" : "done", chars };
              });
            };
            for (let p = 0; p < b.parts.length; p++) {
              const part = b.parts[p];
              const from = doc ? doc.length + 2 : 0;
              doc = doc ? `${doc}\n\n${part.text}` : part.text;
              patch(id, { part: (p + 1) as 1 | 2, doc });
              log("system", `📑 Optimus anaandika ripoti — Kipande ${p + 1}/2 (${part.sections[0]}-${part.sections[part.sections.length - 1]})…`);
              await stream(false, from);
              finish(part.sections, false);
              log("success", `✅ Kipande ${p + 1}/2 kimekamilika.`);
              await wait(400);
            }
            setSecs((s) => (b.missing.includes(s.n) ? { ...s, state: "missing" } : s));
            log("warning", `🛠️ Optimus anarekebisha ripoti: ${b.missing.map((n) => REPORT_SECTIONS[n - 1]).join(", ")}…`);
            await wait(900);
            const repairFrom = doc.length + 2;
            doc = `${doc}\n\n${b.repairText}`;
            patch(id, { part: 3, doc, repairFrom });
            setSecs((s) => (b.missing.includes(s.n) ? { ...s, state: "repairing" } : s));
            await stream(true, repairFrom);
            finish(b.missing, true);
            patch(id, { saved: "saving" });
            await wait(900);
            patch(id, { saved: "saved" });
            use("optimus", 9000);
            setStatus("optimus", "online");
            log("success", "✅ Ripoti kamili (10/10) imehifadhiwa Reports Dashboard.");
            await wait(400);
            break;
          }
          case "summary": {
            const all = itemsRef();
            const seals = all.filter((x) => x.kind === "seal");
            add({
              kind: "summary", id: nid(),
              seconds: instant ? 412 : Math.round((Date.now() - t0) / 1000),
              usage: AGENTS.map((a) => ({ agent: a.id, requests: usage[a.id]?.requests ?? 0, tokens: usage[a.id]?.tokens ?? 0 })),
              locked: seals.filter((x) => x.kind === "seal" && x.status === "LOCKED").length,
              superseded: all.filter((x) => x.kind === "supersede").length,
              open: seals.filter((x) => x.kind === "seal" && x.status === "OPEN").length,
              sources: new Set(all.flatMap((x) => (x.kind === "evidence" ? x.trace.sources : x.kind === "turn" && x.search ? x.search.sources : []).map((s) => s.url))).size,
              memories: all.reduce((n, x) => n + (x.kind === "memory" && x.scope !== "consolidate" ? x.agents.filter((g) => g.state === "saved").length : 0), 0),
            });
            log("success", "🤝 Mjadala umekamilika. Ripoti iko kwenye 📑 Reports.");
            break;
          }
        }
      }

      function stageOwners(): AgentId[] {
        return st.owners.length ? st.owners : ["optimus"];
      }
      function itemsRef(): StageItem[] {
        return local;
      }
      /** index ya zamu inayofuata ya agent (bila evidence nyingine ya agent huyo katikati) */
      function nextTurnOf(agent: AgentId): number {
        for (let j = beatIdx + 1; j < STAGE_BEATS.length; j++) {
          const x = STAGE_BEATS[j];
          if (x.do === "evidence" && x.agent === agent) return -1;
          if (x.do === "turn" && x.agent === agent) return j;
        }
        return -1;
      }
      /** Search pipeline (cache → memory → relevance → SearXNG retries → sources → save) */
      async function runTrace(b: EvBeat, set: (p: Partial<SearchTrace> | ((x: SearchTrace) => Partial<SearchTrace>)) => void) {
        const who = name(b.agent);
        if (instant) {
          set({ queryShown: b.query.length });
        } else {
          for (let k = 3; k < b.query.length; k += 3) { set({ queryShown: k }); await wait(16); }
          set({ queryShown: b.query.length });
        }
        let fresh = true;
        if (b.memoryHit) {
          set({ cache: "skip", memory: "run" });
          log("search", `🧠 ${who} anaangalia memory ya mjadala huu kwanza…`);
          await wait(900);
          set({ memory: "done", engine: "skip", save: "skip" });
          log("success", `✅ ${who}: amepata kwenye memory — hahitaji search mpya.`);
          fresh = false;
        } else if (b.cache === "skip") {
          set({ cache: "skip" });
        } else {
          set({ cache: "run" });
          log("search", `🔍 ${who} anakagua Appwrite cache kwanza (Semantic Search)…`);
          await wait(1000);
          if (b.cache === "hit") {
            set({ cache: "done", similarity: b.similarity, matched: b.matched });
            log("success", `✅ ${who} KAPATA kwenye Appwrite! Similarity: ${b.similarity}%`);
            if (b.stale) {
              set({ relevance: "run" });
              await wait(700);
              set({ relevance: "fail" });
              log("warning", `⚠️ ${who}: cache hit haionekani relevant — fresh verification search.`);
            } else {
              set({ engine: "skip", save: "skip" });
              fresh = false;
            }
          } else {
            set({ cache: "fail", similarity: b.similarity });
            log("warning", `❌ ${who} KAKOSA kwenye Appwrite — similarity ${b.similarity}% (threshold 80%).`);
          }
        }
        if (fresh) {
          let attempt = 1;
          for (let f = 0; f < (b.engineFails ?? 0); f++) {
            set({ engine: "run", attempt });
            log("search", `🌐 ${who} anawasha SearXNG engine… (attempt ${attempt}/11)`);
            await wait(900);
            set((x) => ({ engine: "fail", failures: x.failures + 1 }));
            log("warning", `⚠️ ${who}: SearXNG attempt ${attempt}/11 imefeli — HTTP 502`);
            for (let s = 3; s >= 1; s--) { set({ waitLeft: s }); await wait(650); }
            set({ waitLeft: undefined });
            attempt++;
          }
          set({ engine: "run", attempt });
          log("search", `🌐 ${who} anawasha SearXNG engine… (attempt ${attempt}/11)`);
          await wait(1100);
          set({ engine: "done" });
          log("success", `📥 ${who}: matokeo ${b.sources.length} KUTOKA SEARCH ENGINE.`);
        }
        for (let k = 0; k < b.sources.length; k++) {
          await wait(220);
          set((x) => ({ sources: [...x.sources, b.sources[k]] }));
        }
        if (fresh) {
          set({ save: "run" });
          await wait(600);
          set({ save: "done" });
          log("success", `✅ ${who}: SAVE SUCCESS — vector + results zimehifadhiwa Appwrite.`);
        }
        set({ done: true });
      }
    },
    [addLog, bumpUsage, resetStatus, setBoardLive, setStatus],
  );

  return { items, stage, phase, title, run, stop, reset };
}
XMD_SURGERY_EOF_3

echo "✍️  src/components/board/stage/Finale.tsx"
cat > "src/components/board/stage/Finale.tsx" <<'XMD_SURGERY_EOF_4'
"use client";
import Link from "next/link";
import { useLayoutEffect, useRef, useState } from "react";
import { AlertTriangle, ArrowRight, ArrowRightLeft, ChevronDown, FileText, Info, Play, RotateCcw, Sparkles, Wrench, XCircle } from "lucide-react";
import type { NoticeItem, ReportItem, SummaryItem } from "@/lib/stage/types";
import { cn, compact } from "@/lib/utils";
import { AgentAvatar } from "../../ui/AgentAvatar";
import { Markdown } from "../../ui/Markdown";
import { Lane, Spinner, TONE, Tag, ag } from "./kit";

/* ============================================================== report writer — "hati hai"
 * engine: HATUA 7 — "📑 Kipande 1/2 (1-5)", "2/2 (6-10)" · repair "🛠️ …missing" · saveReport
 * Ripoti inastreamiwa neno kwa neno kwenye ukurasa unaofuata mstari wa mwisho (live).
 * Mstari wa sehemu 10 unaonyesha kila sehemu: inasubiri · inaandikwa · imekamilika · imekosekana · inarekebishwa. */
const SEG: Record<ReportItem["sections"][number]["state"], string> = {
  wait: "rgb(255 255 255 / 0.08)",
  writing: "#a78bfa",
  done: "#34d399",
  missing: "#f87171",
  repairing: "#fbbf24",
  repaired: "#fbbf24",
};

export function ReportWriter({ it }: { it: ReportItem }) {
  const saved = it.saved === "saved";
  const streaming = it.shown < it.doc.length;
  const [expanded, setExpanded] = useState(false);
  const page = useRef<HTMLDivElement>(null);
  const stick = useRef(true);

  const text = it.doc.slice(0, it.shown);
  const cut = it.repairFrom ?? Infinity;
  const main = text.slice(0, Math.min(text.length, cut));
  const fix = text.length > cut ? text.slice(cut) : "";
  const words = text.trim() ? text.trim().split(/\s+/).length : 0;
  const secs = Math.max(1, (Date.now() - it.startedAt) / 1000);
  const done = it.sections.filter((s) => s.state === "done" || s.state === "repaired").length;
  const current = it.sections.find((s) => s.state === "writing" || s.state === "repairing");
  const missing = it.sections.filter((s) => s.state === "missing");

  // ukurasa unafuata mstari wa mwisho — isipokuwa mtumiaji amepanda juu kusoma
  useLayoutEffect(() => {
    const el = page.current;
    if (el && stick.current && !saved) el.scrollTop = el.scrollHeight;
  }, [it.shown, saved]);

  const tone = saved ? TONE.ok : it.part === 3 ? TONE.warn : TONE.violet;

  return (
    <Lane className="space-y-3">
      <div className="overflow-hidden rounded-2xl border transition-colors duration-500" style={{ borderColor: `rgb(${tone.rgb} / 0.24)`, background: `linear-gradient(160deg, rgb(${tone.rgb} / 0.08), rgb(${tone.rgb} / 0.01) 45%)` }}>
        {/* header */}
        <div className="flex items-start gap-3 px-4 pt-4">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-prism text-white shadow-[0_8px_24px_-10px_rgb(139_92_246/0.8)]"><FileText size={16} /></span>
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <p className="text-[10.5px] font-semibold uppercase tracking-[0.14em]" style={{ color: tone.c }}>{saved ? "Ripoti imekamilika" : "Optimus anaandika ripoti"}</p>
              {!saved && (
                <span className="inline-flex h-[18px] items-center gap-1 rounded-full bg-[rgb(248_113_113/0.12)] px-1.5 text-[9.5px] font-bold tracking-[0.12em] text-[#fca5a5]">
                  <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-[#f87171]" /> LIVE
                </span>
              )}
            </div>
            <p className="mt-0.5 truncate text-[14px] font-semibold text-[var(--color-fg)]">{it.title}</p>
          </div>
        </div>

        {/* mstari wa sehemu 10 */}
        <div className="px-4 pt-3">
          <div className="flex gap-1">
            {it.sections.map((s) => (
              <span
                key={s.n}
                title={`${s.n}. ${s.title}`}
                className={cn("h-1.5 flex-1 rounded-full transition-colors duration-500", (s.state === "writing" || s.state === "repairing") && "animate-pulse")}
                style={{ background: SEG[s.state] }}
              />
            ))}
          </div>
          <div className="mt-2 flex items-center gap-2 text-[11.5px]">
            {current ? (
              <>
                <Spinner size={10} color={SEG[current.state]} />
                <span className="shimmer-text truncate font-medium">{current.state === "repairing" ? "Inarekebisha" : "Sasa"}: {current.n}. {current.title}</span>
              </>
            ) : missing.length ? (
              <span className="truncate text-[var(--color-bad)]">Imekosekana: {missing.map((m) => `${m.n}. ${m.title}`).join(", ")} — inarekebishwa…</span>
            ) : saved ? (
              <span className="text-[var(--color-muted)]">Sehemu zote 10 zimekamilika</span>
            ) : (
              <span className="shimmer-text font-medium">Anaandaa kipande kinachofuata…</span>
            )}
            <span className="ml-auto flex shrink-0 items-center gap-1.5">
              {!saved && (
                <Tag tone={it.part === 3 ? "warn" : "violet"}>
                  {it.part === 3 ? <><Wrench size={10} /> Marekebisho</> : `Kipande ${it.part}/2`}
                </Tag>
              )}
              <span className="font-mono text-[10.5px] text-[var(--color-faint)]">{done}/10</span>
            </span>
          </div>
        </div>

        {/* ukurasa hai */}
        <div className="relative mx-3 mt-3">
          <div
            ref={page}
            onScroll={(e) => { const el = e.currentTarget; stick.current = el.scrollHeight - el.scrollTop - el.clientHeight < 40; }}
            className="overflow-y-auto rounded-xl border border-[var(--color-line)] bg-[rgb(8_10_14/0.6)] px-4 py-3 text-[13px] [scrollbar-width:thin]"
            style={{ maxHeight: saved && !expanded ? 240 : 400 }}
          >
            <div className={cn("st-doc", streaming && !fix && "st-doc-live")}>
              <Markdown text={main || " "} />
            </div>
            {fix && (
              <div className="mt-3 border-l-2 border-[var(--color-warn)] pl-3 animate-[fade_0.4s_both]">
                <p className="mb-1 flex items-center gap-1.5 text-[10.5px] font-semibold uppercase tracking-[0.12em] text-[var(--color-warn)]"><Wrench size={11} /> Marekebisho · sehemu iliyokosekana</p>
                <div className={cn("st-doc", streaming && "st-doc-live")}>
                  <Markdown text={fix} />
                </div>
              </div>
            )}
          </div>
          {saved && !expanded && (
            <div className="pointer-events-none absolute inset-x-px bottom-px flex h-20 items-end justify-center rounded-b-xl bg-gradient-to-t from-[rgb(8_10_14)] to-transparent pb-2">
              <button onClick={() => setExpanded(true)} className="pointer-events-auto flex h-7 items-center gap-1 rounded-full border border-[var(--color-line-strong)] bg-[var(--color-ink-2)] px-3 text-[11.5px] text-[var(--color-fg-2)] hover:text-[var(--color-fg)]">
                Soma yote <ChevronDown size={12} />
              </button>
            </div>
          )}
        </div>

        {/* takwimu */}
        <div className="flex flex-wrap items-center gap-x-3 gap-y-1 px-4 py-2.5 text-[11px] text-[var(--color-muted)]">
          <span><b className="font-mono font-semibold text-[var(--color-fg-2)]">{words}</b> maneno</span>
          <span><b className="font-mono font-semibold text-[var(--color-fg-2)]">{compact(text.length)}</b> herufi</span>
          {streaming && <span><b className="font-mono font-semibold text-[var(--color-fg-2)]">{Math.round(words / secs)}</b> maneno/s</span>}
          <span className="ml-auto">
            {it.saved === "saving" ? <span className="shimmer-text font-medium">Inahifadhi kwenye Reports…</span>
              : it.saved === "failed" ? <span className="text-[var(--color-bad)]">Imeshindwa kuhifadhiwa</span>
              : saved ? <span className="text-[var(--color-ok)]">Imehifadhiwa</span>
              : <span className="text-[var(--color-faint)]">inaandikwa live</span>}
          </span>
        </div>
      </div>

      {saved && (
        <div className="prism-border relative overflow-hidden rounded-2xl bg-[linear-gradient(135deg,rgb(61_123_255/0.08),rgb(217_70_239/0.06))] p-4 animate-[rise_0.5s_both]">
          <div className="flex items-center gap-3">
            <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-prism text-white shadow-[0_8px_24px_-8px_rgb(139_92_246/0.8)]"><FileText size={18} /></span>
            <div className="min-w-0 flex-1">
              <p className="text-[10.5px] font-semibold uppercase tracking-[0.14em] text-[#c4b5fd]">Report filed · Swahili</p>
              <p className="truncate text-[14px] font-semibold">{it.title}</p>
            </div>
            <Link href={`/reports?open=${it.reportId}`} className="btn-white flex h-9 shrink-0 items-center gap-1.5 rounded-xl px-3 text-[12.5px] font-semibold">
              Open <ArrowRight size={14} />
            </Link>
          </div>
        </div>
      )}
    </Lane>
  );
}

/* ============================================================== notices
 * engine: chips za retry / rotation / warn / error / halt (Resume) */
const NOTICE = {
  retry: { icon: RotateCcw, c: TONE.warn.c },
  rotate: { icon: ArrowRightLeft, c: TONE.sky.c },
  warn: { icon: AlertTriangle, c: TONE.warn.c },
  error: { icon: XCircle, c: TONE.bad.c },
  halt: { icon: XCircle, c: TONE.bad.c },
  info: { icon: Info, c: TONE.muted.c },
} as const;

export function NoticeLine({ it, onResume }: { it: NoticeItem; onResume?: () => void }) {
  const n = NOTICE[it.tone];
  if (it.tone === "halt")
    return (
      <Lane>
        <div className="flex flex-wrap items-center gap-3 rounded-xl border border-[rgb(248_113_113/0.3)] bg-[rgb(248_113_113/0.07)] px-3.5 py-2.5">
          <n.icon size={15} style={{ color: n.c }} />
          <div className="min-w-0 flex-1">
            <p className="text-[12.5px] font-semibold text-[var(--color-fg)]">{it.text}</p>
            {it.detail && <p className="text-[11.5px] text-[var(--color-muted)]">{it.detail}</p>}
          </div>
          <button onClick={onResume} className="btn-white flex h-8 items-center gap-1.5 rounded-lg px-3 text-[12px] font-medium"><Play size={12} /> Resume</button>
        </div>
      </Lane>
    );
  return (
    <Lane>
      <div className="flex items-center gap-2 py-0.5 text-[11.5px]">
        <n.icon size={12} style={{ color: n.c }} className="shrink-0" />
        {it.agent && <AgentAvatar agent={ag(it.agent)} size={14} ring={false} />}
        <span className="min-w-0 flex-1 truncate text-[var(--color-muted)]">{it.text}</span>
        {it.detail && <span className="shrink-0 truncate rounded bg-white/[0.04] px-1.5 py-0.5 font-mono text-[10.5px] text-[var(--color-fg-2)]">{it.detail}</span>}
      </div>
    </Lane>
  );
}

/* ============================================================== summary
 * engine: bcast({type:"summary"}) + done — "🤝 Mjadala umekamilika" */
export function SummaryCard({ it }: { it: SummaryItem }) {
  const max = Math.max(1, ...it.usage.map((u) => u.tokens));
  const total = it.usage.reduce((n, u) => n + u.tokens, 0);
  const mm = `${Math.floor(it.seconds / 60)}:${String(it.seconds % 60).padStart(2, "0")}`;
  const stats = [
    { k: "LOCKED", v: it.locked, c: TONE.ok.c },
    { k: "SUPERSEDED", v: it.superseded, c: TONE.violet.c },
    { k: "OPEN", v: it.open, c: TONE.warn.c },
    { k: "Sources", v: it.sources, c: TONE.sky.c },
    { k: "Memories", v: it.memories, c: "#d8b4fe" },
  ];
  return (
    <Lane>
      <div className="prism-border overflow-hidden rounded-2xl bg-[var(--color-ink-1)]">
        <div className="flex items-center gap-3 px-4 pb-3 pt-4">
          <span className="grid h-9 w-9 place-items-center rounded-xl bg-prism text-white"><Sparkles size={16} /></span>
          <div className="min-w-0 flex-1">
            <p className="text-[15px] font-semibold tracking-[-0.01em]">Mjadala umekamilika</p>
            <p className="text-[11.5px] text-[var(--color-muted)]">Muda {mm} · tokens {compact(total)} · ripoti iko kwenye Reports</p>
          </div>
        </div>
        <div className="grid grid-cols-5 border-y border-[var(--color-line)]">
          {stats.map((s, i) => (
            <div key={s.k} className={cn("px-1 py-2.5 text-center sm:px-2", i > 0 && "border-l border-[var(--color-line)]")}>
              <p className="font-mono text-[18px] font-semibold leading-6" style={{ color: s.c }}>{s.v}</p>
              <p className="truncate text-[8px] font-semibold uppercase tracking-normal text-[var(--color-faint)] sm:text-[9.5px] sm:tracking-[0.1em]">{s.k}</p>
            </div>
          ))}
        </div>
        <div className="space-y-1.5 px-4 py-3">
          {it.usage.map((u) => {
            const a = ag(u.agent);
            return (
              <div key={u.agent} className="flex items-center gap-2.5 text-[11.5px]">
                <AgentAvatar agent={a} size={18} ring={false} />
                <span className="w-[70px] shrink-0 text-[var(--color-fg-2)]">{a.name}</span>
                <span className="h-[6px] flex-1 overflow-hidden rounded-full bg-white/[0.05]">
                  <span className="block h-full rounded-full transition-[width] duration-700" style={{ width: `${(u.tokens / max) * 100}%`, background: a.accent }} />
                </span>
                <span className="w-[76px] shrink-0 text-right font-mono text-[10.5px] text-[var(--color-muted)]">{compact(u.tokens)} · {u.requests}×</span>
              </div>
            );
          })}
        </div>
        <div className="flex border-t border-[var(--color-line)]">
          <Link href="/reports" className="flex flex-1 items-center justify-center gap-1.5 py-2.5 text-[12px] font-medium text-[var(--color-fg)] hover:bg-white/[0.03]"><FileText size={13} /> Fungua ripoti</Link>
          <Link href="/sessions" className="flex flex-1 items-center justify-center gap-1.5 border-l border-[var(--color-line)] py-2.5 text-[12px] text-[var(--color-muted)] hover:bg-white/[0.03] hover:text-[var(--color-fg)]">Sessions <ArrowRight size={12} /></Link>
        </div>
      </div>
    </Lane>
  );
}
XMD_SURGERY_EOF_4

echo "✍️  src/components/board/stage/StageStream.tsx"
cat > "src/components/board/stage/StageStream.tsx" <<'XMD_SURGERY_EOF_5'
"use client";
import "./stage.css";
import type { StageItem } from "@/lib/stage/types";
import { UserPrompt } from "../parts";
import { Fragment, memo, useCallback, useRef } from "react";
import { AgendaBuildCard, AgendaStartMark, ConveneCard, FinaleMark, ScopeCard } from "./Opening";
import { EvidenceCard } from "./Evidence";
import { ChairCard, ConsensusTick, StageMessage } from "./Turn";
import { AssemblyCard, DeliverableCard, ReviewCard, ScriptCard } from "./Code";
import { MemoryStrip, ObserversCard, OverruledCard, SealCard, SupersedeCard, TaskLine, ValidatorCard } from "./Ledger";
import { NoticeLine, ReportWriter, SummaryCard } from "./Finale";

/** Dispatcher: kila StageItem → render yake (hakuna tukio bila render). */
export function StageStream({ items, onResume }: { items: StageItem[]; onResume?: () => void }) {
  // callback thabiti → StageNode (memo) hairender upya kwa sababu ya arrow mpya ya mzazi
  const resumeRef = useRef(onResume);
  resumeRef.current = onResume;
  const resume = useCallback(() => resumeRef.current?.(), []);
  return (
    <div className="space-y-4">
      {items.map((it) => (
        <Fragment key={it.id}>
          {it.kind === "task" && it.task === "validate" && <FinaleMark />}
          <StageNode it={it} onResume={resume} />
        </Fragment>
      ))}
    </div>
  );
}

/** memo: item ni immutable — ni item iliyopatchiwa tu inayorender upya kila tick (zamani: Markdown yote ilichakatwa upya kila 16ms) */
const StageNode = memo(function StageNode({ it, onResume }: { it: StageItem; onResume?: () => void }) {
  switch (it.kind) {
    case "user": return <UserPrompt text={it.text} />;
    case "convene": return <ConveneCard it={it} />;
    case "scope": return <ScopeCard it={it} />;
    case "agendaBuild": return <AgendaBuildCard it={it} />;
    case "agendaStart": return <AgendaStartMark it={it} />;
    case "evidence": return <EvidenceCard it={it} />;
    case "turn": return <StageMessage it={it} />;
    case "consensus": return <ConsensusTick it={it} />;
    case "chair": return <ChairCard it={it} />;
    case "script": return <ScriptCard it={it} />;
    case "review": return <ReviewCard it={it} />;
    case "deliverable": return <DeliverableCard it={it} />;
    case "task": return <TaskLine it={it} />;
    case "memory": return <MemoryStrip it={it} />;
    case "seal": return <SealCard it={it} />;
    case "observers": return <ObserversCard it={it} />;
    case "supersede": return <SupersedeCard it={it} />;
    case "overruled": return <OverruledCard it={it} />;
    case "validator": return <ValidatorCard it={it} />;
    case "assembly": return <AssemblyCard it={it} />;
    case "report": return <ReportWriter it={it} />;
    case "notice": return <NoticeLine it={it} onResume={onResume} />;
    case "summary": return <SummaryCard it={it} />;
    default: {
      const never: never = it;
      return never;
    }
  }
});
XMD_SURGERY_EOF_5

echo "✍️  src/components/board/stage/StageRail.tsx"
cat > "src/components/board/stage/StageRail.tsx" <<'XMD_SURGERY_EOF_6'
"use client";
import { Link2, Lock, CircleDashed, Sparkles } from "lucide-react";
import { STAGE_AGENDA } from "@/lib/stage/script";
import type { AgendaPhase, FinalePhase, LiveStage } from "@/lib/stage/types";
import { cn } from "@/lib/utils";
import { TONE } from "./kit";

/* Rail ya maendeleo (sticky) — inaonyesha agenda zote, awamu ya sasa na kazi ya background.
 * Awamu zinatoka kwenye matukio ya engine (angalia usePlayback). */

const AGENDA_STEPS: { k: AgendaPhase; label: string }[] = [
  { k: "evidence", label: "Evidence" },
  { k: "discussion", label: "Mjadala" },
  { k: "code", label: "Code" },
  { k: "lock", label: "Ledger" },
  { k: "review", label: "Observers" },
  { k: "relock", label: "Re-lock" },
  { k: "memory", label: "Memory" },
];
const FINALE_STEPS: { k: FinalePhase; label: string }[] = [
  { k: "validate", label: "Validator" },
  { k: "assemble", label: "Script" },
  { k: "report", label: "Ripoti" },
  { k: "reflect", label: "Reflection" },
  { k: "done", label: "Imekamilika" },
];
// mpangilio halisi wa engine: lock → memory → observers → (relock)
const ORDER: AgendaPhase[] = ["evidence", "discussion", "code", "lock", "memory", "review", "relock"];

export function StageRail({ stage, live }: { stage: LiveStage; live: boolean }) {
  const inFinale = stage.scope === "finale" || stage.scope === "done";
  const steps = inFinale
    ? FINALE_STEPS
    : AGENDA_STEPS.filter((s) => (s.k === "code" ? stage.agenda?.requiresCode : s.k === "relock" ? stage.hadObjection : true))
        .sort((a, b) => ORDER.indexOf(a.k) - ORDER.indexOf(b.k));
  const cur = inFinale ? stage.finale : stage.phase;
  const curIdx = steps.findIndex((s) => s.k === cur);

  if (stage.scope === "opening") return null;

  return (
    <div className="glass sticky top-0 z-20 -mx-4 border-b border-[var(--color-line)] px-4 py-2 sm:-mx-6 sm:px-6">
      <div className="st-fog-x st-noscroll flex items-center gap-1.5 overflow-x-auto">
        {STAGE_AGENDA.map((a) => {
          const l = stage.ledger[a.index];
          const active = !inFinale && stage.agenda?.index === a.index && !l;
          const tone = l?.status === "OPEN" ? TONE.warn : l ? TONE.ok : null;
          return (
            <a key={a.index} href={`#agenda-${a.index}`} title={`${a.title}${l ? ` · ${l.status}` : ""}`}
              className={cn("flex h-6 shrink-0 items-center gap-1 rounded-full border px-2 text-[10.5px] font-semibold transition-all", active ? "prism-border text-[var(--color-fg)]" : "border-[var(--color-line)] text-[var(--color-muted)]")}
              style={tone ? { color: tone.c, borderColor: `rgb(${tone.rgb} / 0.35)`, background: `rgb(${tone.rgb} / 0.08)` } : undefined}>
              {l?.status === "SUPERSEDED+LOCKED" ? <Link2 size={10} /> : l?.status === "OPEN" ? <CircleDashed size={10} /> : l ? <Lock size={10} /> : active ? <span className="h-1.5 w-1.5 rounded-full bg-prism animate-pulse" /> : null}
              A{a.index}
              {l && <span className="font-mono font-normal opacity-80">v{l.version}</span>}
            </a>
          );
        })}
        <span className={cn("flex h-6 shrink-0 items-center gap-1 rounded-full border px-2 text-[10.5px] font-semibold", inFinale ? "prism-border text-[var(--color-fg)]" : "border-[var(--color-line)] text-[var(--color-faint)]")}>
          <Sparkles size={10} /> Finale
        </span>
        <span className="mx-1 h-4 w-px shrink-0 bg-[var(--color-line)]" />
        {steps.map((s, i) => {
          const done = i < curIdx || stage.scope === "done";
          const on = i === curIdx && stage.scope !== "done";
          return (
            <span key={s.k} className="flex shrink-0 items-center gap-1.5">
              {i > 0 && <span className={cn("h-px w-3", done || on ? "bg-[var(--color-line-strong)]" : "bg-[var(--color-line)]")} />}
              <span className={cn("flex items-center gap-1 text-[11px]", on ? "font-semibold text-[var(--color-fg)]" : done ? "text-[var(--color-muted)]" : "text-[var(--color-faint)]")}>
                <span className={cn("h-1.5 w-1.5 rounded-full", on ? "bg-prism animate-pulse" : done ? "bg-[var(--color-ok)]" : "bg-[var(--color-line-strong)]")} />
                {s.label}
              </span>
            </span>
          );
        })}
      </div>
      {live && stage.background && (
        <p className="shimmer-text mt-1 truncate text-[11px] font-medium">{stage.background}</p>
      )}
    </div>
  );
}
XMD_SURGERY_EOF_6

echo "✍️  src/components/board/stage/stage.css"
cat > "src/components/board/stage/stage.css" <<'XMD_SURGERY_EOF_7'
/* Stage — Board Room (faili jipya; globals.css haijaguswa).
 * Animations zinazoruhusiwa tu: rise/fade (globals), shimmer (globals .shimmer-text), spinner/pulse. */

/* fade kando (fog) kwa rails zinazoskrolla */
.st-fog-x { -webkit-mask-image: linear-gradient(90deg, transparent, #000 14px, #000 calc(100% - 22px), transparent); mask-image: linear-gradient(90deg, transparent, #000 14px, #000 calc(100% - 22px), transparent); }

/* skeleton ya shimmer (mistari inayosubiri) */
.st-skel {
  background: linear-gradient(90deg, rgb(255 255 255 / 0.04) 0%, rgb(255 255 255 / 0.04) 40%, rgb(255 255 255 / 0.1) 50%, rgb(255 255 255 / 0.04) 60%, rgb(255 255 255 / 0.04) 100%);
  background-size: 200% 100%;
  animation: shimmer 1.8s linear infinite;
}

/* ============================================================================
 * XMD Script Box — kutoka professor-xmd-company (01 Prism Glass), imeboreshwa:
 * live writing (mistari inafade in), continuation chip, surgical patch ndani ya box,
 * mistari iliyobadilika imewekwa alama, expand, sheen ya hover.
 * ========================================================================= */
.xsb {
  --sb-bg: rgba(10, 16, 28, 0.72);
  --sb-fg: #e7eef8;
  --sb-muted: #9bb0c4;
  --sb-border: rgba(255, 255, 255, 0.14);
  --sb-head: rgba(255, 255, 255, 0.035);
  --sb-ln: rgba(126, 224, 214, 0.42);
  --tok-kw: #7ee0d6;
  --tok-str: #f0c98a;
  --tok-cmt: #6d7480;
  --tok-fn: #9db7ff;
  --tok-num: #f0a8c0;
  --tok-type: #b7c4a1;
  --tok-punct: #7a8190;
  position: relative;
  display: flex;
  flex-direction: column;
  min-width: 0;
  max-width: 100%;
  overflow: hidden;
  color: var(--sb-fg);
  background: var(--sb-bg);
  border: 1px solid var(--sb-border);
  border-radius: 20px;
  backdrop-filter: blur(22px) saturate(160%);
  -webkit-backdrop-filter: blur(22px) saturate(160%);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.32),
    inset 0 -1px 0 rgba(255, 255, 255, 0.06),
    0 24px 60px -28px rgba(0, 0, 0, 0.65);
  transition: border-color 400ms ease, box-shadow 400ms ease;
}
.xsb[data-live="1"] { border-color: color-mix(in srgb, var(--acc, #7ee0d6) 38%, rgba(255, 255, 255, 0.1)); }
.xsb::after {
  content: "";
  pointer-events: none;
  position: absolute;
  inset: 0;
  background: linear-gradient(115deg, transparent 30%, rgba(255, 255, 255, 0.1) 48%, transparent 62%);
  transform: translateX(-80%);
  opacity: 0;
  transition: transform 700ms cubic-bezier(0.22, 1, 0.36, 1), opacity 400ms ease;
}
/* sheen kwa mouse tu — kwenye touch ilibaki imekwama upande wa kulia */
@media (hover: hover) and (pointer: fine) { .xsb:hover::after { transform: translateX(80%); opacity: 1; } }

.xsb-head {
  display: flex; align-items: center; gap: 8px;
  min-height: 42px; padding: 8px 8px 8px 12px;
  background: var(--sb-head);
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
}
.xsb-title {
  min-width: 0; flex-shrink: 0; max-width: 60%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  font-family: var(--font-mono); font-size: 12px; font-weight: 500; letter-spacing: 0.01em;
  color: var(--sb-fg); margin: 0;
}
.xsb-chip {
  display: inline-flex; align-items: center; gap: 4px; height: 20px; padding: 0 7px;
  border: 1px solid var(--sb-border); border-radius: 999px;
  font-family: var(--font-mono); font-size: 9.5px; letter-spacing: 0.08em; text-transform: uppercase;
  color: var(--sb-muted); white-space: nowrap;
}
.xsb-stats { font-family: var(--font-mono); font-size: 11px; font-weight: 600; white-space: nowrap; }
.xsb-btn {
  display: inline-flex; align-items: center; justify-content: center; gap: 6px;
  min-width: 34px; min-height: 30px; padding: 0 9px; border: 0; border-radius: 9px;
  background: transparent; color: var(--sb-muted);
  font-size: 10.5px; font-weight: 500; letter-spacing: 0.05em; text-transform: uppercase; cursor: pointer;
  transition: background-color 150ms cubic-bezier(0.22, 1, 0.36, 1), color 150ms cubic-bezier(0.22, 1, 0.36, 1), transform 150ms ease-out;
}
.xsb-btn:hover { background: color-mix(in oklab, var(--sb-fg) 8%, transparent); color: var(--sb-fg); }
.xsb-btn:active { transform: scale(0.96); }

.xsb-body {
  margin: 0; padding: 12px 14px 16px; overflow: auto;
  font-family: var(--font-mono); font-size: 12.5px; line-height: 1.7; tab-size: 2;
  scrollbar-width: thin; scrollbar-color: rgba(255, 255, 255, 0.12) transparent;
  transition: max-height 350ms cubic-bezier(0.22, 1, 0.36, 1);
}
.xsb-line {
  display: grid; grid-template-columns: 30px minmax(0, 1fr); column-gap: 12px;
  min-height: 1.7em; border-radius: 4px; position: relative;
}
.xsb-line.is-new { animation: fade 0.35s ease-out both; }
.xsb-ln { text-align: right; color: var(--sb-ln); user-select: none; font-variant-numeric: tabular-nums; }
.xsb-code { min-width: 0; white-space: pre; }
.xsb-line.is-changed { background: rgba(52, 211, 153, 0.07); }
.xsb-line.is-changed::before { content: ""; position: absolute; left: -14px; top: 2px; bottom: 2px; width: 2px; border-radius: 2px; background: #34d399; }

/* surgical patch (diff) */
.xsb-diff { margin: 0 0 12px; overflow: hidden; border-radius: 12px; border: 1px solid rgba(255, 255, 255, 0.08); background: rgba(0, 0, 0, 0.22); }
.xsb-diff-head { display: flex; align-items: center; gap: 8px; padding: 6px 10px; border-bottom: 1px solid rgba(255, 255, 255, 0.07); font-family: var(--font-sans, inherit); font-size: 10px; font-weight: 600; letter-spacing: 0.14em; text-transform: uppercase; color: var(--sb-muted); }
.xsb-diff .xsb-line { padding: 0 10px; border-radius: 0; }
.xsb-del { background: rgba(239, 68, 68, 0.14); }
.xsb-del .xsb-code { color: #fca5a5; text-decoration: line-through; text-decoration-color: rgba(252, 165, 165, 0.45); }
.xsb-add { background: rgba(52, 211, 153, 0.13); }
.xsb-add .xsb-code { color: #a7f3d0; }
.xsb-mark { color: var(--sb-muted); }

/* caret + progress */
.xsb-caret::after { content: ""; display: inline-block; width: 7px; height: 1.05em; margin-left: 1px; vertical-align: -0.15em; border-radius: 1px; background: var(--acc, #7ee0d6); animation: blink 1s steps(1) infinite; }
.xsb-progress { position: absolute; left: 0; right: 0; bottom: 0; height: 2px; overflow: hidden; }
.xsb-progress > span {
  display: block; height: 100%;
  background: linear-gradient(90deg, transparent 0%, var(--acc, #7ee0d6) 50%, transparent 100%);
  background-size: 200% 100%; animation: shimmer 1.4s linear infinite; opacity: 0.8;
}

/* tokens */
.tk-kw { color: var(--tok-kw); }
.tk-str { color: var(--tok-str); }
.tk-cmt { color: var(--tok-cmt); font-style: italic; }
.tk-fn { color: var(--tok-fn); }
.tk-num { color: var(--tok-num); }
.tk-type { color: var(--tok-type); }
.tk-p { color: var(--tok-punct); }

@media (prefers-reduced-motion: reduce) {
  .st-skel, .xsb-progress > span, .xsb-line.is-new, .xsb-caret::after { animation: none !important; }
  .xsb::after { display: none; }
}

/* ---------------------------------------------------------------- scroller bila mstari (StageRail n.k.) */
.st-noscroll { scrollbar-width: none; -ms-overflow-style: none; }
.st-noscroll::-webkit-scrollbar { display: none; width: 0; height: 0; background: transparent; }

/* ---------------------------------------------------------------- ripoti · hati hai */
.st-doc .prose-xmd { font-size: 13.5px; line-height: 1.7; }
.st-doc .prose-xmd > :first-child { margin-top: 0; padding-top: 0; }
.st-doc .prose-xmd h2 { font-size: 15px; margin-top: 1.3em; }
.st-doc-live .prose-xmd > :last-child:not(ul):not(ol):not(table):not(:has(table))::after,
.st-doc-live .prose-xmd > :is(ul, ol):last-child > li:last-child::after {
  content: ""; display: inline-block; width: 7px; height: 1.05em; margin-left: 2px; vertical-align: -0.15em;
  border-radius: 2px; background: #a78bfa; animation: blink 1s steps(1) infinite;
}
@media (prefers-reduced-motion: reduce) { .st-doc-live .prose-xmd *::after { animation: none !important; } }
XMD_SURGERY_EOF_7

echo "✍️  src/app/layout.tsx"
cat > "src/app/layout.tsx" <<'XMD_SURGERY_EOF_8'
import type { Metadata, Viewport } from "next";
import { Suspense, type ReactNode } from "react";
import { GeistSans } from "geist/font/sans";
import { GeistMono } from "geist/font/mono";
import "./globals.css";
import "./mobile.css";
import { AppStateProvider } from "@/components/shell/AppState";
import { Sidebar } from "@/components/shell/Sidebar";
import { Topbar } from "@/components/shell/Topbar";
import { ActivityPanel, BottomTabs, MobileDrawer } from "@/components/shell/Overlays";
import { ZoomLock } from "@/components/shell/ZoomLock";

export const metadata: Metadata = {
  title: "PROFESSOR-XMD — AI Engineering Company",
  description: "Five AI agents. One board room. Your project.",
  icons: { icon: "/favicon.png" },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  themeColor: "#07080b",
  interactiveWidget: "resizes-content",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className={`${GeistSans.variable} ${GeistMono.variable}`}>
      <body>
        <ZoomLock />
        <AppStateProvider>
          <div aria-hidden className="backdrop-aurora pointer-events-none fixed inset-0" />
          <div className="relative flex min-h-dvh">
            <Sidebar />
            <div className="flex min-w-0 flex-1 flex-col">
              {/* Topbar inatumia useSearchParams → inahitaji Suspense kwa `next build` */}
              <Suspense fallback={<div className="h-14 shrink-0" />}>
                <Topbar />
              </Suspense>
              <main className="flex min-h-0 flex-1 flex-col">{children}</main>
            </div>
          </div>
          <BottomTabs />
          <MobileDrawer />
<ActivityPanel />
        </AppStateProvider>
      </body>
    </html>
  );
}
XMD_SURGERY_EOF_8

echo "✍️  src/app/mobile.css"
cat > "src/app/mobile.css" <<'XMD_SURGERY_EOF_9'
/* Zoom lock ya simu — hakuna pinch / double-tap zoom (pamoja na viewport maximumScale=1 kwenye layout.tsx) */
html, body { touch-action: pan-x pan-y; -webkit-text-size-adjust: 100%; text-size-adjust: 100%; }
a, button, input, textarea, select, label, [role="button"] { touch-action: manipulation; }
XMD_SURGERY_EOF_9

echo "✍️  src/components/shell/ZoomLock.tsx"
cat > "src/components/shell/ZoomLock.tsx" <<'XMD_SURGERY_EOF_10'
"use client";
import { useEffect } from "react";

/**
 * Zoom lock ya simu.
 * iOS Safari hupuuza `user-scalable=no` — kwa hiyo tunazuia gesture za pinch (gesturestart/change)
 * na touchmove ya vidole ≥2. Android/Chrome inaheshimu viewport (maximumScale=1, userScalable=false).
 */
export function ZoomLock() {
  useEffect(() => {
    const stop = (e: Event) => e.preventDefault();
    const pinch = (e: TouchEvent) => { if (e.touches.length > 1) e.preventDefault(); };
    document.addEventListener("gesturestart", stop, { passive: false });
    document.addEventListener("gesturechange", stop, { passive: false });
    document.addEventListener("touchmove", pinch, { passive: false });
    return () => {
      document.removeEventListener("gesturestart", stop);
      document.removeEventListener("gesturechange", stop);
      document.removeEventListener("touchmove", pinch);
    };
  }, []);
  return null;
}
XMD_SURGERY_EOF_10

echo
if [[ -x node_modules/.bin/tsc ]]; then
  echo "🔎 tsc --noEmit…"
  rm -rf .next/types
  node_modules/.bin/tsc --noEmit -p . && echo "✅ TypeScript safi."
else
  echo "ℹ️  node_modules haipo — endesha: npm ci && npm run build"
fi
echo "✅ Surgery v3 imekamilika. Sasa: rm -rf .next && npm run build && npm start"
