#!/usr/bin/env bash
# =============================================================================
# surgery-fix-v2.sh — Board Room v2: marekebisho mawili
#   1) Ujumbe wa agent (Pendekezo / Uamuzi uliosasishwa / Agree + Sharti /
#      Research request / Pingamizi limekataliwa / Mwenyekiti) — maandishi ya
#      kawaida yanayostream, HAKUNA kadi.
#   2) ScriptBox — upana wote wa safu, katikati ya viewport kwenye simu;
#      sheen ya hover ni kwa mouse tu (haibaki imekwama kwenye touch).
#
# Faili zinazoguswa (3 tu):
#   src/components/board/stage/Turn.tsx
#   src/components/board/stage/Code.tsx
#   src/components/board/stage/stage.css
#
# Matumizi (kutoka root ya repo professor-xmd-ui-v2):
#   bash surgery-fix-v2.sh
# Backup zinawekwa: <faili>.bak-<tarehe>. Kurudisha: bash surgery-fix-v2.sh --undo
# =============================================================================
set -euo pipefail

STAGE="src/components/board/stage"
FILES=("$STAGE/Turn.tsx" "$STAGE/Code.tsx" "$STAGE/stage.css")

if [[ ! -d "$STAGE" ]]; then
  echo "❌ Endesha script hii kutoka root ya repo (hakuna $STAGE)." >&2; exit 1
fi

if [[ "${1:-}" == "--undo" ]]; then
  for f in "${FILES[@]}"; do
    last=$(ls -1t "$f".bak-* 2>/dev/null | head -n1 || true)
    if [[ -n "$last" ]]; then cp "$last" "$f"; echo "↩️  $f ← $last"; else echo "⚠️  Hakuna backup ya $f"; fi
  done
  exit 0
fi

# Inahitaji toleo la stage lenye ScriptBox + ThinkTrace (ZIP iliyopita)
for need in "$STAGE/ScriptBox.tsx" "$STAGE/ThinkTrace.tsx" "$STAGE/kit.tsx"; do
  if [[ ! -f "$need" ]]; then
    echo "❌ $need haipo — weka kwanza ZIP ya v2 iliyopita (ScriptBox/ThinkTrace), kisha endesha tena." >&2; exit 1
  fi
done

TS=$(date +%Y%m%d-%H%M%S)
for f in "${FILES[@]}"; do
  [[ -f "$f" ]] && cp "$f" "$f.bak-$TS" && echo "🗂️  backup: $f.bak-$TS"
done

echo "✍️  src/components/board/stage/Turn.tsx"
cat > "src/components/board/stage/Turn.tsx" <<'XMD_SURGERY_EOF_0'
"use client";
import React, { useState } from "react";
import { ArrowUpRight, Check, Copy, GitBranch, Gavel, Handshake, Hourglass, Puzzle, RotateCcw, Undo2, Vote } from "lucide-react";
import type { AgentId } from "@/lib/agents";
import type { ChairItem, ConsensusItem, Signal, TurnItem } from "@/lib/stage/types";
import { cn } from "@/lib/utils";
import { AgentAvatar } from "../../ui/AgentAvatar";
import { Markdown } from "../../ui/Markdown";
import { SourceChips } from "../parts";
import { Inline, Lane, Spinner, TONE, Tag, ag, type Tone } from "./kit";
import { ThinkTrace } from "./ThinkTrace";

/* ============================================================== parser
 * Engine inatumia maneno maalum kwenye jibu la agent. Tunayageuza kuwa blocks. */
type Block =
  | { t: "p"; text: string }
  | { t: "signal"; sig: Signal; text: string }
  | { t: "proposal" | "updated"; decision: string; rationale?: string; tradeoff?: string; evidence?: string }
  | { t: "agree"; text: string }
  | { t: "research"; q: string }
  | { t: "rejected"; text: string };

const KEY = /^(PROPOSED DECISION|UPDATED DECISION|RATIONALE|TRADE-OFF|EVIDENCE|AGREE|RESEARCH_REQUEST|OBJECTION REJECTED|CLARIFY|OFF_TOPIC|CONTRADICTION|DISAGREE|INSUFFICIENT_EVIDENCE|I_WAS_WRONG|WAIT|SKILL_REQUEST):\s*(.*)$/;

