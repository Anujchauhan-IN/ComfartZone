import { useEffect, useId, useRef, useState } from 'react';
import type { RefObject, SyntheticEvent } from 'react';
import type { NewPostInput, PostType, Topic } from '../../lib/feed';
import { POST_LIMITS, POST_TYPE_OPTIONS, TOPIC_OPTIONS } from '../../lib/feed';

const typeDescriptions: Record<PostType, string> = {
  confession: 'Get it off your chest.', petty_court: 'Let the people judge.', am_i_weird: 'Request a peer review.', hot_take: 'Say the quiet part aloud.',
};

interface Props {
  open: boolean;
  onClose: () => void;
  onSubmit: (post: NewPostInput) => void;
  returnFocusRef: RefObject<HTMLButtonElement | null>;
}

export default function PostComposer({ open, onClose, onSubmit, returnFocusRef }: Props) {
  const titleId = useId();
  const descriptionId = useId();
  const closeRef = useRef<HTMLButtonElement>(null);
  const dialogRef = useRef<HTMLElement>(null);
  const contentRef = useRef('');
  const [type, setType] = useState<PostType>('confession');
  const [topic, setTopic] = useState<Topic | 'none'>('none');
  const [content, setContent] = useState('');
  const [submitted, setSubmitted] = useState(false);
  contentRef.current = content;
  const trimmedLength = content.trim().length;
  const valid = trimmedLength >= POST_LIMITS.min && trimmedLength <= POST_LIMITS.max;

  const requestClose = () => {
    if (contentRef.current.trim() && !window.confirm('Discard this local draft?')) return;
    onClose();
    returnFocusRef.current?.focus();
  };

  useEffect(() => {
    if (!open) return;
    closeRef.current?.focus();
    document.body.style.overflow = 'hidden';
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') requestClose();
      if (event.key === 'Tab' && dialogRef.current) {
        const focusable = [...dialogRef.current.querySelectorAll<HTMLElement>('button:not([disabled]), select, textarea')];
        if (!focusable.length) return;
        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
        if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => { window.removeEventListener('keydown', handleKeyDown); document.body.style.overflow = ''; };
  }, [open]);

  if (!open) return null;
  const submit = (event: SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    setSubmitted(true);
    if (!valid) return;
    onSubmit({ type, topic: topic === 'none' ? undefined : topic, content: content.trim() });
    setContent(''); setTopic('none'); setType('confession'); setSubmitted(false);
    onClose(); returnFocusRef.current?.focus();
  };

  return (
    <div className="dialog-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) requestClose(); }}>
      <section ref={dialogRef} className="composer-dialog" role="dialog" aria-modal="true" aria-labelledby={titleId} aria-describedby={descriptionId}>
        <div className="composer-dialog__header">
          <div><p className="eyebrow">Local prototype</p><h2 id={titleId}>Spill it</h2></div>
          <button ref={closeRef} className="icon-button" type="button" aria-label="Close composer" onClick={requestClose}>×</button>
        </div>
        <p id={descriptionId} className="composer-dialog__description">Your post is added to this tab only and disappears on refresh.</p>
        <form className="composer-form" onSubmit={submit} noValidate>
          <fieldset><legend className="text-sm font-extrabold">Choose a post type</legend>
            <div className="mt-2 grid grid-cols-2 gap-2">
              {POST_TYPE_OPTIONS.filter((option) => option.value !== 'all').map((option) => (
                <label className="type-choice" key={option.value}><input type="radio" name="post-type" value={option.value} checked={type === option.value} onChange={() => setType(option.value)} /><span><strong>{option.label}</strong><small>{typeDescriptions[option.value]}</small></span></label>
              ))}
            </div>
          </fieldset>
          <label className="field-label">Topic (optional)<select className="field-control" value={topic} onChange={(event) => setTopic(event.target.value as Topic | 'none')}>
            <option value="none">No topic</option>{TOPIC_OPTIONS.filter((option) => option.value !== 'all').map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}
          </select></label>
          <div><label className="text-sm font-extrabold" htmlFor="post-content">What happened?</label>
            <textarea id="post-content" className="composer-textarea" maxLength={POST_LIMITS.max} value={content} onChange={(event) => setContent(event.target.value)} aria-invalid={(submitted || content.length > 0) && !valid} aria-describedby="post-validation post-counter" />
            <div className="mt-2 flex items-start justify-between gap-3 text-xs"><span id="post-validation" className={content.length > 0 && !valid ? 'text-danger' : 'text-ink-muted'}>{content.length > 0 && !valid ? `${Math.max(0, POST_LIMITS.min - trimmedLength)} more characters needed.` : 'Plain text only. Nothing is permanently saved.'}</span><span id="post-counter" className="shrink-0 text-ink-muted">{content.length} / {POST_LIMITS.max}</span></div>
          </div>
          <div className="flex justify-end gap-2"><button className="button-secondary" type="button" onClick={requestClose}>Cancel</button><button className="button-primary" type="submit" disabled={!valid}>Add local preview</button></div>
        </form>
      </section>
    </div>
  );
}
