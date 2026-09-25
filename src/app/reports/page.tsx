"use client";
import { Suspense, useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Search, X, Printer, Copy, Check, Clock, Lock, FileText, LayoutGrid, List } from "lucide-react";
import { getAgent } from "@/lib/agents";
import { REPORTS, type Report } from "@/lib/mock";
import { cn } from "@/lib/utils";
import { AvatarStack } from "@/components/ui/AgentAvatar";
import { Markdown, slug } from "@/components/ui/Markdown";
import { Spotlight } from "@/components/ui/Spotlight";

const TAG: Record<Report["tag"], string> = {
  Fintech: "52 211 153",
  EdTech: "61 123 255",
  Commerce: "249 115 22",
  Health: "244 114 182",
  Logistics: "250 204 21",
};

function Cover({ r }: { r: Report }) {
  const c = TAG[r.tag];
  return (
    <div className="relative h-[132px] overflow-hidden rounded-t-[20px] border-b border-[var(--color-line)]" style={{ background: `radial-gradient(120% 90% at 100% 0%, rgb(${c} / 0.28), transparent 60%), radial-gradient(90% 80% at 0% 100%, rgb(139 92 246 / 0.16), transparent 60%), #0a0c10` }}>
      <div className="grid-lines absolute inset-0 opacity-70" />
      {/* mini document */}
      <div className="absolute bottom-[-18px] right-5 w-[46%] rotate-[-4deg] rounded-t-xl border border-white/10 bg-[#0f1218] p-3 shadow-2xl transition duration-500 group-hover:-translate-y-2 group-hover:rotate-[-2deg]">
        <div className="h-1.5 w-2/3 rounded-full bg-white/30" />
        <div className="mt-2.5 space-y-1.5">
          {[90, 75, 82, 60].map((w, i) => <div key={i} className="h-1 rounded-full bg-white/10" style={{ width: `${w}%` }} />)}
        </div>
        <div className="mt-2.5 grid grid-cols-3 gap-1">
          {[0, 1, 2].map((i) => <div key={i} className="h-3 rounded-sm" style={{ background: `rgb(${c} / ${0.5 - i * 0.14})` }} />)}
        </div>
      </div>
      <span className="absolute left-4 top-4 rounded-md px-2 py-0.5 text-[10.5px] font-semibold" style={{ color: `rgb(${c})`, background: `rgb(${c} / 0.14)` }}>{r.tag}</span>
    </div>
  );
}

