import { useEffect, useId, useRef, useState } from 'react';
import type { ChangeEvent, ReactNode, RefObject, SyntheticEvent } from 'react';
import type { ExpiryAction, LocalAttachment, NewPostInput, PostType, Topic } from '../../lib/feed';
import { MAX_MEDIA_BYTES, POST_FORMAT_OPTIONS, POST_LIMITS, TOPIC_LABELS, TOPIC_OPTIONS, TYPE_LABELS } from '../../lib/feed';

interface Props {
  open: boolean;
  onOpen: (trigger?: HTMLElement | null) => void;
  onClose: () => void;
  onSubmit: (post: NewPostInput) => void;
  returnFocusRef: RefObject<HTMLElement | null>;
}

type ToolIconName = 'format' | 'topic' | 'clock' | 'image' | 'anonymous';
type MenuName = ToolIconName | null;
type Duration = 'normal' | ExpiryAction;

const iconPaths: Record<ToolIconName, ReactNode> = {
  format: <><path d="M4 6h16M4 12h10M4 18h7" /><circle cx="18" cy="15" r="3" /></>,
  topic: <path d="M20 13 13 20 4 11V4h7l9 9Z M8 8h.01" />,
  clock: <><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></>,
  image: <><rect x="3" y="5" width="18" height="14" rx="2" /><path d="m3 16 5-5 4 4 2-2 7 6M8.5 9h.01" /></>,
  anonymous: <><circle cx="9" cy="11" r="3" /><circle cx="17" cy="11" r="3" /><path d="M12 11h2M3 9l2-1M21 9l-2-1M7 15c1.5 1 3.5 1 5 0" /></>,
};

function ToolIcon({ name }: { name: ToolIconName }) {
  return <svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round">{iconPaths[name]}</svg>;
}

function graphemes(value: string): string[] {
  if (typeof Intl !== 'undefined' && 'Segmenter' in Intl) {
    const segmenter = new Intl.Segmenter(undefined, { granularity: 'grapheme' });
    return Array.from(segmenter.segment(value), ({ segment }) => segment);
  }
  return Array.from(value);
}

function MenuOption({ selected, children, onClick }: { selected: boolean; children: ReactNode; onClick: () => void }) {
  return <button className="composer-menu__option" type="button" aria-pressed={selected} onClick={onClick}><span>{children}</span>{selected && <span aria-hidden="true">✓</span>}</button>;
}

