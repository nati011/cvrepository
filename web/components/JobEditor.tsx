"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import type { Job, JDImprovement } from "@/lib/types";

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

type Props = {
  jobId?: string;
};

export function JobEditor({ jobId }: Props) {
  const router = useRouter();
  const isEdit = Boolean(jobId);

  const [title, setTitle] = useState("");
  const [jdText, setJdText] = useState("");
  const [instruction, setInstruction] = useState("");
  const [loading, setLoading] = useState(isEdit);
  const [aiBusy, setAiBusy] = useState(false);
  const [ai, setAi] = useState<AIResult | null>(null);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [addedSkills, setAddedSkills] = useState<Set<string>>(new Set());
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (!jobId) return;
    let cancelled = false;
    async function load() {
      try {
        const res = await fetch(`/api/jobs/${jobId}`, { cache: "no-store" });
        const data = (await res.json()) as Job & { error?: string };
        if (!res.ok) {
          if (!cancelled) setErr(data.error ?? "Failed to load job");
          return;
        }
        if (!cancelled) {
          setTitle(data.title);
          setJdText(data.jd_text);
        }
      } catch {
        if (!cancelled) setErr("Network error while loading job");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    void load();
    return () => {
      cancelled = true;
    };
  }, [jobId]);

  async function improveWithAI() {
    if (!title.trim() && !jdText.trim()) {
      setErr("Add a title or some description first, then let AI improve it.");
      return;
    }
    setAiBusy(true);
    setErr(null);
    setMsg(null);
    try {
      const res = await fetch("/api/jobs/improve", {
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
      const payload = { title: title.trim(), jd_text: jdText.trim() };
      const res = await fetch(isEdit ? `/api/jobs/${jobId}` : "/api/jobs", {
        method: isEdit ? "PUT" : "POST",
        headers: { "Content-Type": "application/json; charset=utf-8" },
        body: JSON.stringify(payload),
      });
      const data = (await res.json()) as Job & { error?: string };
      if (!res.ok) {
        setErr(data.error ?? `Save failed (${res.status})`);
        return;
      }
      router.push(isEdit ? `/jobs/${jobId}` : "/jobs");
      router.refresh();
    } catch {
      setErr("Network error while saving job");
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return <p className="text-sm text-slate-500">Loading job…</p>;
  }

  return (
    <form onSubmit={save} className="rounded-xl border border-slate-200 bg-white p-5 shadow-card">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="text-sm font-semibold text-brand-primary">
          {isEdit ? "Edit job" : "Create job"}
        </h2>
        <Link href={isEdit ? `/jobs/${jobId}` : "/jobs"} className="text-xs font-medium text-slate-500 hover:text-brand-secondary">
          ← Back
        </Link>
      </div>

      <div className="mt-4 grid gap-4">
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Role title"
          className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-brand-secondary"
        />

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
            {saving ? "Saving…" : isEdit ? "Save changes" : "Create job"}
          </button>
          <Link
            href={isEdit ? `/jobs/${jobId}` : "/jobs"}
            className="rounded-lg border border-slate-200 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
          >
            Cancel
          </Link>
          {msg && <span className="text-sm text-emerald-600">{msg}</span>}
          {err && <span className="text-sm text-rose-600">{err}</span>}
        </div>
      </div>
    </form>
  );
}
