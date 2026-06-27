"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useRef, useState } from "react";
import type { Campaign, CampaignStatus, JDImprovement } from "@/lib/types";

const CREATE_STATUSES: CampaignStatus[] = ["draft", "active", "paused"];

type AIResult = {
  summary: string;
  highlights: string[];
  suggestedSkills: string[];
};

function skillAlreadyListed(lines: string[], skill: string): boolean {
  const skillLower = skill.trim().toLowerCase();
  if (!skillLower) return false;
  return lines.some((line) => {
    const m = line.match(/^\s*[-*•]\s*(.+)$/);
    if (!m) return false;
    const item = m[1].trim().toLowerCase();
    if (item === skillLower) return true;
    if (skillLower.length >= 4 && (item.includes(skillLower) || skillLower.includes(item))) return true;
    return false;
  });
}

function insertSkillIntoJD(jd: string, skill: string): { text: string; changed: boolean } {
  const trimmed = skill.trim();
  if (!trimmed) return { text: jd, changed: false };
  const lines = jd.split("\n");
  if (skillAlreadyListed(lines, trimmed)) return { text: jd, changed: false };
  const sectionRe = /^(requirements|nice to have|skills|qualifications|what we(?:'|')re looking for)/i;
  let insertAt = lines.length;
  for (let i = 0; i < lines.length; i++) {
    const header = lines[i].match(/^##\s+(.+)$/);
    if (!header || !sectionRe.test(header[1].trim())) continue;
    insertAt = i + 1;
    for (let j = i + 1; j < lines.length; j++) {
      if (/^##\s+/.test(lines[j])) break;
      if (/^\s*[-*•]\s+/.test(lines[j])) insertAt = j + 1;
    }
    break;
  }
  const bullet = `- ${trimmed}`;
  if (insertAt >= lines.length) {
    const trimmedJd = jd.trimEnd();
    const prefix = trimmedJd === "" ? "" : trimmedJd.endsWith("\n") ? trimmedJd : `${trimmedJd}\n`;
    return { text: `${prefix}${bullet}\n`, changed: true };
  }
  const next = [...lines];
  next.splice(insertAt, 0, bullet);
  return { text: next.join("\n"), changed: true };
}

export function CampaignEditor() {
  const router = useRouter();

  const [title, setTitle] = useState("");
  const [jdText, setJdText] = useState("");
  const [status, setStatus] = useState<CampaignStatus>("active");
  const [client, setClient] = useState("");
  const [hiringManager, setHiringManager] = useState("");
  const [location, setLocation] = useState("");
  const [headcount, setHeadcount] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [tags, setTags] = useState("");
  const [ownerId, setOwnerId] = useState("");
  const [instruction, setInstruction] = useState("");

  const [aiBusy, setAiBusy] = useState(false);
  const [ai, setAi] = useState<AIResult | null>(null);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [addedSkills, setAddedSkills] = useState<Set<string>>(new Set());
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  async function improveWithAI() {
    if (!title.trim() && !jdText.trim()) {
      setErr("Add a title or some description first, then let AI improve it.");
      return;
    }
    setAiBusy(true);
    setErr(null);
    setMsg(null);
    try {
      const res = await fetch("/api/campaigns/improve", {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=utf-8" },
        body: JSON.stringify({
          title: title.trim(),
          jd_text: jdText.trim(),
          instruction: instruction.trim(),
        }),
      });
      const data = (await res.json()) as JDImprovement & { error?: string };
      if (!res.ok) {
        setErr(data.error ?? `AI improve failed (${res.status})`);
        return;
      }
      if (data.title) setTitle(data.title);
      const nextJd = data.jd_text ?? jdText;
      if (data.jd_text) setJdText(data.jd_text);
      const skills = data.suggested_skills ?? [];
      setAi({
        summary: data.summary ?? "",
        highlights: data.highlights ?? [],
        suggestedSkills: skills,
      });
      const preAdded = new Set<string>();
      for (const s of skills) {
        const { changed } = insertSkillIntoJD(nextJd, s);
        if (!changed) preAdded.add(s.trim().toLowerCase());
      }
      setAddedSkills(preAdded);
      setMsg("AI updated the description. Review and save.");
    } catch {
      setErr("Network error while improving with AI");
    } finally {
      setAiBusy(false);
    }
  }

  function appendSkill(skill: string) {
    const trimmed = skill.trim();
    if (!trimmed) return;
    const { text, changed } = insertSkillIntoJD(jdText, trimmed);
    if (!changed) {
      setAddedSkills((prev) => new Set(prev).add(trimmed.toLowerCase()));
      setMsg(`"${trimmed}" is already listed in the description.`);
      return;
    }
    setJdText(text);
    setAddedSkills((prev) => new Set(prev).add(trimmed.toLowerCase()));
    setMsg(`Added "${trimmed}" to the description.`);
    setErr(null);
    requestAnimationFrame(() => {
      const el = textareaRef.current;
      if (!el) return;
      el.focus();
      el.scrollTop = el.scrollHeight;
    });
  }

  function buildPayload() {
    const tagList = tags
      .split(",")
      .map((t) => t.trim())
      .filter(Boolean);
    const hc = headcount.trim() ? Number(headcount) : null;
    return {
      title: title.trim(),
      jd_text: jdText.trim(),
      status,
      client: client.trim(),
      hiring_manager: hiringManager.trim(),
      location: location.trim(),
      headcount: hc != null && !Number.isNaN(hc) ? hc : null,
      start_date: startDate.trim() || null,
      end_date: endDate.trim() || null,
      tags: tagList,
      owner_id: ownerId.trim() || null,
    };
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!jdText.trim()) {
      setErr("Job description is required");
      return;
    }
    setSaving(true);
    setErr(null);
    setMsg(null);
    try {
      const res = await fetch("/api/campaigns", {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=utf-8" },
        body: JSON.stringify(buildPayload()),
      });
      const data = (await res.json()) as Campaign & { error?: string };
      if (!res.ok) {
        setErr(data.error ?? `Save failed (${res.status})`);
        return;
      }
      router.push("/campaigns");
      router.refresh();
    } catch {
      setErr("Network error while saving campaign");
    } finally {
      setSaving(false);
    }
  }

  return (
    <form onSubmit={save} className="rounded-xl border border-slate-200 bg-white p-5 shadow-card">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="text-sm font-semibold text-brand-primary">Create campaign</h2>
        <Link href="/campaigns" className="text-xs font-medium text-slate-500 hover:text-brand-secondary">
          ← Back
        </Link>
      </div>

      <div className="mt-4 grid gap-4">
        <div className="grid gap-3 sm:grid-cols-2">
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Role title"
            className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-brand-secondary"
          />
          <select
            value={status}
            onChange={(e) => setStatus(e.target.value as CampaignStatus)}
            className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-brand-secondary"
          >
            {CREATE_STATUSES.map((s) => (
              <option key={s} value={s}>
                {s.charAt(0).toUpperCase() + s.slice(1)}
              </option>
            ))}
          </select>
          <input
            value={client}
            onChange={(e) => setClient(e.target.value)}
            placeholder="Client / company"
            className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-brand-secondary"
          />
          <input
            value={hiringManager}
            onChange={(e) => setHiringManager(e.target.value)}
            placeholder="Hiring manager"
            className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-brand-secondary"
          />
          <input
            value={location}
            onChange={(e) => setLocation(e.target.value)}
            placeholder="Location (e.g. Remote)"
            className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-brand-secondary"
          />
          <input
            value={headcount}
            onChange={(e) => setHeadcount(e.target.value)}
            placeholder="Headcount"
            type="number"
            min={1}
            className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-brand-secondary"
          />
          <input
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
            type="date"
            className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-brand-secondary"
          />
          <input
            value={endDate}
            onChange={(e) => setEndDate(e.target.value)}
            type="date"
            className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-brand-secondary"
          />
          <input
            value={tags}
            onChange={(e) => setTags(e.target.value)}
            placeholder="Tags (comma-separated)"
            className="sm:col-span-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-brand-secondary"
          />
          <input
            value={ownerId}
            onChange={(e) => setOwnerId(e.target.value)}
            placeholder="Owner / recruiter ID"
            className="sm:col-span-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-brand-secondary"
          />
        </div>

        <textarea
          ref={textareaRef}
          value={jdText}
          onChange={(e) => setJdText(e.target.value)}
          placeholder="Job description…"
          rows={14}
          className="rounded-lg border border-slate-200 bg-white px-3 py-2 font-mono text-[13px] leading-relaxed outline-none focus:border-brand-secondary"
        />

        <div className="rounded-lg border border-brand-secondary/30 bg-brand-secondary/5 p-3">
          <div className="flex flex-wrap items-center gap-2">
            <input
              value={instruction}
              onChange={(e) => setInstruction(e.target.value)}
              placeholder="Optional AI instruction"
              className="min-w-[220px] flex-1 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-brand-secondary"
            />
            <button
              type="button"
              onClick={() => void improveWithAI()}
              disabled={aiBusy}
              className="inline-flex items-center gap-1.5 rounded-lg bg-brand-secondary px-4 py-2 text-sm font-semibold text-white hover:bg-brand-secondary/90 disabled:opacity-50"
            >
              {aiBusy ? "Improving…" : "Improve with AI"}
            </button>
          </div>
        </div>

        {ai && (
          <div className="rounded-lg border border-slate-200 bg-slate-50 p-3">
            {ai.summary && <p className="text-[13px] text-slate-700">{ai.summary}</p>}
            {ai.suggestedSkills.length > 0 && (
              <div className="mt-2 flex flex-wrap gap-1.5">
                {ai.suggestedSkills.map((s, i) => {
                  const added = addedSkills.has(s.trim().toLowerCase());
                  return (
                    <button
                      key={`sk-${i}`}
                      type="button"
                      onClick={() => appendSkill(s)}
                      disabled={added}
                      className="rounded-full border border-brand-primary/20 bg-brand-primary/5 px-2.5 py-1 text-[12px] font-medium text-brand-primary"
                    >
                      {added ? "✓ " : "+ "}
                      {s}
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        )}

        <div className="flex flex-wrap items-center gap-3">
          <button
            type="submit"
            disabled={saving}
            className="rounded-lg bg-brand-primary px-4 py-2 text-sm font-semibold text-white hover:bg-brand-primary/90 disabled:opacity-50"
          >
            {saving ? "Saving…" : "Create campaign"}
          </button>
          <Link href="/campaigns" className="rounded-lg border border-slate-200 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50">
            Cancel
          </Link>
          {msg && <span className="text-sm text-emerald-600">{msg}</span>}
          {err && <span className="text-sm text-rose-600">{err}</span>}
        </div>
      </div>
    </form>
  );
}
