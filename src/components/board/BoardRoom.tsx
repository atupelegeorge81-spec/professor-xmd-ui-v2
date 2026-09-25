"use client";
import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { BrainCircuit, CircleDashed, Clock, Coins, Link2, Loader2, Lock, X, ArrowDown, Circle } from "lucide-react";
import { AGENTS, getAgent, type AgentId } from "@/lib/agents";
import type { Source } from "@/lib/mock";
import { STAGE_AGENDA, STAGE_PROMPT } from "@/lib/stage/script";
import type { StageItem } from "@/lib/stage/types";
import { cn, compact, domainOf } from "@/lib/utils";
import { useApp } from "../shell/AppState";
import { AgentAvatar } from "../ui/AgentAvatar";
import { PromptComposer } from "../ui/PromptComposer";
import { BoardGraph } from "./BoardGraph";
import { StageStream } from "./stage/StageStream";
import { StageRail } from "./stage/StageRail";
import { usePlayback } from "./stage/usePlayback";

/* Board Room — stream ya matukio yote ya engine (angalia components/board/stage/*).
 * Modes: ?prompt=… (live) · ?session=… (historia, instant) · idle (BoardGraph). */

export function BoardRoom() {
  const params = useSearchParams();
  const router = useRouter();
  const { resetStatus, setBoardLive, status } = useApp();
  const { items, stage, phase, run, stop, reset } = usePlayback();
  const [panel, setPanel] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [atBottom, setAtBottom] = useState(true);
  const scrollRef = useRef<HTMLDivElement>(null);
  const follow = useRef(true);

  /* ---------------- external session details trigger ---------------- */
  useEffect(() => {
    const open = () => setPanel(true);
    window.addEventListener("xmd:open-session-details", open);
    return () => window.removeEventListener("xmd:open-session-details", open);
  }, []);

  /* ---------------- URL-driven modes ---------------- */
  const key = params.toString();
  useEffect(() => {
    const prompt = params.get("prompt");
    const session = params.get("session");
    const speed = Number(params.get("speed")) || 1;
    const hold = params.get("hold");
    follow.current = true;
    if (prompt) {
      setElapsed(0);
      const t = setTimeout(() => run(prompt, { speed, hold: hold ? Number(hold) : undefined, holdMs: Number(params.get("holdMs")) || 0 }), 60);
      return () => clearTimeout(t);
    }
    if (session) {
      run(STAGE_PROMPT, { instant: true });
      setElapsed(412);
      return;
    }
    reset();
    resetStatus();
    setBoardLive(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  useEffect(() => () => reset(), [reset]);
  useEffect(() => {
    if (phase !== "running" || params.get("session")) return;
    const t = setInterval(() => setElapsed((e) => e + 1), 1000);
    return () => clearInterval(t);
  }, [phase, params]);

  /* ---------------- smart autoscroll ---------------- */
  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    // acha kufuata TU mtumiaji akiskrolla mwenyewe (maudhui yanayokua haraka yasivunje follow)
    let intent = 0;
    const mark = () => { intent = Date.now(); };
    const onScroll = () => {
      const near = el.scrollHeight - el.scrollTop - el.clientHeight < 140;
      if (near) follow.current = true;
      else if (Date.now() - intent < 900) follow.current = false;
      setAtBottom(follow.current || near);
    };
    const opts = { passive: true } as const;
    el.addEventListener("scroll", onScroll, opts);
    el.addEventListener("wheel", mark, opts);
    el.addEventListener("touchmove", mark, opts);
    el.addEventListener("keydown", mark);
    el.addEventListener("pointerdown", mark, opts);
    return () => {
      el.removeEventListener("scroll", onScroll);
      el.removeEventListener("wheel", mark);
      el.removeEventListener("touchmove", mark);
      el.removeEventListener("keydown", mark);
      el.removeEventListener("pointerdown", mark);
    };
  }, [phase]);
  useEffect(() => {
    const el = scrollRef.current;
    if (el && follow.current && phase === "running" && !params.get("session")) el.scrollTop = el.scrollHeight;
  }, [items, phase, params]);

  /* ---------------- derived (panel) ---------------- */
  const seals = items.filter((i): i is Extract<StageItem, { kind: "seal" }> => i.kind === "seal");
  const supersedes = items.filter((i): i is Extract<StageItem, { kind: "supersede" }> => i.kind === "supersede");
  const locked = Object.values(stage.ledger).filter((l) => l.status !== "OPEN").length;
  const tokens = items.reduce((n, i) => n + (i.kind === "summary" ? i.usage.reduce((m, u) => m + u.tokens, 0) : 0), 0);
  const liveTokens = tokens || items.filter((i) => i.kind === "turn" || i.kind === "script").length * 3100;
  const sources = useMemo(() => {
    const m = new Map<string, Source & { agent: AgentId }>();
    items.forEach((i) => {
      const tr = i.kind === "evidence" ? i.trace : i.kind === "turn" ? i.search : undefined;
      if (tr && (i.kind === "evidence" || i.kind === "turn")) tr.sources.forEach((s) => m.set(s.url, { ...s, agent: i.agent }));
    });
    return [...m.values()];
  }, [items]);
  const memory = useMemo(() => {
    let saved = 0, none = 0;
    items.forEach((i) => { if (i.kind === "memory" && i.scope !== "consolidate") i.agents.forEach((g) => { if (g.state === "saved") saved++; if (g.state === "none") none++; }); });
    return { saved, none };
  }, [items]);
  const mmss = `${String(Math.floor(elapsed / 60)).padStart(2, "0")}:${String(elapsed % 60).padStart(2, "0")}`;
  const turnsOf = (id: AgentId) => items.filter((i) => i.kind === "turn" && i.agent === id).length;
  const running = phase === "running" && !params.get("session");

  /* ================= EMPTY STATE ================= */
  if (phase === "idle") {
    return (
      <div className="relative flex min-h-[calc(100dvh-56px)] flex-col items-center justify-center overflow-hidden px-4 pb-10 pt-8">
        <div className="grid-lines pointer-events-none absolute inset-0" />
        <BoardGraph className="relative mb-8 max-w-[720px] animate-[rise_0.6s_both]" />
        <PromptComposer autoFocus onSubmit={(t) => router.push(`/board?prompt=${encodeURIComponent(t)}`)} className="w-full max-w-[640px] animate-[rise_0.6s_0.15s_both]" />
      </div>
    );
  }

  /* ================= PANEL ================= */
  const PanelStats = (
    <div className="grid grid-cols-3 gap-2">
      {[
        { icon: Clock, label: "Elapsed", value: mmss },
        { icon: Lock, label: "Locked", value: `${locked}/${STAGE_AGENDA.length}` },
        { icon: Coins, label: "Tokens", value: compact(liveTokens) },
      ].map((s) => (
        <div key={s.label} className="surface rounded-xl p-2.5">
          <s.icon size={13} className="text-[var(--color-faint)]" />
          <p className="mt-1.5 font-mono text-[14px] font-semibold">{s.value}</p>
          <p className="text-[10.5px] text-[var(--color-faint)]">{s.label}</p>
        </div>
      ))}
    </div>
  );

  const PanelBody = (
    <div className="space-y-5">
      <section>
        <p className="eyebrow mb-2.5">Agenda</p>
        <ol className="space-y-1">
          {STAGE_AGENDA.map((a) => {
            const l = stage.ledger[a.index];
            const active = !l && stage.scope === "agenda" && stage.agenda?.index === a.index;
            const st = l?.status === "SUPERSEDED+LOCKED" ? { t: "SUPERSEDED → v2", c: "#c4b5fd", I: Link2 } : l?.status === "OPEN" ? { t: "OPEN", c: "var(--color-warn)", I: CircleDashed } : l ? { t: "LOCKED", c: "var(--color-ok)", I: Lock } : active ? { t: "inajadiliwa", c: "#a78bfa", I: Loader2 } : { t: "inasubiri", c: "var(--color-faint)", I: Circle };
            return (
              <li key={a.index} className={cn("flex items-center gap-2.5 rounded-xl px-2.5 py-2 text-[12.5px]", active && "bg-white/[0.04]")}>
                <st.I size={14} style={{ color: st.c }} className={cn(active && running && "anim-spin")} />
                <span className={cn("min-w-0 flex-1 truncate", !l && !active ? "text-[var(--color-muted)]" : "text-[var(--color-fg)]")}>{a.title}</span>
                <span className="shrink-0 font-mono text-[9.5px] font-semibold tracking-wide" style={{ color: st.c }}>{st.t}</span>
              </li>
            );
          })}
        </ol>
      </section>

      <section>
        <p className="eyebrow mb-2.5">Ledger</p>
        {seals.length === 0 ? (
          <p className="rounded-xl border border-dashed border-[var(--color-line)] px-3 py-3 text-center text-[11.5px] text-[var(--color-faint)]">Maamuzi yanaonekana hapa yakifungwa</p>
        ) : (
          <div className="space-y-1">
            {seals.map((s) => {
              const sup = supersedes.find((x) => x.agenda === s.agenda.index);
              return (
                <div key={s.id} className="rounded-xl border border-[var(--color-line)] bg-white/[0.015] px-2.5 py-2 text-[11.5px]">
                  <div className="flex items-center gap-2 font-mono text-[10.5px]">
                    <span className="text-[var(--color-muted)]">A{s.agenda.index}</span>
                    <span className={cn(s.superseded ? "text-[var(--color-faint)] line-through" : s.status === "OPEN" ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]")}>#{s.ledgerId}</span>
                    {sup && <><span className="text-[var(--color-faint)]">→</span><span className="text-[var(--color-ok)]">#{sup.to.ledgerId}</span></>}
                    <span className="ml-auto text-[var(--color-faint)]">{s.status === "OPEN" ? "OPEN" : sup ? "v2" : `v${s.version}`}</span>
                  </div>
                  <p className="mt-0.5 line-clamp-2 text-[var(--color-fg-2)]">{s.decision.replace(/[`*]/g, "")}</p>
                </div>
              );
            })}
          </div>
        )}
      </section>

      <section>
        <p className="eyebrow mb-2.5">At the table</p>
        <div className="space-y-1">
          {AGENTS.map((a) => {
            const s = status[a.id];
            const busy = running && (s === "thinking" || s === "speaking");
            return (
              <div key={a.id} className={cn("flex items-center gap-2.5 rounded-xl px-2 py-1.5 transition", busy && "bg-white/[0.04]")}>
                <AgentAvatar agent={a} size={28} status={busy ? s : "online"} />
                <div className="min-w-0 flex-1 leading-tight">
                  <p className="text-[12.5px] font-medium">{a.name}</p>
                  <p className="text-[10.5px]" style={{ color: busy ? a.accent : "var(--color-faint)" }}>
                    {busy ? (s === "thinking" ? "anafikiri / anatafuta…" : "anaongea…") : `zamu ${turnsOf(a.id)}`}
                  </p>
                </div>
                <span className="font-mono text-[10px]" style={{ color: a.accent }}>{a.chip}</span>
              </div>
            );
          })}
        </div>
      </section>

      <section>
        <p className="eyebrow mb-2.5">Background</p>
        <div className="space-y-1.5 rounded-xl border border-[var(--color-line)] bg-white/[0.015] p-2.5 text-[11.5px]">
          <p className={cn("flex items-center gap-2", stage.background && running ? "shimmer-text font-medium" : "text-[var(--color-faint)]")}>
            {!(stage.background && running) && <Circle size={10} />} {stage.background && running ? stage.background : "Hakuna kazi ya background sasa hivi"}
          </p>
          <p className="flex items-center gap-2 text-[var(--color-muted)]">
            <BrainCircuit size={12} className="text-[var(--color-prism-2)]" /> Memory: {memory.saved} zimehifadhiwa · {memory.none} NO_MEMORY
          </p>
          <p className="text-[10.5px] text-[var(--color-faint)]">Maudhui ya memory ni binafsi — hayaonyeshwi kwenye chat.</p>
        </div>
      </section>

      <section>
        <div className="mb-2.5 flex items-center justify-between">
          <p className="eyebrow">Evidence</p>
          <span className="font-mono text-[10.5px] text-[var(--color-faint)]">{sources.length}</span>
        </div>
        {sources.length === 0 ? (
          <p className="rounded-xl border border-dashed border-[var(--color-line)] px-3 py-4 text-center text-[11.5px] text-[var(--color-faint)]">Sources zinaonekana hapa agents wakitafiti</p>
        ) : (
          <div className="space-y-1.5">
            {sources.map((s, i) => (
              <a key={s.url} href={s.url} target="_blank" rel="noreferrer" className="flex items-start gap-2.5 rounded-xl border border-[var(--color-line)] bg-white/[0.015] p-2.5 transition hover:bg-white/[0.04] animate-[rise_0.4s_both]">
                <span className="grid h-[18px] w-[18px] shrink-0 place-items-center rounded-md bg-white/[0.07] font-mono text-[10px] text-[var(--color-fg-2)]">{i + 1}</span>
                <div className="min-w-0 flex-1">
                  <p className="line-clamp-1 text-[12px] font-medium text-[var(--color-fg-2)]">{s.title}</p>
                  <p className="text-[10.5px] text-[var(--color-faint)]">{domainOf(s.url)} · via {getAgent(s.agent)!.name}</p>
                </div>
              </a>
            ))}
          </div>
        )}
      </section>
    </div>
  );

  /* ================= SESSION ================= */
  return (
    <div className="flex h-[calc(100dvh-56px)] min-h-0">
      <div className="relative flex min-w-0 flex-1 flex-col">
        <div ref={scrollRef} className="min-h-0 flex-1 overflow-y-auto">
          <div className="mx-auto max-w-[860px] px-4 pb-10 sm:px-6">
            <StageRail stage={stage} live={running} />
            <div className="pt-5">
              <StageStream items={items} onResume={() => run(STAGE_PROMPT)} />
            </div>
          </div>
        </div>

        {!atBottom && (
          <button onClick={() => { const el = scrollRef.current; if (el) el.scrollTo({ top: el.scrollHeight, behavior: "smooth" }); }} className="glass absolute bottom-28 left-1/2 z-30 flex h-8 -translate-x-1/2 items-center gap-1.5 rounded-full px-3 text-[12px] text-[var(--color-fg-2)] shadow-lg">
            <ArrowDown size={13} /> Latest
          </button>
        )}

        <div className="shrink-0 px-3 pb-[max(12px,env(safe-area-inset-bottom))] pt-2 sm:px-6">
          <PromptComposer
            size="md"
            running={running}
            onStop={stop}
            onSubmit={(t) => router.push(`/board?prompt=${encodeURIComponent(t)}`)}
            placeholder={running ? "Interject as CEO — the board will pick it up next round…" : "Start a follow-up session…"}
            className="mx-auto max-w-[860px]"
          />
        </div>
      </div>

      <aside className="hidden w-[320px] shrink-0 overflow-y-auto border-l border-[var(--color-line)] bg-[rgb(12_14_19/0.5)] p-4 xl:block">
        <div className="space-y-5">{PanelStats}{PanelBody}</div>
      </aside>
      {panel && (
        <div className="fixed inset-0 z-[60] flex justify-end bg-black/50 xl:hidden" onClick={() => setPanel(false)}>
          <aside onClick={(e) => e.stopPropagation()} className="surface-solid anim-slide-right m-2 flex min-h-0 w-full max-w-[340px] flex-col overflow-hidden rounded-2xl">
            <div className="shrink-0 border-b border-[var(--color-line)] bg-[rgb(12_14_19/0.92)] p-4 backdrop-blur-xl">
              <div className="flex items-center justify-between">
                <p className="text-[14px] font-semibold">Session details</p>
                <button onClick={() => setPanel(false)} className="grid h-8 w-8 place-items-center rounded-lg text-[var(--color-muted)] hover:bg-white/5" aria-label="Close session details">
                  <X size={16} />
                </button>
              </div>
              <div className="mt-3">{PanelStats}</div>
            </div>
            <div className="min-h-0 flex-1 overflow-y-auto overscroll-contain p-4">{PanelBody}</div>
          </aside>
        </div>
      )}
    </div>
  );
}
