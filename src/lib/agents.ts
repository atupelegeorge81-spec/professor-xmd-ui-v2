export type AgentId = "optimus" | "ultron" | "vextron" | "megatron" | "cybertron";

export interface Agent {
  id: AgentId;
  name: string;
  role: string;
  chip: string;
  tagline: string;
  bio: string;
  avatar: string;
  accent: string;
  /** rgb triplet for alpha usage */
  rgb: string;
  model: string;
  skills: string[];
  stats: { sessions: number; decisions: number; sources: number };
  starters: string[];
}

export const AGENTS: Agent[] = [
  {
    id: "optimus",
    name: "Optimus",
    role: "Project Manager",
    chip: "PM",
    tagline: "Consensus chair · protects decision quality",
    bio: "Chairs every board session, turns fuzzy ideas into locked decisions and writes the final Swahili report.",
    avatar: "/agents/optimus.webp",
    accent: "#3b82f6",
    rgb: "59 130 246",
    model: "deepseek-v4-pro",
    skills: ["Roadmaps", "Scope", "Risk", "Reports", "Pricing"],
    stats: { sessions: 128, decisions: 412, sources: 936 },
    starters: ["Break my idea into an MVP roadmap", "What are the biggest risks here?", "Draft a 6-week delivery plan"],
  },
  {
    id: "ultron",
    name: "Ultron",
    role: "UI/UX Designer",
    chip: "UX",
    tagline: "Look & feel · patterns · delightful flows",
    bio: "Owns the product's visual language, user journeys and design system. Obsessed with clarity and motion.",
    avatar: "/agents/ultron.webp",
    accent: "#a855f7",
    rgb: "168 85 247",
    model: "qwen3.6-plus",
    skills: ["Design systems", "User flows", "Colour", "Motion", "A11y"],
    stats: { sessions: 117, decisions: 268, sources: 701 },
    starters: ["Propose a colour system for a fintech app", "Review my onboarding flow", "Which layout fits a dashboard?"],
  },
  {
    id: "vextron",
    name: "Vextron",
    role: "Frontend Engineer",
    chip: "FE",
    tagline: "React · Next.js · Tailwind · performance",
    bio: "Ships fast, accessible interfaces. Picks the right framework, keeps bundles small and Core Web Vitals green.",
    avatar: "/agents/vextron.webp",
    accent: "#f97316",
    rgb: "249 115 22",
    model: "qwen3.6-coder",
    skills: ["Next.js", "React 19", "Tailwind", "PWA", "Web Vitals"],
    stats: { sessions: 121, decisions: 301, sources: 812 },
    starters: ["Next.js or Remix for this project?", "How do I make my PWA work offline?", "Audit my page performance"],
  },
  {
    id: "megatron",
    name: "Megatron",
    role: "Backend & DB Engineer",
    chip: "BE",
    tagline: "APIs · data · architecture · scale",
    bio: "Designs APIs, schemas and integrations — M-Pesa, Airtel Money, queues — that stay boring under load.",
    avatar: "/agents/megatron.webp",
    accent: "#ef4444",
    rgb: "239 68 68",
    model: "deepseek-v4",
    skills: ["Postgres", "APIs", "Payments", "Queues", "Caching"],
    stats: { sessions: 119, decisions: 344, sources: 768 },
    starters: ["Design a schema for a wallet app", "How should I integrate M-Pesa?", "REST or tRPC here?"],
  },
  {
    id: "cybertron",
    name: "Cybertron",
    role: "QA & DevOps Engineer",
    chip: "QA",
    tagline: "Reliability · security · testing · deploy",
    bio: "Guards quality and uptime: test strategy, CI/CD, observability, threat modelling and compliance checks.",
    avatar: "/agents/cybertron.webp",
    accent: "#84cc16",
    rgb: "132 204 22",
    model: "qwen3.6-plus",
    skills: ["CI/CD", "Testing", "Security", "Observability", "Docker"],
    stats: { sessions: 114, decisions: 229, sources: 655 },
    starters: ["Set up CI/CD for a Next.js app", "Threat-model my login flow", "What should I monitor in prod?"],
  },
];

export const getAgent = (id: string) => AGENTS.find((a) => a.id === id);
