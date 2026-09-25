"use client";
import Link from "next/link";
import { useMemo, useState } from "react";
import { Search, CheckCircle2, CircleDashed, ChevronRight, Plus } from "lucide-react";
import { getAgent } from "@/lib/agents";
import { SESSIONS, type Session } from "@/lib/mock";
import { cn, compact } from "@/lib/utils";
import { AvatarStack } from "@/components/ui/AgentAvatar";

const GROUPS: Session["group"][] = ["Today", "Yesterday", "This week", "Earlier"];

export default function SessionsPage() {
  const [q, setQ] = useState("");
  const [tab, setTab] = useState<"all" | "complete" | "unresolved">("all");
  const list = useMemo(
    () => SESSIONS.filter((s) => (tab === "all" || s.status === tab) && `${s.title} ${s.project}`.toLowerCase().includes(q.toLowerCase())),
    [q, tab],
  );
  const counts = { all: SESSIONS.length, complete: SESSIONS.filter((s) => s.status === "complete").length, unresolved: SESSIONS.filter((s) => s.status === "unresolved").length };

  return (
    <div className="mx-auto w-full max-w-[1100px] px-3 pb-28 pt-5 sm:px-6 sm:pt-7 lg:pb-12">
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3 animate-[rise_0.5s_both]">
        <div>
          <p className="eyebrow">History</p>
          <h1 className="mt-1 text-[26px] font-semibold tracking-[-0.03em] sm:text-[30px]">Sessions</h1>
          <p className="mt-1 text-[13.5px] text-[var(--color-muted)]">Every board meeting, searchable. Re-open any transcript exactly as it happened.</p>
        </div>
        <Link href="/board?new=1" className="btn-prism flex h-10 items-center gap-1.5 rounded-xl px-4 text-[13px] font-semibold"><Plus size={15} /> New session</Link>
      </div>

      <div className="mb-4 flex flex-col gap-2.5 sm:flex-row sm:items-center">
        <div className="flex gap-1 rounded-xl border border-[var(--color-line)] p-1">
          {(["all", "complete", "unresolved"] as const).map((t) => (
            <button key={t} onClick={() => setTab(t)} className={cn("flex h-8 items-center gap-1.5 rounded-lg px-3 text-[12.5px] capitalize", tab === t ? "bg-white/10 text-[var(--color-fg)]" : "text-[var(--color-muted)] hover:text-[var(--color-fg-2)]")}>
              {t} <span className="font-mono text-[10.5px] text-[var(--color-faint)]">{counts[t]}</span>
            </button>
          ))}
        </div>
        <div className="surface flex h-10 w-full items-center gap-2 rounded-xl px-3 sm:ml-auto sm:flex-1 sm:max-w-[320px]">
          <Search size={15} className="text-[var(--color-faint)]" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search sessions…" className="h-full flex-1 bg-transparent text-[13px] outline-none placeholder:text-[var(--color-faint)]" />
        </div>
      </div>

      <div className="space-y-6">
        {GROUPS.map((g) => {
          const rows = list.filter((s) => s.group === g);
          if (!rows.length) return null;
          return (
            <section key={g} className="animate-[rise_0.5s_both]">
              <p className="eyebrow mb-2 px-1">{g}</p>
              <div className="surface divide-y divide-[var(--color-line)] overflow-hidden rounded-[20px]">
                {rows.map((s) => (
                  <Link key={s.id} href={`/board?session=${s.id}`} className="group flex items-center gap-3 px-4 py-3.5 transition hover:bg-white/[0.03] sm:gap-4">
                    <span className={cn("grid h-9 w-9 shrink-0 place-items-center rounded-xl", s.status === "complete" ? "bg-[rgb(52_211_153/0.1)] text-[var(--color-ok)]" : "bg-[rgb(251_191_36/0.1)] text-[var(--color-warn)]")}>
                      {s.status === "complete" ? <CheckCircle2 size={16} /> : <CircleDashed size={16} />}
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-[13.5px] font-medium">{s.title}</span>
                      <span className="mt-0.5 flex items-center gap-2 text-[11.5px] text-[var(--color-faint)]">
                        <span className="rounded-md bg-white/[0.05] px-1.5 py-px text-[var(--color-fg-2)]">{s.project}</span>
                        <span>{s.rounds} rounds</span>
                        <span className="hidden sm:inline">· {s.decisions} locked</span>
                        <span className="hidden sm:inline">· {compact(s.tokens)} tokens</span>
                      </span>
                    </span>
                    <span className="hidden md:block"><AvatarStack agents={s.agents.map((a) => getAgent(a)!)} size={22} /></span>
                    <span className={cn("hidden rounded-full px-2 py-0.5 text-[10.5px] font-semibold sm:block", s.status === "complete" ? "text-[var(--color-ok)]" : "text-[var(--color-warn)]")}>{s.status === "complete" ? "Complete" : "Unresolved"}</span>
                    <span className="w-12 text-right font-mono text-[11px] text-[var(--color-faint)]">{s.when}</span>
                    <ChevronRight size={15} className="text-[var(--color-faint)] transition group-hover:translate-x-0.5 group-hover:text-[var(--color-fg)]" />
                  </Link>
                ))}
              </div>
            </section>
          );
        })}
        {list.length === 0 && <p className="py-16 text-center text-[13px] text-[var(--color-muted)]">No sessions found.</p>}
      </div>
    </div>
  );
}
