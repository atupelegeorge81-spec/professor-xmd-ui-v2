"use client";
import { useState } from "react";
import { Brain, ChevronDown, Check, Copy, ThumbsUp, ThumbsDown, Search } from "lucide-react";
import { getAgent, type AgentId } from "@/lib/agents";
import type { Source } from "@/lib/mock";
import { cn, domainOf } from "@/lib/utils";
import { AgentAvatar } from "../ui/AgentAvatar";
import { Markdown } from "../ui/Markdown";

export type Phase = "thinking" | "searching" | "answering" | "done";

export interface LiveTurn {
  kind: "turn";
  id: string;
  agent: AgentId;
  thinking: string[];
  thinkShown: number;
  search?: string;
  sources: Source[];
  content: string;
  phase: Phase;
  seconds: number;
}

/* ------------------------------ Source chips ------------------------------ */
export function Favicon({ url, size = 16 }: { url: string; size?: number }) {
  const d = domainOf(url);
  const hue = [...d].reduce((h, c) => (h * 31 + c.charCodeAt(0)) % 360, 7);
  return (
    <span className="grid shrink-0 place-items-center rounded-[5px] font-mono font-bold uppercase text-white" style={{ width: size, height: size, fontSize: size * 0.55, background: `oklch(0.55 0.14 ${hue})` }}>
      {d[0]}
    </span>
  );
}

export function SourceChips({ sources }: { sources: Source[] }) {
  const [open, setOpen] = useState(false);
  const shown = open ? sources : sources.slice(0, 3);
  return (
    <div className="flex flex-wrap gap-1.5">
      {shown.map((s, i) => (
        <a key={s.url} href={s.url} target="_blank" rel="noreferrer" title={s.title} className="group flex h-7 max-w-[220px] items-center gap-1.5 rounded-lg border border-[var(--color-line)] bg-white/[0.025] pl-1.5 pr-2 text-[11.5px] text-[var(--color-fg-2)] transition hover:border-white/15 hover:bg-white/[0.05] animate-[rise_0.4s_both]" style={{ animationDelay: `${i * 60}ms` }}>
          <Favicon url={s.url} />
          <span className="truncate">{domainOf(s.url)}</span>
          <span className="font-mono text-[10px] text-[var(--color-faint)]">{i + 1}</span>
        </a>
      ))}
      {sources.length > 3 && !open && (
        <button onClick={() => setOpen(true)} className="flex h-7 items-center gap-1 rounded-lg border border-dashed border-[var(--color-line-strong)] px-2 text-[11.5px] text-[var(--color-muted)] hover:text-[var(--color-fg)]">
          +{sources.length - 3} more
        </button>
      )}
    </div>
  );
}

/* ------------------------------ Thinking block ------------------------------ */
function ThinkingBlock({ turn, accent }: { turn: LiveTurn; accent: string }) {
  const live = turn.phase === "thinking" || turn.phase === "searching";
  const [manual, setManual] = useState<boolean | null>(null);
  const open = manual ?? live;
  const steps = turn.thinking.slice(0, turn.thinkShown);

  return (
    <div className="mb-3">
      <button onClick={() => setManual(!open)} className="group flex items-center gap-2 rounded-lg py-1 text-[12.5px]">
        <Brain size={14} style={{ color: accent }} className={live ? "animate-pulse" : ""} />
        {live ? (
          <span className="shimmer-text font-medium">{turn.phase === "searching" ? "Searching for evidence…" : "Thinking…"}</span>
        ) : (
          <span className="font-medium text-[var(--color-muted)] group-hover:text-[var(--color-fg-2)]">Thought for {turn.seconds}s{turn.sources.length ? ` · ${turn.sources.length} sources` : ""}</span>
        )}
        <ChevronDown size={13} className={cn("text-[var(--color-faint)] transition", open && "rotate-180")} />
      </button>
      <div className={cn("grid transition-all duration-300", open ? "grid-rows-[1fr] opacity-100" : "grid-rows-[0fr] opacity-0")}>
        <div className="overflow-hidden">
          <ol className="relative ml-[6px] mt-1.5 space-y-2.5 border-l border-[var(--color-line-strong)] pb-1 pl-4">
            {steps.map((t, i) => (
              <li key={i} className="relative text-[12.5px] leading-5 text-[var(--color-muted)] animate-[rise_0.35s_both]">
                <span className="absolute -left-[21px] top-[7px] h-[7px] w-[7px] rounded-full border border-[var(--color-ink-1)]" style={{ background: i === steps.length - 1 && live ? accent : "var(--color-faint)" }} />
                {t}
              </li>
            ))}
            {turn.search && (turn.phase !== "thinking" || turn.sources.length > 0) && (
              <li className="relative animate-[rise_0.35s_both]">
                <span className="absolute -left-[21px] top-[7px] h-[7px] w-[7px] rounded-full" style={{ background: turn.phase === "searching" ? accent : "var(--color-ok)" }} />
                <div className="flex items-center gap-2 text-[12.5px] text-[var(--color-fg-2)]">
                  {turn.phase === "searching" ? <Search size={13} className="animate-pulse" /> : <Check size={13} className="text-[var(--color-ok)]" />}
                  <span className="text-[var(--color-muted)]">Searched</span>
                  <span className="truncate rounded-md bg-white/[0.05] px-1.5 py-0.5 font-mono text-[11px]">{turn.search}</span>
                </div>
                {turn.sources.length > 0 && (
                  <div className="mt-2 space-y-1">
                    {turn.sources.map((s) => (
                      <div key={s.url} className="flex items-center gap-2 text-[11.5px] text-[var(--color-muted)]">
                        <Favicon url={s.url} size={14} />
                        <span className="truncate">{s.title}</span>
                        <span className="shrink-0 text-[var(--color-faint)]">{domainOf(s.url)}</span>
                      </div>
                    ))}
                  </div>
                )}
              </li>
            )}
          </ol>
        </div>
      </div>
    </div>
  );
}

