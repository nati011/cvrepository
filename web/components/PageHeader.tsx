export function PageHeader({
  title,
  description,
}: {
  title: string;
  description?: string;
}) {
  return (
    <header className="mb-8 border-b border-brand-primary/10 pb-8">
      <h1 className="font-display text-xl font-semibold tracking-tight text-brand-dark sm:text-2xl">
        {title}
      </h1>
      {description && (
        <p className="mt-2 max-w-2xl text-[13px] leading-relaxed text-brand-dark/70">
          {description}
        </p>
      )}
    </header>
  );
}
