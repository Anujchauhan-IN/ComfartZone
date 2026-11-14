interface Props { className?: string }
export default function MascotIcon({ className = 'h-12 w-12' }: Props) {
  return <svg aria-hidden="true" className={className} viewBox="0 0 40 40" fill="none"><path d="M10.5 10.2c2.2-4.4 8.6-6.6 13.5-4.9 4.1 1.4 7.8 5.8 7.3 10.2 4 2.6 4.2 9 .6 12-3.1 2.6-7.2 2.1-10.3 3.2-4.1 1.5-9.5 1.2-12.4-2.4-2.2-2.8-2-6.7-.5-9.5-1.2-2.8.1-6.3 1.8-8.6Z" fill="currentColor" stroke="var(--text)" strokeWidth="2.2" strokeLinejoin="round"/><path d="m14.6 16.5 3.1-1.1M25.4 15.4l3 1.2" stroke="var(--text)" strokeWidth="2" strokeLinecap="round"/><circle cx="17" cy="19" r="1.3" fill="var(--text)"/><circle cx="27" cy="19" r="1.3" fill="var(--text)"/><path d="M19.2 24.5c1.8-1 3.8-1 5.6 0" stroke="var(--text)" strokeWidth="2" strokeLinecap="round"/></svg>;
}