export function parseTurn(src: string): Block[] {
  const out: Block[] = [];
  let para: string[] = [];
  const flush = () => { if (para.join("").trim()) out.push({ t: "p", text: para.join("\n").trim() }); para = []; };
  for (const line of src.split("\n")) {
    const m = line.match(KEY);
    if (!m) { if (!line.trim()) flush(); else para.push(line); continue; }
    flush();
    const [, k, v] = m;
    const last = out[out.length - 1];
    if (k === "PROPOSED DECISION") out.push({ t: "proposal", decision: v });
    else if (k === "UPDATED DECISION") out.push({ t: "updated", decision: v });
    else if (k === "RATIONALE" || k === "TRADE-OFF" || k === "EVIDENCE") {
      const f = k === "RATIONALE" ? "rationale" : k === "TRADE-OFF" ? "tradeoff" : "evidence";
      if (last && (last.t === "proposal" || last.t === "updated")) last[f] = v;
      else out.push({ t: "p", text: `**${k}:** ${v}` });
    } else if (k === "AGREE") out.push({ t: "agree", text: v });
    else if (k === "RESEARCH_REQUEST") out.push({ t: "research", q: v });
    else if (k === "OBJECTION REJECTED") out.push({ t: "rejected", text: v });
    else out.push({ t: "signal", sig: k as Signal, text: v });
  }
  flush();
  return out;
}

/* Judgment signals (brain parseSignals) — kila moja lina rangi na maana */
export const SIGNAL: Record<Signal, { label: string; tone: Tone }> = {
  CLARIFY: { label: "Clarify", tone: "sky" },
  OFF_TOPIC: { label: "Off topic", tone: "warn" },
  CONTRADICTION: { label: "Contradiction", tone: "bad" },
  DISAGREE: { label: "Disagree", tone: "bad" },
  INSUFFICIENT_EVIDENCE: { label: "Evidence haitoshi", tone: "warn" },
  I_WAS_WRONG: { label: "Nilikosea", tone: "violet" },
  WAIT: { label: "Subiri", tone: "warn" },
  SKILL_REQUEST: { label: "Skill request", tone: "violet" },
};

/* ============================================================== message
 * Muonekano wa BoardMessage ya v2: avatar + mstari, jina + role pill, ThinkingBlock, jibu, source chips. */
