"use client";
import Link from "next/link";
import { use, useEffect, useRef, useState } from "react";
import { notFound } from "next/navigation";
import { ArrowLeft, Cpu, Sparkles, Trash2 } from "lucide-react";
import { AGENTS, getAgent, type Agent } from "@/lib/agents";
import { useApp } from "@/components/shell/AppState";
import { AgentAvatar } from "@/components/ui/AgentAvatar";
import { PromptComposer } from "@/components/ui/PromptComposer";
import { BoardMessage, UserPrompt, type LiveTurn } from "@/components/board/parts";
import { sleep } from "@/lib/utils";

type Msg = { kind: "user"; id: string; text: string } | LiveTurn;

function reply(agent: Agent, q: string): Omit<LiveTurn, "id" | "phase" | "thinkShown"> {
  return {
    kind: "turn",
    agent: agent.id,
    seconds: 3 + Math.round(Math.random() * 4),
    thinking: [
      `Mkuu is asking: “${q.slice(0, 80)}${q.length > 80 ? "…" : ""}”`,
      `Framing this from a ${agent.role.toLowerCase()} perspective and checking what is current.`,
    ],
    search: `${q.split(" ").slice(0, 6).join(" ")} best practices 2026`,
    sources: [
      { title: "Official documentation", url: "https://developer.mozilla.org/docs/Web" },
      { title: "Engineering blog — field notes", url: "https://web.dev/articles" },
    ],
    content: `Mkuu, here is my take as your **${agent.role}**:\n\n- **Start narrow** — solve one painful job end-to-end before adding scope\n- **Verify with evidence** — I checked current guidance [1] and real-world notes [2]\n- **Decide explicitly** — write down what we are *not* doing yet\n\nIf you want, I can bring this to the Board Room so the other owners can challenge it before we lock anything.`,
  };
}