/* ------------------------------ Agent message ------------------------------ */
export function BoardMessage({ turn }: { turn: LiveTurn }) {
  const agent = getAgent(turn.agent)!;
  const [copied, setCopied] = useState(false);
  const speaking = turn.phase !== "done";
  return (
    <article className="group relative flex gap-3 animate-[rise_0.45s_both] sm:gap-4">
      <div className="flex flex-col items-center">
        <AgentAvatar agent={agent} size={36} status={speaking ? "speaking" : undefined} />
        <span className="mt-2 w-px flex-1 bg-gradient-to-b from-[var(--color-line-strong)] to-transparent" />
      </div>
      <div className="min-w-0 flex-1 pb-2">
        <header className="mb-1.5 flex flex-wrap items-center gap-x-2 gap-y-1">
          <span className="text-[14px] font-semibold">{agent.name}</span>
          <span className="rounded-md px-1.5 py-0.5 text-[10.5px] font-medium" style={{ color: agent.accent, background: `rgb(${agent.rgb} / 0.1)` }}>{agent.role}</span>
          {speaking && (
            <span className="flex items-center gap-1.5 text-[11px]" style={{ color: agent.accent }}>
              <span className="typing-dots flex gap-0.5"><span /><span /><span /></span>
            </span>
          )}
        </header>

        {turn.thinking.length > 0 && <ThinkingBlock turn={turn} accent={agent.accent} />}

        {(turn.phase === "answering" || turn.phase === "done") && (
          <>
            <div className={cn(turn.phase === "answering" && "[&_.prose-xmd>*:last-child]:caret")}>
              <Markdown text={turn.content} accent={agent.accent} />
            </div>
            {turn.phase === "done" && turn.sources.length > 0 && (
              <div className="mt-3"><SourceChips sources={turn.sources} /></div>
            )}
            {turn.phase === "done" && (
              <div className="mt-2 flex items-center gap-0.5 opacity-100 transition sm:opacity-0 sm:group-hover:opacity-100">
                <button onClick={() => { navigator.clipboard?.writeText(turn.content); setCopied(true); setTimeout(() => setCopied(false), 1200); }} className="grid h-7 w-7 place-items-center rounded-md text-[var(--color-faint)] hover:bg-white/5 hover:text-[var(--color-fg)]" aria-label="Copy">
                  {copied ? <Check size={13} /> : <Copy size={13} />}
                </button>
                <button className="grid h-7 w-7 place-items-center rounded-md text-[var(--color-faint)] hover:bg-white/5 hover:text-[var(--color-fg)]" aria-label="Good"><ThumbsUp size={13} /></button>
                <button className="grid h-7 w-7 place-items-center rounded-md text-[var(--color-faint)] hover:bg-white/5 hover:text-[var(--color-fg)]" aria-label="Bad"><ThumbsDown size={13} /></button>
              </div>
            )}
          </>
        )}
      </div>
    </article>
  );
}

/* ------------------------------ User prompt ------------------------------ */
export function UserPrompt({ text }: { text: string }) {
  return (
    <div className="flex justify-end animate-[rise_0.4s_both]">
      <div className="max-w-[85%]">
        <p className="mb-1 text-right text-[11px] text-[var(--color-faint)]">Mkuu · CEO</p>
        <div className="rounded-2xl rounded-tr-md border border-white/10 bg-white/[0.06] px-4 py-3 text-[14px] leading-6 text-[var(--color-fg)]">{text}</div>
      </div>
    </div>
  );
}