export function StageMessage({ it }: { it: TurnItem }) {
  const a = ag(it.agent);
  const live = it.phase !== "done";
  const blocks = parseTurn(it.content);
  const answering = it.phase === "answering";
  const [copied, setCopied] = useState(false);
  const sources = it.search?.sources ?? [];

  return (
    <article className="group relative flex animate-[rise_0.45s_both] gap-3 sm:gap-4">
      <div className="flex flex-col items-center">
        <AgentAvatar agent={a} size={36} status={live ? "speaking" : undefined} />
        <span className="mt-2 w-px flex-1 bg-gradient-to-b from-[var(--color-line-strong)] to-transparent" />
      </div>
      <div className="min-w-0 flex-1 pb-2">
        <header className="mb-1.5 flex flex-wrap items-center gap-x-2 gap-y-1">
          <span className="text-[14px] font-semibold">{a.name}</span>
          <span className="rounded-md px-1.5 py-0.5 text-[10.5px] font-medium" style={{ color: a.accent, background: `rgb(${a.rgb} / 0.1)` }}>{a.role}</span>
          {it.role === "responder" && <Tag tone="bad">jibu la pingamizi</Tag>}
          {it.skill && (
            <Tag tone={it.skill.found ? "violet" : "warn"}>
              <Puzzle size={10.5} /> {it.skill.name} · {it.skill.found ? "loaded" : "haipo"}
            </Tag>
          )}
          {live && it.phase !== "retrying" && (
            <span className="flex items-center gap-1.5 text-[11px]" style={{ color: a.accent }}>
              <span className="typing-dots flex gap-0.5"><span /><span /><span /></span>
            </span>
          )}
        </header>

        {(it.thinking.length > 0 || it.search) && <ThinkTrace turn={it} accent={a.accent} />}

        {it.phase === "retrying" && it.retry && (
          <div className="mb-3 flex items-center gap-2.5 rounded-xl border border-[rgb(251_191_36/0.22)] bg-[rgb(251_191_36/0.06)] px-3 py-2 text-[12.5px] text-[var(--color-fg-2)] animate-[rise_0.3s_both]">
            <Spinner size={12} color={TONE.warn.c} />
            <span className="shimmer-text font-medium">Jibu tupu/limekatika — retry {it.retry.n}/{it.retry.max}</span>
            <span className="ml-auto truncate font-mono text-[10.5px] text-[var(--color-muted)]">{it.retry.model}</span>
          </div>
        )}

        {(answering || it.phase === "done") && (
          <>
            <div className="space-y-2.5">
              {blocks.map((b, i) => (
                <BlockView key={i} b={b} agent={it.agent} caret={answering && i === blocks.length - 1} />
              ))}
            </div>
            {it.phase === "done" && sources.length > 0 && <div className="mt-3"><SourceChips sources={sources} /></div>}
            {it.phase === "done" && (
              <div className="mt-2 flex items-center gap-0.5 opacity-100 transition sm:opacity-0 sm:group-hover:opacity-100">
                <button onClick={() => { navigator.clipboard?.writeText(it.content); setCopied(true); setTimeout(() => setCopied(false), 1200); }} className="grid h-7 w-7 place-items-center rounded-md text-[var(--color-faint)] hover:bg-white/5 hover:text-[var(--color-fg)]" aria-label="Copy">
                  {copied ? <Check size={13} /> : <Copy size={13} />}
                </button>
              </div>
            )}
          </>
        )}
      </div>
    </article>
  );
}

function BlockView({ b, agent, caret }: { b: Block; agent: AgentId; caret: boolean }) {
  const a = ag(agent);
  const c = caret ? "caret" : "";
  switch (b.t) {
    case "p":
      return <div className={cn(caret && "[&_.prose-xmd>*:last-child]:caret")}><Markdown text={b.text} accent={a.accent} /></div>;
    case "signal": {
      const s = SIGNAL[b.sig];
      return (
        <div className="flex flex-wrap items-start gap-2">
          <Tag tone={s.tone} className="mt-[2px] uppercase">{s.label}</Tag>
          <p className={cn("min-w-0 flex-1 text-[14px] leading-6 text-[var(--color-fg-2)]", c)}><Inline text={b.text} accent={a.accent} /></p>
        </div>
      );
    }
    case "proposal":
    case "updated": {
      // maandishi ya kawaida (si kadi): lebo ndogo ya rangi + aya za kawaida zinazostream
      const upd = b.t === "updated";
      const col = upd ? TONE.violet.c : a.accent;
      const fields = ([["Sababu", b.rationale], ["Trade-off", b.tradeoff], ["Evidence", b.evidence]] as const).filter(([, v]) => v);
      return (
        <div className="space-y-1.5">
          <Label color={col} icon={upd ? <GitBranch size={12} /> : <Vote size={12} />}>{upd ? "Uamuzi uliosasishwa" : "Pendekezo"}</Label>
          <p className={cn("text-[15px] font-medium leading-7 text-[var(--color-fg)]", !fields.length && c)}><Inline text={b.decision} accent={col} /></p>
          {fields.map(([k, v], i) => (
            <p key={k} className={cn("text-[14px] leading-6 text-[var(--color-fg-2)]", i === fields.length - 1 && c)}>
              <span className="font-semibold text-[var(--color-fg)]">{k}:</span> <Inline text={v!} accent={col} />
            </p>
          ))}
        </div>
      );
    }
    case "agree": {
      const [head, cond] = splitCondition(b.text);
      return (
        <div className="space-y-1.5">
          <Label color={TONE.ok.c} icon={<Check size={12} strokeWidth={3} />}>Agree</Label>
          <p className={cn("text-[14px] leading-6 text-[var(--color-fg-2)]", !cond && c)}><Inline text={head} /></p>
          {cond && (
            <p className={cn("text-[14px] leading-6 text-[var(--color-fg-2)]", c)}>
              <span className="font-semibold text-[var(--color-ok)]">Sharti:</span> <span className="text-[var(--color-fg)]"><Inline text={cond} /></span>
            </p>
          )}
        </div>
      );
    }
    case "research":
      return (
        <p className={cn("text-[14px] leading-6 text-[var(--color-fg-2)]", c)}>
          <span className="mr-1.5 inline-flex translate-y-[1px] items-center gap-1 font-semibold" style={{ color: TONE.violet.c }}><ArrowUpRight size={13} /> Research request:</span>
          <code className="rounded-md bg-white/[0.06] px-1.5 py-[1px] font-mono text-[12.5px] text-[var(--color-fg)]">{b.q}</code>
        </p>
      );
    case "rejected":
      return (
        <div className="space-y-1.5">
          <Label color="#7dd3fc" icon={<Undo2 size={12} />}>Pingamizi limekataliwa</Label>
          <p className={cn("text-[14px] leading-6 text-[var(--color-fg-2)]", c)}><Inline text={b.text} accent="#7dd3fc" /></p>
        </div>
      );
  }
}

