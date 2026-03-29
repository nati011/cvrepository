export function PageHeader({
  eyebrow,
  title,
  description,
}: {
  eyebrow?: string;
  title: string;
  description?: string;
}) {
  return (
    <header className="mb-8 border-b border-brand-primary/10 pb-8 dark:border-white/10">
      {eyebrow && (
        <p className="font-display text-xs font-semibold uppercase tracking-widest text-brand-secondary">
          {eyebrow}
        </p>
      )}
      <h1 className="font-display mt-1 text-2xl font-semibold tracking-tight text-brand-dark dark:text-white sm:text-3xl">
        {title}
      </h1>
      {description && (
        <p className="mt-2 max-w-2xl text-sm leading-relaxed text-brand-dark/70 dark:text-brand-light/80">
          {description}
        </p>
      )}
    </header>
  );
}
