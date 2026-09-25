"use client";

import { Globe, Lock, Sparkles } from "lucide-react";
import { AGENTS } from "@/lib/agents";
import { WEEK_ACTIVITY } from "@/lib/mock";
import { Sparkline } from "@/components/ui/Sparkline";
import { useApp } from "@/components/shell/AppState";
import { compact } from "@/lib/utils";
import { FogRail } from "./Fog";

const CARD =
  "relative isolate flex w-[80%] shrink-0 snap-start flex-col overflow-hidden rounded-[22px] border border-white/[0.07] bg-[linear-gradient(180deg,rgb(255_255_255/0.035),rgb(255_255_255/0.01))] p-4 sm:w-[46%] md:w-[31.5%] xl:w-auto";

function Glow({ rgb }: { rgb: string }) {
  return (
    <span
      aria-hidden
      className="pointer-events-none absolute -right-10 -top-12 -z-10 h-32 w-32 rounded-full blur-[48px]"
      style={{ background: `rgb(${rgb} / 0.22)` }}
    />
  );
}

export function Pulse({ className = "" }: { className?: string }) {
  const { usage } = useApp();
  const used = Object.values(usage).reduce((s, u) => s + u.tokens, 0);
  const budget = 100_000;
  const pct = Math.min(1, used / budget);
  const R = 30;
  const C = 2 * Math.PI * R;

  return (
    <section className={className}>
      <div className="mb-2.5 flex items-baseline justify-between xl:hidden">
        <h3 className="text-[15px] font-semibold tracking-[-0.01em]">Pulse</h3>
        <span className="text-[11.5px] text-[var(--color-faint)]">
          Last 30 days
        </span>
      </div>

      <FogRail
        label="Pulse"
        className="-mx-4 scroll-px-4 gap-3 px-4 sm:-mx-6 sm:scroll-px-6 sm:px-6 xl:mx-0 xl:grid xl:h-full xl:grid-rows-3 xl:overflow-visible xl:px-0 xl:[mask-image:none] xl:[-webkit-mask-image:none]"
      >
        <article className={CARD}>
          <Glow rgb="139 92 246" />

          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1.5 text-[12px] text-[var(--color-muted)]">
              <Lock size={13} />
              Decisions locked
            </span>
            <span className="rounded-full bg-[rgb(52_211_153/0.12)] px-2 py-0.5 text-[10.5px] font-semibold text-[var(--color-ok)]">
              +18%
            </span>
          </div>

          <div className="mt-2 flex items-end justify-between gap-3">
            <div>
              <p className="text-[34px] font-semibold leading-none tracking-[-0.045em]">
                47
              </p>
              <p className="mt-1 text-[11px] text-[var(--color-faint)]">
                12 sessions
              </p>
            </div>

            <div className="w-[58%] [mask-image:linear-gradient(90deg,transparent,#000_35%)] [-webkit-mask-image:linear-gradient(90deg,transparent,#000_35%)]">
              <Sparkline
                data={WEEK_ACTIVITY}
                color="#a78bfa"
                id="pulse-dec"
                height={54}
              />
            </div>
          </div>
        </article>

        <article className={CARD}>
          <Glow rgb="61 123 255" />

          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1.5 text-[12px] text-[var(--color-muted)]">
              <Globe size={13} />
              Sources verified
            </span>
            <span className="text-[10.5px] text-[var(--color-faint)]">
              evidence gate
            </span>
          </div>

          <div className="mt-2 flex items-end justify-between gap-3">
            <p className="text-[34px] font-semibold leading-none tracking-[-0.045em]">
              3,872
            </p>

            <div className="flex h-[54px] w-[46%] items-end gap-1">
              {AGENTS.map((a) => (
                <span
                  key={a.id}
                  className="flex flex-1 flex-col items-center gap-1"
                >
                  <span
                    className="w-full rounded-[5px]"
                    style={{
                      height: `${Math.max(
                        18,
                        (a.stats.sources / 936) * 42,
                      )}px`,
                      background: `linear-gradient(180deg, ${a.accent}, rgb(${a.rgb} / 0.15))`,
                    }}
                  />
                </span>
              ))}
            </div>
          </div>
        </article>

        <article className={CARD}>
          <Glow rgb="217 70 239" />

          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1.5 text-[12px] text-[var(--color-muted)]">
              <Sparkles size={13} />
              Today&apos;s tokens
            </span>
            <span className="text-[10.5px] text-[var(--color-faint)]">
              of {compact(budget)}
            </span>
          </div>

          <div className="mt-2 flex items-end justify-between gap-3">
            <div>
              <p className="text-[34px] font-semibold leading-none tracking-[-0.045em]">
                {compact(used)}
              </p>
              <p className="mt-1 text-[11px] text-[var(--color-faint)]">
                {Math.round(pct * 100)}% of daily budget
              </p>
            </div>

            <svg width="68" height="68" viewBox="0 0 76 76" className="-mb-1 shrink-0">
              <defs>
                <linearGradient id="pulse-ring" x1="0" y1="0" x2="1" y2="1">
                  <stop offset="0" stopColor="#3d7bff" />
                  <stop offset="0.55" stopColor="#8b5cf6" />
                  <stop offset="1" stopColor="#d946ef" />
                </linearGradient>
              </defs>

              <circle
                cx="38"
                cy="38"
                r={R}
                stroke="rgb(255 255 255 / 0.07)"
                strokeWidth="7"
                fill="none"
              />

              <circle
                cx="38"
                cy="38"
                r={R}
                stroke="url(#pulse-ring)"
                strokeWidth="7"
                strokeLinecap="round"
                fill="none"
                strokeDasharray={`${C * pct} ${C}`}
                transform="rotate(-90 38 38)"
              />
            </svg>
          </div>
        </article>
      </FogRail>
    </section>
  );
}