/** Lebo ndogo ya rangi juu ya aya (badala ya kadi) */
function Label({ color, icon, children }: { color: string; icon: React.ReactNode; children: React.ReactNode }) {
  return (
    <p className="flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-[0.14em]" style={{ color }}>
      {icon} {children}
    </p>
  );
}

function splitCondition(t: string): [string, string | undefined] {
  // engine: "AGREE … [Condition added by X] …"
  const c = t.match(/^(.*?)\s*\[Condition added by [^\]]+\]\s*(.+)$/i);
  if (c) return [c[1].trim() || "Nakubali", c[2]];
  const m = t.match(/^(.*?)[—,-]?\s*kwa sharti( kwamba)?:?\s*(.+)$/i);
  if (!m) return [t, undefined];
  return [m[1].trim().replace(/[—,-]$/, "").trim() || "Nakubali", m[3]];
}

/* ============================================================== consensus
 * engine: proposal parser · approvals Set (reset kwa proposal mpya) · consensus gate · MAX_TURNS */
export function ConsensusTick({ it }: { it: ConsensusItem }) {
  const by = ag(it.by);
  const total = it.owners.length;
  const n = it.approvals.length;
  const tone: Tone = it.event === "reached" ? "ok" : it.event === "exhausted" ? "warn" : it.event === "reset" ? "violet" : "blue";
  const t = TONE[tone];
  const text = {
    proposed: <>Pendekezo <b>v{it.version}</b> la {by.name} liko mezani</>,
    reset: <>{by.name} ameleta <b>v{it.version}</b> — kura za zamani zimefutwa</>,
    agreed: <>{by.name} amekubali</>,
    reached: <>Consensus <b>{n}/{total}</b> — v{it.version} imekubaliwa</>,
    exhausted: <>Zamu zimeisha bila consensus — <b>{n}/{total}</b></>,
  }[it.event];
  const Icon = it.event === "reached" ? Handshake : it.event === "exhausted" ? Hourglass : it.event === "reset" ? RotateCcw : Vote;
  return (
    <Lane>
      <div className="flex items-center gap-2.5 rounded-xl border px-3 py-2 text-[12.5px]" style={{ borderColor: `rgb(${t.rgb} / 0.16)`, background: `rgb(${t.rgb} / 0.04)` }}>
        <Icon size={14} style={{ color: t.c }} className="shrink-0" />
        <span className="min-w-0 flex-1 text-[var(--color-muted)] [&_b]:font-semibold [&_b]:text-[var(--color-fg)]">{text}</span>
        <span className="flex shrink-0 items-center gap-1">
          {it.owners.map((o) => {
            const yes = it.approvals.includes(o);
            const g = ag(o);
            return (
              <span key={o} className={cn("relative transition-opacity duration-500", yes ? "opacity-100" : "opacity-35 grayscale")} title={`${g.name}: ${yes ? "amekubali" : "bado"}`}>
                <AgentAvatar agent={g} size={20} ring={false} />
                {yes && <span className="absolute -bottom-1 -right-1 grid h-3 w-3 place-items-center rounded-full bg-[var(--color-ok)] text-black"><Check size={8} strokeWidth={4} /></span>}
              </span>
            );
          })}
          <span className="ml-1.5 font-mono text-[11px] font-semibold" style={{ color: t.c }}>{n}/{total}</span>
        </span>
      </div>
    </Lane>
  );
}

