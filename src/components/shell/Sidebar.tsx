"use client";
import { XmdBot } from "../icons/XmdBot";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { LayoutGrid, Presentation, FileText, History, Plus, Settings2, Sparkles } from "lucide-react";
import { AGENTS } from "@/lib/agents";
import { REPORTS, SESSIONS } from "@/lib/mock";
import { cn, compact } from "@/lib/utils";
import { AgentAvatar } from "../ui/AgentAvatar";
import { LogoMark } from "../ui/Logo";
import { useApp } from "./AppState";

export const NAV = [
  { href: "/", label: "Overview", icon: LayoutGrid },
  { href: "/board", label: "Board Room", icon: Presentation },
  { href: "/agents", label: "Agents", icon: XmdBot },
  { href: "/reports", label: "Reports", icon: FileText, count: REPORTS.length },
  { href: "/sessions", label: "Sessions", icon: History, count: SESSIONS.length },
];

export function isActive(pathname: string, href: string) {
  return href === "/" ? pathname === "/" : pathname.startsWith(href);
}

export function SidebarContent({ onNavigate }: { onNavigate?: () => void }) {
  const pathname = usePathname();
  const { status, boardLive, usage } = useApp();
  const totalTokens = Object.values(usage).reduce((s, u) => s + u.tokens, 0);
  const pct = Math.min(100, Math.round((totalTokens / 100000) * 100));

  return (
    <div className="flex h-full flex-col">
      {/* brand */}
      <div className="flex items-center gap-2.5 px-4 pb-3 pt-4">
        <LogoMark size={34} />
        <div className="min-w-0 flex-1 leading-tight">
          <p className="truncate text-[13.5px] font-semibold tracking-tight text-[var(--color-fg)]">PROFESSOR-XMD</p>
          <p className="truncate text-[11px] text-[var(--color-muted)]">AI engineering company</p>
        </div>
      </div>


      <nav className="mt-4 space-y-0.5 px-3">
        {NAV.map((n) => {
          const active = isActive(pathname, n.href);
          const Icon = n.icon;
          return (
            <Link
              key={n.href}
              href={n.href}
              onClick={onNavigate}
              className={cn(
                "group relative flex h-9 items-center gap-2.5 rounded-xl px-3 text-[13px] font-medium transition-colors",
                active ? "bg-white/[0.06] text-[var(--color-fg)]" : "text-[var(--color-muted)] hover:bg-white/[0.035] hover:text-[var(--color-fg-2)]",
              )}
            >
              {active && <span className="absolute left-0 top-1/2 h-4 w-[3px] -translate-y-1/2 rounded-r-full bg-prism" />}
              <Icon size={16} strokeWidth={1.8} className={active ? "text-[var(--color-fg)]" : ""} />
              <span className="flex-1">{n.label}</span>
              {n.href === "/board" && boardLive && (
                <span className="flex items-center gap-1 rounded-full bg-[rgb(52_211_153/0.12)] px-1.5 py-0.5 text-[10px] font-semibold text-[var(--color-ok)]">
                  <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-[var(--color-ok)]" /> LIVE
                </span>
              )}
              {n.count ? <span className="font-mono text-[11px] text-[var(--color-faint)]">{n.count}</span> : null}
            </Link>
          );
        })}
      </nav>

      <div className="mt-6 flex items-center justify-between px-6">
        <span className="eyebrow">Team</span>
        <span className="text-[10.5px] text-[var(--color-faint)]">5 online</span>
      </div>
      <div className="mt-2 space-y-0.5 px-3">
        {AGENTS.map((a) => {
          const active = pathname === `/agents/${a.id}`;
          const s = status[a.id];
          return (
            <Link
              key={a.id}
              href={`/agents/${a.id}`}
              onClick={onNavigate}
              className={cn(
                "flex items-center gap-2.5 rounded-xl px-2.5 py-1.5 transition-colors",
                active ? "bg-white/[0.06]" : "hover:bg-white/[0.035]",
              )}
            >
              <AgentAvatar agent={a} size={26} status={s} />
              <span className="min-w-0 flex-1 leading-tight">
                <span className="block truncate text-[12.5px] font-medium text-[var(--color-fg-2)]">{a.name}</span>
                <span className="block truncate text-[10.5px] text-[var(--color-faint)]">
                  {s === "thinking" ? <span style={{ color: a.accent }}>thinking…</span> : s === "speaking" ? <span style={{ color: a.accent }}>speaking</span> : a.role}
                </span>
              </span>
              <span className="rounded-md px-1.5 py-0.5 font-mono text-[9.5px] font-semibold" style={{ color: a.accent, background: `rgb(${a.rgb} / 0.1)` }}>
                {a.chip}
              </span>
            </Link>
          );
        })}
      </div>

      <div className="mt-auto space-y-3 p-3">
        <div className="surface rounded-2xl p-3.5">
          <div className="flex items-center gap-2 text-[12px] font-medium text-[var(--color-fg-2)]">
            <Sparkles size={13} className="text-[#a78bfa]" /> Today&apos;s usage
          </div>
          <div className="mt-2 flex items-baseline justify-between">
            <span className="text-[18px] font-semibold tracking-tight">{compact(totalTokens)}</span>
            <span className="text-[11px] text-[var(--color-faint)]">of 100k tokens</span>
          </div>
          <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-white/[0.06]">
            <div className="h-full rounded-full bg-prism transition-all duration-700" style={{ width: `${pct}%` }} />
          </div>
        </div>
        <div className="flex items-center gap-2.5 rounded-xl px-2 py-1.5">
          <span className="grid h-8 w-8 place-items-center rounded-full bg-gradient-to-br from-[#2a2f3d] to-[#151821] text-[12px] font-semibold text-[var(--color-fg)] ring-1 ring-white/10">M</span>
          <span className="min-w-0 flex-1 leading-tight">
            <span className="block truncate text-[12.5px] font-medium">Mkuu</span>
            <span className="block truncate text-[10.5px] text-[var(--color-faint)]">CEO · Owner</span>
          </span>
          <button aria-label="Settings" className="grid h-8 w-8 place-items-center rounded-lg text-[var(--color-muted)] hover:bg-white/5 hover:text-[var(--color-fg)]">
            <Settings2 size={15} />
          </button>
        </div>
      </div>
    </div>
  );
}

export function Sidebar() {
  return (
    <aside className="sticky top-0 hidden h-dvh w-[252px] shrink-0 border-r border-[var(--color-line)] bg-[var(--color-ink-1)]/60 lg:block">
      <SidebarContent />
    </aside>
  );
}

export function NewSessionButton({ compact: c }: { compact?: boolean }) {
  return (
    <Link href="/board?new=1" className={cn("btn-prism inline-flex h-9 items-center gap-1.5 rounded-xl text-[12.5px] font-semibold", c ? "w-9 justify-center" : "px-3.5")}>
      <Plus size={15} strokeWidth={2.4} />
      {!c && <span>New session</span>}
    </Link>
  );
}