export default function AgentRoom({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const agent = getAgent(id);
  const { setStatus, bumpUsage, addLog } = useApp();
  const [msgs, setMsgs] = useState<Msg[]>([]);
  const [busy, setBusy] = useState(false);
  const scroll = useRef<HTMLDivElement>(null);
  const abort = useRef(false);

  useEffect(() => { scroll.current?.scrollTo({ top: scroll.current.scrollHeight }); }, [msgs]);
  useEffect(() => () => { abort.current = true; }, []);
  if (!agent) return notFound();

  const send = async (q: string) => {
    abort.current = false;
    setBusy(true);
    const tid = Math.random().toString(36).slice(2);
    const r = reply(agent, q);
    setMsgs((m) => [...m, { kind: "user", id: `u${tid}`, text: q }, { ...r, id: tid, phase: "thinking", thinkShown: 0, sources: [], content: "" }]);
    const patch = (p: Partial<LiveTurn>) => setMsgs((m) => m.map((x) => (x.id === tid ? ({ ...x, ...p } as Msg) : x)));
    setStatus(agent.id, "thinking");
    for (let k = 1; k <= r.thinking.length; k++) { await sleep(600); if (abort.current) return; patch({ thinkShown: k }); }
    patch({ phase: "searching" });
    addLog("search", `${agent.name} searched “${r.search}”`);
    await sleep(1000);
    patch({ sources: r.sources });
    await sleep(400);
    setStatus(agent.id, "speaking");
    patch({ phase: "answering" });
    const words = r.content.split(/(\s+)/);
    let acc = "";
    for (let w = 0; w < words.length; w += 3) { if (abort.current) return; acc += words.slice(w, w + 3).join(""); patch({ content: acc }); await sleep(24); }
    patch({ content: r.content, phase: "done" });
    setStatus(agent.id, "online");
    bumpUsage(agent.id, 900);
    setBusy(false);
  };

  const stop = () => {
    abort.current = true;
    setMsgs((m) => m.map((x) => (x.kind === "turn" && x.phase !== "done" ? { ...x, phase: "done", thinkShown: x.thinking.length } : x)));
    setStatus(agent.id, "online");
    setBusy(false);
  };

  return (
    <div className="flex h-[calc(100dvh-56px)] min-h-0">
      {/* profile column */}
      <aside className="hidden w-[330px] shrink-0 overflow-y-auto border-r border-[var(--color-line)] lg:block">
        <div className="relative aspect-square overflow-hidden" style={{ maskImage: "linear-gradient(180deg,#000 60%,transparent 100%)" }}>
          <div className="absolute inset-0" style={{ background: `radial-gradient(70% 60% at 50% 35%, rgb(${agent.rgb} / 0.4), transparent 70%), #050608` }} />
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={agent.avatar} alt={agent.name} className="relative h-full w-full scale-[1.2] object-cover" style={{ maskImage: "linear-gradient(180deg,#000 50%,transparent 100%)" }} />
          <Link href="/agents" className="glass absolute left-3 top-3 flex h-8 items-center gap-1.5 rounded-full px-3 text-[12px] text-[var(--color-fg-2)] hover:text-[var(--color-fg)]"><ArrowLeft size={13} /> All agents</Link>
        </div>
        <div className="-mt-16 space-y-5 px-5 pb-6">
          <div className="relative">
            <span className="rounded-md px-1.5 py-0.5 font-mono text-[10.5px] font-bold" style={{ color: agent.accent, background: `rgb(${agent.rgb} / 0.14)` }}>{agent.chip}</span>
            <h1 className="mt-2 text-[26px] font-semibold tracking-[-0.03em]">{agent.name}</h1>
            <p className="text-[13px] font-medium" style={{ color: agent.accent }}>{agent.role}</p>
            <p className="mt-3 text-[13px] leading-[21px] text-[var(--color-fg-2)]">{agent.bio}</p>
          </div>
          <div className="grid grid-cols-3 gap-2">
            {[["Sessions", agent.stats.sessions], ["Decisions", agent.stats.decisions], ["Sources", agent.stats.sources]].map(([l, v]) => (
              <div key={l as string} className="surface rounded-xl px-2 py-2.5 text-center">
                <p className="font-mono text-[14px] font-semibold">{v}</p>
                <p className="text-[10px] text-[var(--color-faint)]">{l}</p>
              </div>
            ))}
          </div>
          <div>
            <p className="eyebrow mb-2">Skills</p>
            <div className="flex flex-wrap gap-1.5">
              {agent.skills.map((s) => <span key={s} className="rounded-lg border border-[var(--color-line)] bg-white/[0.02] px-2 py-1 text-[11.5px] text-[var(--color-fg-2)]">{s}</span>)}
            </div>
          </div>
          <div className="surface flex items-center gap-3 rounded-xl p-3">
            <span className="grid h-8 w-8 place-items-center rounded-lg bg-white/[0.05] text-[var(--color-muted)]"><Cpu size={15} /></span>
            <div className="leading-tight">
              <p className="text-[10.5px] text-[var(--color-faint)]">Model</p>
              <p className="font-mono text-[12px]">{agent.model}</p>
            </div>
          </div>
          <div>
            <p className="eyebrow mb-2">Other agents</p>
            <div className="flex gap-2">
              {AGENTS.filter((a) => a.id !== agent.id).map((a) => (
                <Link key={a.id} href={`/agents/${a.id}`} title={a.name}><AgentAvatar agent={a} size={34} /></Link>
              ))}
            </div>
          </div>
        </div>
      </aside>

      {/* chat column */}
      <div className="flex min-w-0 flex-1 flex-col">
        <div className="flex shrink-0 items-center gap-3 border-b border-[var(--color-line)] px-3 py-2.5 sm:px-6">
          <Link href="/agents" className="grid h-8 w-8 place-items-center rounded-lg text-[var(--color-muted)] hover:bg-white/5 lg:hidden"><ArrowLeft size={16} /></Link>
          <AgentAvatar agent={agent} size={32} status="online" />
          <div className="min-w-0 flex-1 leading-tight">
            <p className="text-[14px] font-semibold">{agent.name}</p>
            <p className="text-[11.5px] text-[var(--color-muted)]">Private room · {agent.role}</p>
          </div>
          {msgs.length > 0 && (
            <button onClick={() => { stop(); setMsgs([]); }} className="btn-ghost flex h-8 items-center gap-1.5 rounded-lg px-2.5 text-[12px]"><Trash2 size={13} /> Clear</button>
          )}
        </div>

        <div ref={scroll} className="min-h-0 flex-1 overflow-y-auto">
          {msgs.length === 0 ? (
            <div className="mx-auto flex min-h-full max-w-[640px] flex-col items-center justify-center px-4 py-10 text-center">
              <div className="relative animate-[rise_0.5s_both]">
                <div className="absolute inset-0 -z-10 scale-150 rounded-full blur-3xl" style={{ background: `rgb(${agent.rgb} / 0.35)` }} />
                <AgentAvatar agent={agent} size={88} />
              </div>
              <h2 className="mt-5 text-[22px] font-semibold tracking-tight animate-[rise_0.5s_0.05s_both]">Habari Mkuu, I&apos;m {agent.name}.</h2>
              <p className="mt-1.5 max-w-[420px] text-[13.5px] leading-6 text-[var(--color-muted)] animate-[rise_0.5s_0.1s_both]">{agent.bio}</p>
              <div className="mt-7 grid w-full gap-2 sm:grid-cols-3 animate-[rise_0.5s_0.15s_both]">
                {agent.starters.map((s) => (
                  <button key={s} onClick={() => send(s)} className="surface group rounded-2xl p-3.5 text-left transition hover:border-white/15">
                    <Sparkles size={14} style={{ color: agent.accent }} />
                    <p className="mt-2 text-[12.5px] leading-5 text-[var(--color-fg-2)] group-hover:text-[var(--color-fg)]">{s}</p>
                  </button>
                ))}
              </div>
            </div>
          ) : (
            <div className="mx-auto max-w-[780px] space-y-6 px-3 py-6 sm:px-6">
              {msgs.map((m) => (m.kind === "user" ? <UserPrompt key={m.id} text={m.text} /> : <BoardMessage key={m.id} turn={m} />))}
            </div>
          )}
        </div>

        <div className="shrink-0 px-3 pb-[max(12px,env(safe-area-inset-bottom))] pt-2 sm:px-6">
          <PromptComposer size="md" running={busy} onStop={stop} onSubmit={send} placeholder={`Message ${agent.name}…`} className="mx-auto max-w-[780px]" />
        </div>
      </div>
    </div>
  );
}