function Reader({ r, onClose }: { r: Report; onClose: () => void }) {
  const [copied, setCopied] = useState(false);
  const [active, setActive] = useState("");
  const toc = r.content.split("\n").filter((l) => l.startsWith("## ")).map((l) => l.slice(3));
  useEffect(() => {
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = ""; };
  }, []);
  return (
    <div className="fixed inset-0 z-[65] flex flex-col bg-[rgb(7_8_11/0.97)] backdrop-blur-md anim-[fade]">
      <div className="no-print flex h-14 shrink-0 items-center gap-2 border-b border-[var(--color-line)] px-3 sm:px-5">
        <button onClick={onClose} className="grid h-9 w-9 place-items-center rounded-xl text-[var(--color-muted)] hover:bg-white/5 hover:text-[var(--color-fg)]" aria-label="Close"><X size={17} /></button>
        <div className="min-w-0 flex-1">
          <p className="truncate text-[13.5px] font-semibold">Ripoti: {r.title}</p>
          <p className="truncate text-[11px] text-[var(--color-faint)]">{r.project} · {r.created} · {r.readMins} min read</p>
        </div>
        <button onClick={() => { navigator.clipboard?.writeText(r.content); setCopied(true); setTimeout(() => setCopied(false), 1300); }} className="btn-ghost flex h-9 items-center gap-1.5 rounded-xl px-3 text-[12.5px]">
          {copied ? <Check size={14} /> : <Copy size={14} />}<span className="hidden sm:inline">{copied ? "Copied" : "Copy"}</span>
        </button>
        <button onClick={() => window.print()} className="btn-white flex h-9 items-center gap-1.5 rounded-xl px-3 text-[12.5px] font-semibold"><Printer size={14} /> <span className="hidden sm:inline">Export PDF</span></button>
      </div>
      <div className="flex min-h-0 flex-1">
        <nav className="no-print hidden w-[260px] shrink-0 overflow-y-auto border-r border-[var(--color-line)] p-5 lg:block">
          <p className="eyebrow mb-3">Contents</p>
          <ol className="space-y-0.5">
            {toc.map((t) => (
              <li key={t}>
                <a href={`#${slug(t)}`} onClick={() => setActive(t)} className={cn("block rounded-lg px-2.5 py-1.5 text-[12.5px] transition", active === t ? "bg-white/[0.06] text-[var(--color-fg)]" : "text-[var(--color-muted)] hover:text-[var(--color-fg-2)]")}>{t}</a>
              </li>
            ))}
          </ol>
          <div className="mt-6 rounded-xl border border-[var(--color-line)] p-3">
            <p className="text-[11px] text-[var(--color-faint)]">Prepared by</p>
            <div className="mt-2"><AvatarStack agents={r.agents.map((a) => getAgent(a)!)} size={24} /></div>
            <p className="mt-2 text-[11.5px] text-[var(--color-muted)]">Chaired & written by Optimus</p>
          </div>
        </nav>
        <div className="min-h-0 flex-1 overflow-y-auto scroll-smooth">
          <article className="mx-auto max-w-[760px] px-5 py-10 sm:px-10">
            <div className="mb-8 flex flex-wrap items-center gap-2">
              <span className="rounded-md px-2 py-0.5 text-[11px] font-semibold" style={{ color: `rgb(${TAG[r.tag]})`, background: `rgb(${TAG[r.tag]} / 0.14)` }}>{r.tag}</span>
              <span className="flex items-center gap-1 text-[11.5px] text-[var(--color-faint)]"><Lock size={12} /> {r.decisions} decisions locked</span>
              <span className="flex items-center gap-1 text-[11.5px] text-[var(--color-faint)]"><Clock size={12} /> {r.readMins} min</span>
            </div>
            <Markdown text={r.content} />
          </article>
        </div>
      </div>
    </div>
  );
}

