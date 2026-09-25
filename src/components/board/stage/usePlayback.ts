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