/* ============================================================== chair challenge
 * brain: chairReview → Optimus anaingilia kati kama mwenyekiti (≤2 kwa agenda) */
export function ChairCard({ it }: { it: ChairItem }) {
  const o = ag("optimus");
  const t = ag(it.target);
  const s = SIGNAL[it.reason];
  const typing = it.shown < it.text.length;
  return (
    <article className="relative flex animate-[rise_0.45s_both] gap-3 sm:gap-4">
      <div className="flex flex-col items-center">
        <AgentAvatar agent={o} size={36} status={typing ? "speaking" : undefined} />
        <span className="mt-2 w-px flex-1 bg-gradient-to-b from-[var(--color-line-strong)] to-transparent" />
      </div>
      <div className="min-w-0 flex-1 pb-2">
        <header className="mb-1.5 flex flex-wrap items-center gap-x-2 gap-y-1">
          <span className="text-[14px] font-semibold">{o.name}</span>
          <span className="inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 text-[10.5px] font-medium" style={{ color: o.accent, background: `rgb(${o.rgb} / 0.1)` }}><Gavel size={10.5} /> Mwenyekiti</span>
          <span className="inline-flex items-center gap-1.5 text-[12px] text-[var(--color-muted)]">→ <AgentAvatar agent={t} size={16} ring={false} /><span className="font-medium text-[var(--color-fg-2)]">{t.name}</span></span>
          <Tag tone={s.tone} className="uppercase">{s.label}</Tag>
        </header>
        <p className={cn("text-[14px] leading-6 text-[var(--color-fg)]", typing && it.shown > 0 && "caret")}>
          {it.shown === 0 ? <span className="shimmer-text text-[13px] font-medium">Optimus anapima mwenendo wa mjadala…</span> : <Inline text={it.text.slice(0, it.shown)} accent={o.accent} />}
        </p>
      </div>
    </article>
  );
}
XMD_SURGERY_EOF_0

echo "✍️  src/components/board/stage/Code.tsx"
cat > "src/components/board/stage/Code.tsx" <<'XMD_SURGERY_EOF_1'
"use client";
import { useState } from "react";
import { Check, ChevronDown, CircleDashed, FileCode2, Layers, PackageCheck, ShieldCheck, ShieldX, X } from "lucide-react";
import type { AssemblyItem, DeliverableItem, ReviewItem, ScriptItem } from "@/lib/stage/types";
import { cn } from "@/lib/utils";
import { AgentAvatar } from "../../ui/AgentAvatar";
import { Card, Lane, Spinner, TONE, Tag, ag } from "./kit";
import { ScriptBox } from "./ScriptBox";

/* ============================================================== script (writer message)
 * engine: code-writing streamTurn (≤3 continuations) · script_diff (surgical patch) · dissolveMessage */