function ReportsInner() {
  const params = useSearchParams();
  const router = useRouter();
  const [q, setQ] = useState("");
  const [tag, setTag] = useState<"All" | Report["tag"]>("All");
  const [view, setView] = useState<"grid" | "list">("grid");
  const openId = params.get("open");
  const open = REPORTS.find((r) => r.id === openId);
  const list = useMemo(
    () => REPORTS.filter((r) => (tag === "All" || r.tag === tag) && `${r.title} ${r.project} ${r.summary}`.toLowerCase().includes(q.toLowerCase())),
    [q, tag],
  );
  const tags = ["All", ...Array.from(new Set(REPORTS.map((r) => r.tag)))] as const;

  return (
    <div className="mx-auto w-full max-w-[1320px] px-3 pb-28 pt-5 sm:px-6 sm:pt-7 lg:pb-12">
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3 animate-[rise_0.5s_both]">
        <div>
          <p className="eyebrow">Library</p>
          <h1 className="mt-1 text-[26px] font-semibold tracking-[-0.03em] sm:text-[30px]">Reports</h1>
          <p className="mt-1 text-[13.5px] text-[var(--color-muted)]">Every session ends with a structured Swahili report — decisions, stack, risks and action plan.</p>
        </div>
      </div>

      <div className="mb-5 flex flex-col gap-2.5 sm:flex-row sm:items-center">
        <div className="surface flex h-[56px] w-full items-center gap-2.5 rounded-full px-3.5 sm:h-12 sm:max-w-[480px] sm:flex-1 sm:rounded-[16px] sm:px-4">
                                  <Search size={16} className="shrink-0 text-[var(--color-faint)]" />
                                  <input
                                    value={q}
                                    onChange={(e) => setQ(e.target.value)}
                                    placeholder="Search reports…"
                                    className="h-full min-w-0 flex-1 bg-transparent text-[13.5px] outline-none placeholder:text-[var(--color-faint)]"
                                  />
                                </div>
        <div className="no-scrollbar flex gap-1.5 overflow-x-auto">
          {tags.map((t) => (
            <button key={t} onClick={() => setTag(t as typeof tag)} className={cn("h-9 shrink-0 rounded-xl border px-3 text-[12.5px] transition", tag === t ? "border-white/20 bg-white/10 text-[var(--color-fg)]" : "border-[var(--color-line)] text-[var(--color-muted)] hover:text-[var(--color-fg-2)]")}>{t}</button>
          ))}
        </div>
        <div className="ml-auto hidden gap-1 rounded-xl border border-[var(--color-line)] p-1 sm:flex">
          {(["grid", "list"] as const).map((v) => (
            <button key={v} onClick={() => setView(v)} aria-label={v} className={cn("grid h-7 w-8 place-items-center rounded-lg", view === v ? "bg-white/10 text-[var(--color-fg)]" : "text-[var(--color-faint)]")}>{v === "grid" ? <LayoutGrid size={14} /> : <List size={14} />}</button>
          ))}
        </div>
      </div>

      {list.length === 0 && (
        <div className="surface grid place-items-center rounded-[20px] py-20 text-center">
          <FileText size={22} className="text-[var(--color-faint)]" />
          <p className="mt-3 text-[13.5px] text-[var(--color-muted)]">No reports match “{q}”</p>
        </div>
      )}

      {view === "grid" ? (
        <div className="stagger grid gap-3 sm:grid-cols-2 xl:grid-cols-3 xl:gap-4">
          {list.map((r) => (
            <Spotlight key={r.id} color={TAG[r.tag]} as="article" className="group cursor-pointer" onClick={() => router.push(`/reports?open=${r.id}`)}>
              <Cover r={r} />
              <div className="p-4">
                <h3 className="text-[15.5px] font-semibold leading-snug tracking-tight">Ripoti: {r.title}</h3>
                <p className="mt-1.5 line-clamp-2 text-[12.5px] leading-5 text-[var(--color-muted)]">{r.summary}</p>
                <div className="mt-4 flex items-center gap-3 border-t border-[var(--color-line)] pt-3 text-[11.5px] text-[var(--color-faint)]">
                  <AvatarStack agents={r.agents.map((a) => getAgent(a)!)} size={20} />
                  <span className="flex items-center gap-1"><Lock size={11} /> {r.decisions}</span>
                  <span className="flex items-center gap-1"><Clock size={11} /> {r.readMins}m</span>
                  <span className="ml-auto">{r.created}</span>
                </div>
              </div>
            </Spotlight>
          ))}
        </div>
      ) : (
        <div className="surface divide-y divide-[var(--color-line)] overflow-hidden rounded-[20px]">
          {list.map((r) => (
            <button key={r.id} onClick={() => router.push(`/reports?open=${r.id}`)} className="flex w-full items-center gap-4 px-4 py-3.5 text-left transition hover:bg-white/[0.03]">
              <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl" style={{ background: `rgb(${TAG[r.tag]} / 0.12)`, color: `rgb(${TAG[r.tag]})` }}><FileText size={17} /></span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[13.5px] font-medium">Ripoti: {r.title}</span>
                <span className="block truncate text-[12px] text-[var(--color-faint)]">{r.summary}</span>
              </span>
              <AvatarStack agents={r.agents.map((a) => getAgent(a)!)} size={20} />
              <span className="w-24 text-right text-[11.5px] text-[var(--color-faint)]">{r.created}</span>
            </button>
          ))}
        </div>
      )}

      {open && <Reader r={open} onClose={() => router.push("/reports")} />}
    </div>
  );
}

export default function ReportsPage() {
  return (
    <Suspense fallback={null}>
      <ReportsInner />
    </Suspense>
  );
}
