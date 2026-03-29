import type { Metadata } from "next";
import { PageHeader } from "@/components/PageHeader";
import { ThemeSwitcher } from "@/components/ThemeSwitcher";

export const metadata: Metadata = {
  title: "Preferences",
  description: "Appearance and workspace settings for CV repository.",
};

export default function PreferencesPage() {
  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        eyebrow="Workspace"
        title="Preferences"
        description="Customize how the app looks. Your theme choice is saved in this browser."
      />
      <section
        aria-labelledby="pref-appearance-heading"
        className="rounded-xl border border-slate-200 bg-white/80 p-5 shadow-sm dark:border-slate-700 dark:bg-slate-900/40"
      >
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2
              id="pref-appearance-heading"
              className="text-sm font-semibold text-slate-900 dark:text-slate-100"
            >
              Appearance
            </h2>
            <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
              Light, dark, or match your system setting.
            </p>
          </div>
          <ThemeSwitcher />
        </div>
      </section>
    </div>
  );
}