export function ScriptCard({ it }: { it: ScriptItem }) {
  const a = ag(it.agent);
  const [openOld, setOpenOld] = useState(false);

  if (it.replaced) {
    // toleo la zamani — limebaki kama mstari mfupi (company: dissolveMessage → "↕️ Script ilisasishwa")
    return (
      <Lane>
        <button onClick={() => setOpenOld((v) => !v)} className="flex w-full items-center gap-2.5 rounded-xl border border-[var(--color-line)] bg-white/[0.02] px-3 py-2 text-left text-[12px] text-[var(--color-muted)] transition hover:bg-white/[0.04]">
          <FileCode2 size={13} style={{ color: a.accent }} className="shrink-0" />
          <span className="font-mono text-[11.5px] text-[var(--color-fg-2)] line-through decoration-[var(--color-faint)]">{it.file}</span>
          <Tag tone="muted" mono>v{it.version}</Tag>
          <span className="min-w-0 flex-1 truncate">Script ilisasishwa → v{it.version + 1}</span>
          <span className="font-mono text-[11px]"><span className="text-[var(--color-ok)]">+{it.replaced.add}</span> <span className="text-[var(--color-bad)]">−{it.replaced.del}</span></span>
          <ChevronDown size={13} className={cn("shrink-0 transition", openOld && "rotate-180")} />
        </button>
        {openOld && (
          <div className="mt-2 opacity-70">
            <ScriptBox title={it.file} lang={it.lang} code={it.code} accent={a.accent} version={it.version} />
          </div>
        )}
      </Lane>
    );
  }

  const writing = it.state === "writing";
  const patchLabel = it.patch ? (it.patch.reason === "review" ? "marekebisho ya review" : "jibu la pingamizi") : undefined;
  // Header (avatar + jina) juu; ScriptBox chini kwa upana wote wa safu — katikati ya viewport kwenye simu
  return (
    <article className="relative animate-[rise_0.45s_both]">
      <header className="mb-2.5 flex items-center gap-3 sm:gap-4">
        <AgentAvatar agent={a} size={36} status={it.state !== "done" ? "speaking" : undefined} />
        <div className="flex min-w-0 flex-1 flex-wrap items-center gap-x-2 gap-y-0.5">
          <span className="text-[14px] font-semibold">{a.name}</span>
          <span className="rounded-md px-1.5 py-0.5 text-[10.5px] font-medium" style={{ color: a.accent, background: `rgb(${a.rgb} / 0.1)` }}>{a.role}</span>
          <span className="w-full text-[12px] text-[var(--color-muted)] sm:w-auto">
            {it.patch ? <>surgical patch · {patchLabel}</> : writing || it.state === "resume" ? <>anaandika <span className="font-mono text-[11.5px] text-[var(--color-fg-2)]">{it.file}</span></> : <>ameandika <span className="font-mono text-[11.5px] text-[var(--color-fg-2)]">{it.file}</span></>}
          </span>
        </div>
      </header>
      <div className="sm:ml-[52px]">
        <ScriptBox
          title={it.file}
          lang={it.lang}
          code={it.code}
          shown={it.shown}
          accent={a.accent}
          writing={writing}
          resume={it.state === "resume"}
          patching={it.state === "patching"}
          attempt={it.attempt}
          maxAttempts={it.maxAttempts}
          version={it.version}
          patch={it.patch && { ...it.patch, label: patchLabel }}
        />
      </div>
    </article>
  );
}

/* ============================================================== review
 * engine: reviewer APPROVE / REJECT: … (round ≤2) */
export function ReviewCard({ it }: { it: ReviewItem }) {
  const pending = it.verdict === "pending";
  const ok = it.verdict === "approve";
  return (
    <Lane>
      <Card
        tone={pending ? "sky" : ok ? "ok" : "bad"}
        icon={pending ? <Spinner size={14} color={TONE.sky.c} /> : ok ? <ShieldCheck size={15} /> : <ShieldX size={15} />}
        eyebrow={<>Code review · {ag(it.agent).name}</>}
        right={<Tag tone="muted" mono>round {it.round}/{it.maxRounds}</Tag>}
        title={pending ? <span className="shimmer-text">Anakagua script dhidi ya maamuzi ya agenda…</span> : ok ? "APPROVE — script zimekubaliwa" : "REJECT — inahitaji marekebisho"}
      >
        {!pending && it.notes.length > 0 && (
          <ul className="mt-2 space-y-1.5">
            {it.notes.map((n, i) => (
              <li key={i} className="flex gap-2 text-[12.5px] leading-5 text-[var(--color-fg-2)] animate-[rise_0.35s_both]" style={{ animationDelay: `${i * 80}ms` }}>
                <X size={13} className="mt-[3px] shrink-0 text-[var(--color-bad)]" /> {n}
              </li>
            ))}
          </ul>
        )}
      </Card>
    </Lane>
  );
}

/* ============================================================== deliverable
 * engine: "Deliverable ya mwisho — item" */
