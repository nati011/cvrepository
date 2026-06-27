import type { Metadata } from "next";
import { ProfileActions } from "@/components/ProfileActions";

export const metadata: Metadata = {
  title: "Profile",
  description: "Your account details in the CV repository.",
};

const profile = {
  name: "Talent Reviewer",
  initials: "TR",
  org: "Kifiya Financial Technology",
  email: "talent.reviewer@kifiya.com",
};

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5">
      <dt className="text-[11px] font-semibold uppercase tracking-wider text-slate-500">
        {label}
      </dt>
      <dd className="text-[13px] text-brand-dark">{value}</dd>
    </div>
  );
}

export default function ProfilePage() {
  return (
    <div className="flex flex-col gap-8">
      <section className="overflow-hidden rounded-2xl border border-slate-200/90 bg-white shadow-card">
        <div className="flex flex-col gap-4 bg-gradient-to-r from-brand-primary to-brand-primary/85 p-6 text-white sm:flex-row sm:items-center">
          <span className="grid h-16 w-16 shrink-0 place-items-center rounded-full bg-white/15 text-xl font-semibold ring-2 ring-brand-secondary/50">
            {profile.initials}
          </span>
          <div className="min-w-0">
            <h2 className="font-display text-xl font-semibold tracking-tight">{profile.name}</h2>
          </div>
        </div>

        <dl className="grid gap-5 p-6 sm:grid-cols-2">
          <Field label="Email" value={profile.email} />
          <Field label="Organization" value={profile.org} />
        </dl>
      </section>

      <section className="rounded-xl border border-slate-200/90 bg-white p-6 shadow-card">
        <h2 className="text-sm font-semibold text-brand-primary">Account</h2>
        <p className="mt-1 text-[13px] text-slate-500">
          Sign out of this workspace when you are done reviewing.
        </p>
        <div className="mt-4">
          <ProfileActions />
        </div>
      </section>
    </div>
  );
}
