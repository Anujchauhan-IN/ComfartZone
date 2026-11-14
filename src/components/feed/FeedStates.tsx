interface StateProps {
  onReset?: () => void;
}

export function EmptyState({ onReset }: StateProps) {
  return (
    <section className="surface px-5 py-10 text-center" aria-labelledby="empty-feed-heading">
      <div className="mx-auto grid h-14 w-14 place-items-center rounded-full bg-accent-soft text-2xl" aria-hidden="true">·_·</div>
      <h2 id="empty-feed-heading" className="mt-4 text-lg font-extrabold">Nothing fits those filters.</h2>
      <p className="mt-2 text-sm text-ink-muted">A rare moment of peace. Suspicious, honestly.</p>
      {onReset && <button className="button-secondary mt-5" type="button" onClick={onReset}>Clear filters</button>}
    </section>
  );
}

export function ErrorState({ onReset }: StateProps) {
  return (
    <section className="surface px-5 py-10 text-center" role="alert">
      <h2 className="text-lg font-extrabold">The feed tripped over its own shoelaces.</h2>
      <p className="mt-2 text-sm text-ink-muted">Try resetting the local prototype.</p>
      {onReset && <button className="button-secondary mt-5" type="button" onClick={onReset}>Try again</button>}
    </section>
  );
}

export function LoadingState() {
  return (
    <div className="space-y-3" aria-label="Loading posts" aria-busy="true">
      {[0, 1].map((item) => (
        <div className="surface animate-pulse p-4" key={item}>
          <div className="h-5 w-32 rounded bg-surface-muted" />
          <div className="mt-4 h-4 rounded bg-surface-muted" />
          <div className="mt-2 h-4 w-4/5 rounded bg-surface-muted" />
          <div className="mt-5 h-10 rounded-input bg-surface-muted" />
        </div>
      ))}
    </div>
  );
}