export default function PostComposer({ open, onOpen, onClose, onSubmit, returnFocusRef }: Props) {
  const titleId = useId();
  const rootRef = useRef<HTMLElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [activeMenu, setActiveMenu] = useState<MenuName>(null);
  const [type, setType] = useState<PostType>('regular');
  const [topic, setTopic] = useState<Topic | 'none'>('none');
  const [content, setContent] = useState('');
  const [anonymous, setAnonymous] = useState(false);
  const [duration, setDuration] = useState<Duration>('normal');
  const [attachment, setAttachment] = useState<LocalAttachment | null>(null);
  const [altText, setAltText] = useState('');
  const [mediaError, setMediaError] = useState('');
  const [submitted, setSubmitted] = useState(false);

  const trimmedContent = content.trim();
  const graphemeCount = graphemes(trimmedContent).length;
  const remaining = POST_LIMITS.max - graphemeCount;
  const hasContent = graphemeCount >= POST_LIMITS.min;
  const attachmentNeedsAlt = Boolean(attachment && !hasContent && !altText.trim());
  const valid = (hasContent || attachment) && graphemeCount <= POST_LIMITS.max && !attachmentNeedsAlt && !mediaError;
  const hasDraft = Boolean(content || attachment || topic !== 'none' || type !== 'regular' || anonymous || duration !== 'normal');

  const closeComposer = () => {
    setActiveMenu(null);
    onClose();
    requestAnimationFrame(() => returnFocusRef.current?.focus());
  };

  useEffect(() => {
    if (!open) return;
    requestAnimationFrame(() => textareaRef.current?.focus());
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return;
      if (activeMenu) setActiveMenu(null);
      else closeComposer();
    };
    const closeMenuOutside = (event: PointerEvent) => {
      if (activeMenu && event.target instanceof Element && !event.target.closest('.composer-toolbar')) setActiveMenu(null);
    };
    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('pointerdown', closeMenuOutside);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('pointerdown', closeMenuOutside);
    };
  }, [open, activeMenu]);

  useEffect(() => {
    if (!open || !hasDraft) return;
    const warnBeforeUnload = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener('beforeunload', warnBeforeUnload);
    return () => window.removeEventListener('beforeunload', warnBeforeUnload);
  }, [open, hasDraft]);

  const toggleMenu = (menu: ToolIconName) => setActiveMenu((current) => current === menu ? null : menu);

  const chooseAttachment = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;
    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
    if (!allowed.includes(file.type)) {
      setMediaError('Choose a JPEG, PNG, WebP or GIF.');
      event.target.value = '';
      return;
    }
    if (file.size > MAX_MEDIA_BYTES) {
      setMediaError('That file is over 2 MB.');
      event.target.value = '';
      return;
    }
    if (attachment) URL.revokeObjectURL(attachment.previewUrl);
    setAttachment({ name: file.name, type: file.type, size: file.size, previewUrl: URL.createObjectURL(file) });
    setMediaError('');
    setActiveMenu(null);
  };

  const removeAttachment = () => {
    if (attachment) URL.revokeObjectURL(attachment.previewUrl);
    setAttachment(null);
    setAltText('');
    setMediaError('');
    if (fileInputRef.current) fileInputRef.current.value = '';
  };

  const submit = (event: SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    setSubmitted(true);
    if (!valid) return;
    const expiresIn24Hours = duration !== 'normal';
    onSubmit({
      type,
      topic: topic === 'none' ? undefined : topic,
      content: trimmedContent,
      anonymous,
      expiresIn24Hours,
      expiryAction: expiresIn24Hours ? duration : undefined,
      attachment: attachment ? { ...attachment, altText: altText.trim() || undefined } : undefined,
    });
    setContent('');
    setTopic('none');
    setType('regular');
    setAnonymous(false);
    setDuration('normal');
    setAttachment(null);
    setAltText('');
    setMediaError('');
    setSubmitted(false);
    setActiveMenu(null);
    if (fileInputRef.current) fileInputRef.current.value = '';
    closeComposer();
  };

  const validationMessage = graphemeCount > POST_LIMITS.max
    ? `${graphemeCount - POST_LIMITS.max} over the limit.`
    : attachmentNeedsAlt
      ? 'Add alt text when posting an image without text.'
      : submitted && !hasContent && !attachment
        ? 'Write something or attach an image.'
        : '';

  const topicLabel = topic === 'none' ? 'No topic' : TOPIC_LABELS[topic];
  const durationLabel = duration === 'normal' ? 'Normal' : duration === 'archive_private' ? '24h archive' : '24h delete';
  const hasNonDefaultSelection = type !== 'regular' || topic !== 'none' || duration !== 'normal' || anonymous || Boolean(attachment);

  if (!open) {
    return (
      <section ref={rootRef} className="inline-composer inline-composer--collapsed" aria-labelledby={titleId}>
        <h1 id={titleId}>What ruined your day today?</h1>
        <div className="inline-composer__collapsed-row">
          <button ref={(node) => { if (node) returnFocusRef.current = node; }} className="composer-trigger" type="button" onClick={(event) => onOpen(event.currentTarget)}>Go on…</button>
          <button className="button-primary spill-button" type="button" onClick={(event) => onOpen(event.currentTarget)}><span aria-hidden="true">➤</span> Spill it</button>
        </div>
      </section>
    );
  }

  return (
    <section ref={rootRef} className="inline-composer inline-composer--expanded" aria-labelledby={titleId}>
      <div className="inline-composer__heading">
        <h1 id={titleId}>What ruined your day today?</h1>
        <button className="text-button inline-composer__collapse" type="button" onClick={closeComposer}>Collapse</button>
      </div>
      <form className="composer-form" onSubmit={submit} noValidate>
        <label className="sr-only" htmlFor="post-content">What ruined your day today?</label>
        <textarea
          ref={textareaRef}
          id="post-content"
          name="post-content"
          autoComplete="off"
          placeholder="What ruined your day today?"
          className="composer-textarea"
          value={content}
          onChange={(event) => setContent(event.target.value)}
          aria-invalid={Boolean(validationMessage)}
          aria-describedby="post-validation post-counter"
        />

        <div className="composer-toolbar">
          <div className="composer-tools" aria-label="Post options">
            <button className={`composer-tool ${type !== 'regular' ? 'composer-tool--selected' : ''}`} type="button" aria-label={`Format: ${TYPE_LABELS[type]}`} aria-expanded={activeMenu === 'format'} onClick={() => toggleMenu('format')}>
              <ToolIcon name="format" />{type !== 'regular' && <span className="composer-tool__indicator" aria-hidden="true"></span>}
            </button>
            <button className={`composer-tool ${topic !== 'none' ? 'composer-tool--selected' : ''}`} type="button" aria-label={`Topic: ${topicLabel}`} aria-expanded={activeMenu === 'topic'} onClick={() => toggleMenu('topic')}>
              <ToolIcon name="topic" />{topic !== 'none' && <span className="composer-tool__indicator" aria-hidden="true"></span>}
            </button>
            <button className={`composer-tool ${duration !== 'normal' ? 'composer-tool--selected' : ''}`} type="button" aria-label={`Duration: ${durationLabel}`} aria-expanded={activeMenu === 'clock'} onClick={() => toggleMenu('clock')}>
              <ToolIcon name="clock" />{duration !== 'normal' && <span className="composer-tool__indicator" aria-hidden="true"></span>}
            </button>
            <button className={`composer-tool ${attachment ? 'composer-tool--selected' : ''}`} type="button" aria-label={attachment ? `Image attached: ${attachment.name}` : 'Attach image or GIF'} aria-expanded={activeMenu === 'image'} onClick={() => toggleMenu('image')}>
              <ToolIcon name="image" />{attachment && <span className="composer-tool__indicator" aria-hidden="true"></span>}
            </button>
            <button className={`composer-tool ${anonymous ? 'composer-tool--selected' : ''}`} type="button" aria-label={anonymous ? 'Identity: Anonymous' : 'Identity: Public pseudonym'} aria-expanded={activeMenu === 'anonymous'} onClick={() => toggleMenu('anonymous')}>
              <ToolIcon name="anonymous" />{anonymous && <span className="composer-tool__indicator" aria-hidden="true"></span>}
            </button>
          </div>

          {activeMenu && (
            <div className={`composer-menu composer-menu--${activeMenu}`} role="group" aria-label={`${activeMenu} options`}>
              {activeMenu === 'format' && POST_FORMAT_OPTIONS.map((option) => (
                <MenuOption selected={type === option.value} onClick={() => { setType(option.value); setActiveMenu(null); }} key={option.value}>{option.label}</MenuOption>
              ))}
              {activeMenu === 'topic' && <>
                <MenuOption selected={topic === 'none'} onClick={() => { setTopic('none'); setActiveMenu(null); }}>No topic</MenuOption>
                {TOPIC_OPTIONS.filter((option) => option.value !== 'all').map((option) => (
                  <MenuOption selected={topic === option.value} onClick={() => { setTopic(option.value); setActiveMenu(null); }} key={option.value}>{option.label}</MenuOption>
                ))}
              </>}
              {activeMenu === 'clock' && <>
                <MenuOption selected={duration === 'normal'} onClick={() => { setDuration('normal'); setActiveMenu(null); }}>Normal</MenuOption>
                <MenuOption selected={duration === 'archive_private'} onClick={() => { setDuration('archive_private'); setActiveMenu(null); }}>24h · Archive privately</MenuOption>
                <MenuOption selected={duration === 'delete_permanently'} onClick={() => { setDuration('delete_permanently'); setActiveMenu(null); }}>24h · Delete permanently</MenuOption>
              </>}
              {activeMenu === 'image' && <>
                <label className="composer-menu__file">
                  <span>{attachment ? 'Replace image or GIF' : 'Choose image or GIF'}</span><small>JPEG, PNG, WebP or GIF · 2 MB max</small>
                  <input ref={fileInputRef} type="file" accept="image/jpeg,image/png,image/webp,image/gif" onChange={chooseAttachment} />
                </label>
                {attachment && <button className="composer-menu__option" type="button" onClick={() => { removeAttachment(); setActiveMenu(null); }}>Remove attachment</button>}
              </>}
              {activeMenu === 'anonymous' && <>
                <MenuOption selected={!anonymous} onClick={() => { setAnonymous(false); setActiveMenu(null); }}>Public pseudonym</MenuOption>
                <MenuOption selected={anonymous} onClick={() => { setAnonymous(true); setActiveMenu(null); }}>Anonymous</MenuOption>
              </>}
            </div>
          )}
        </div>

        {hasNonDefaultSelection && (
          <div className="composer-selection" aria-live="polite">
            {type !== 'regular' && <span>{TYPE_LABELS[type]}</span>}
            {topic !== 'none' && <span>{topicLabel}</span>}
            {duration !== 'normal' && <span>{durationLabel}</span>}
            {anonymous && <span>Anonymous</span>}
            {attachment && <span>1 image</span>}
          </div>
        )}

        {attachment && (
          <div className="composer-attachment">
            <img src={attachment.previewUrl} alt="Selected upload preview" />
            <div><strong>{attachment.name}</strong><span>{Math.ceil(attachment.size / 1024)} KB</span></div>
            <button type="button" className="text-button" onClick={removeAttachment}>Remove</button>
            <label><span>Alt text{hasContent ? ' (optional)' : ''}</span><input value={altText} onChange={(event) => setAltText(event.target.value)} maxLength={300} placeholder="Describe the image" /></label>
          </div>
        )}

        {mediaError && <p className="composer-error" role="alert">{mediaError}</p>}

        <div className="composer-footer">
          <div className="composer-status">
            <span id="post-validation" className={validationMessage ? 'text-danger' : 'text-ink-muted'}>{validationMessage}</span>
            <span id="post-counter" className={remaining <= 40 ? remaining < 0 ? 'text-danger' : 'text-ink-muted' : 'composer-counter--quiet'} aria-live="polite">{remaining <= 40 ? `${remaining} left` : ''}</span>
          </div>
          <button className="button-primary" type="submit" disabled={!valid}>Spill it</button>
        </div>
      </form>
    </section>
  );
}
