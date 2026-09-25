"use client";
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import type { AgentId } from "@/lib/agents";
import { LOGS, USAGE, type LogEntry } from "@/lib/mock";

export type AgentStatus = "online" | "thinking" | "speaking" | "idle";

interface Ctx {
activityOpen: boolean;
  setActivityOpen: (v: boolean) => void;
  mobileNavOpen: boolean;
  setMobileNavOpen: (v: boolean) => void;
  logs: LogEntry[];
  addLog: (type: LogEntry["type"], message: string) => void;
  clearLogs: () => void;
  status: Record<AgentId, AgentStatus>;
  setStatus: (id: AgentId, s: AgentStatus) => void;
  resetStatus: () => void;
  boardLive: boolean;
  setBoardLive: (v: boolean) => void;
  usage: typeof USAGE;
  bumpUsage: (id: AgentId, tokens: number) => void;
}

const AppCtx = createContext<Ctx | null>(null);

const ALL_ONLINE: Record<AgentId, AgentStatus> = {
  optimus: "online",
  ultron: "online",
  vextron: "online",
  megatron: "online",
  cybertron: "online",
};

export function AppStateProvider({ children }: { children: ReactNode }) {
const [activityOpen, setActivityOpen] = useState(false);
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  const [logs, setLogs] = useState<LogEntry[]>(LOGS);
  const [status, setStatusMap] = useState(ALL_ONLINE);
  const [boardLive, setBoardLive] = useState(false);
  const [usage, setUsage] = useState(USAGE);

  const addLog = useCallback((type: LogEntry["type"], message: string) => {
    setLogs((l) => [
      ...l.slice(-199),
      { id: Math.random().toString(36).slice(2), time: new Date().toLocaleTimeString("en-GB"), type, message },
    ]);
  }, []);
  const setStatus = useCallback((id: AgentId, s: AgentStatus) => setStatusMap((m) => ({ ...m, [id]: s })), []);
  const resetStatus = useCallback(() => setStatusMap(ALL_ONLINE), []);
  const bumpUsage = useCallback(
    (id: AgentId, tokens: number) =>
      setUsage((u) => ({ ...u, [id]: { requests: u[id].requests + 1, tokens: u[id].tokens + tokens } })),
    [],
  );

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
if (e.key === "Escape") {
setActivityOpen(false);
        setMobileNavOpen(false);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const value = useMemo(
    () => ({
      activityOpen, setActivityOpen, mobileNavOpen, setMobileNavOpen,
      logs, addLog, clearLogs: () => setLogs([]), status, setStatus, resetStatus, boardLive, setBoardLive, usage, bumpUsage,
    }),
    [activityOpen, mobileNavOpen, logs, addLog, status, setStatus, resetStatus, boardLive, usage, bumpUsage],
  );
  return <AppCtx.Provider value={value}>{children}</AppCtx.Provider>;
}

export function useApp() {
  const c = useContext(AppCtx);
  if (!c) throw new Error("useApp outside provider");
  return c;
}