export function DeliverableCard({ it }: { it: DeliverableItem }) {
  const a = ag(it.agent);
  return (
    <Lane>
      <div className="flex items-center gap-2.5 rounded-xl border border-[rgb(52_211_153/0.18)] bg-[rgb(52_211_153/0.05)] px-3 py-2 text-[12.5px]">
        <PackageCheck size={14} className="shrink-0 text-[var(--color-ok)]" />
        <span className="text-[10.5px] font-semibold uppercase tracking-[0.12em] text-[var(--color-ok)]">Deliverable</span>
        <span className="truncate font-mono text-[12px] text-[var(--color-fg)]">{it.file}</span>
        <span className="hidden truncate text-[var(--color-muted)] sm:inline">· {it.agenda}</span>
        <span className="ml-auto flex shrink-0 items-center gap-2 text-[11px] text-[var(--color-muted)]">
          {it.lines} lines <AgentAvatar agent={a} size={18} ring={false} />
        </span>
      </div>
    </Lane>
  );
}

/* ============================================================== assembly
 * engine: HATUA 6.5 assembleFinalScript (collectLockedPieces → stream ≤6) */
export function AssemblyCard({ it }: { it: AssemblyItem }) {
  const o = ag("optimus");
  const merging = it.merged < it.pieces.length;
  const writing = !merging && !it.done;
  return (
    <Lane className="space-y-3">
      <Card
        tone="violet"
        icon={merging ? <Spinner size={14} color={TONE.violet.c} /> : <Layers size={15} />}
        eyebrow="Script ya mwisho · Optimus"
        right={<Tag tone="violet" mono>{it.merged}/{it.pieces.length} vipande</Tag>}
        title={merging ? <span className="shimmer-text">Anakusanya vipande vilivyofungwa kwenye Ledger…</span> : it.done ? "Vipande vyote vimeunganishwa kuwa script moja" : "Anaunganisha kuwa script moja…"}
      >
        <div className="mt-2.5 flex flex-wrap gap-1.5">
          {it.pieces.map((p, i) => {
            const done = i < it.merged;
            const cur = i === it.merged && merging;
            return (
              <span key={i} className={cn("inline-flex h-7 items-center gap-1.5 rounded-lg border px-2 text-[11.5px] transition-opacity duration-300", done ? "border-[rgb(52_211_153/0.25)] bg-[rgb(52_211_153/0.06)] text-[var(--color-fg-2)]" : "border-[var(--color-line)] text-[var(--color-muted)]", !done && !cur && "opacity-60")}>
                {done ? <Check size={12} className="text-[var(--color-ok)]" /> : cur ? <Spinner size={10} color={TONE.violet.c} /> : <CircleDashed size={11} />}
                <AgentAvatar agent={ag(p.agent)} size={14} ring={false} />
                <span className="font-mono">{p.file}</span>
                <span className="text-[var(--color-faint)]">A{p.agenda}</span>
              </span>
            );
          })}
        </div>
      </Card>
      {!merging && (
        <ScriptBox
          title={it.file}
          lang="typescript"
          code={it.code}
          shown={it.shown}
          accent={o.accent}
          writing={writing}
          attempt={it.attempt}
          maxAttempts={it.maxAttempts}
          who={<><AgentAvatar agent={o} size={16} ring={false} /> Optimus</>}
        />
      )}
    </Lane>
  );
}
XMD_SURGERY_EOF_1

echo "✍️  src/components/board/stage/stage.css"
cat > "src/components/board/stage/stage.css" <<'XMD_SURGERY_EOF_2'
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
XMD_SURGERY_EOF_2

echo ""
echo "✅ Marekebisho yamewekwa."
if [[ -x node_modules/.bin/tsc ]]; then
  echo "🔎 tsc --noEmit…"
  node_modules/.bin/tsc --noEmit -p . && echo "✅ tsc imepita"
else
  echo "ℹ️  node_modules haipo — endesha: npm ci && npx tsc --noEmit"
fi
echo "▶️  Kisha: npm run build && npx next start -H 0.0.0.0 -p 3000   (au npm run dev)"
