import { useId, useMemo, useRef, useState } from 'react';
import type { SyntheticEvent } from 'react';
import type { CommentFixture } from '../../lib/feed';
import { COMMENT_LIMITS } from '../../lib/feed';

interface Props { initialComments: CommentFixture[] }
interface ComposerProps { replyTo?: string; onCancel?: () => void; onAdd: (content: string) => void }

function CommentComposer({ replyTo, onCancel, onAdd }: ComposerProps) {
  const id = useId();
  const [content, setContent] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const [busy, setBusy] = useState(false);
  const trimmed = content.trim();
  const valid = trimmed.length >= COMMENT_LIMITS.min && trimmed.length <= COMMENT_LIMITS.max;
  const submit = (event: SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault(); setSubmitted(true); if (!valid || busy) return;
    setBusy(true); onAdd(trimmed); setContent(''); setSubmitted(false); setBusy(false);
  };
  return (
    <form className={replyTo ? 'mt-3 rounded-input bg-surface-muted p-3' : 'surface p-4'} onSubmit={submit} noValidate>
      <label className="text-sm font-extrabold" htmlFor={id}>{replyTo ? 'Write a reply' : 'Write a comment'}</label>
      <textarea id={id} className="mt-2 min-h-24 w-full resize-y rounded-input border border-line bg-surface p-3 text-sm leading-6" maxLength={COMMENT_LIMITS.max} value={content} onChange={(event) => setContent(event.target.value)} aria-invalid={submitted && !valid} />
      <div className="mt-2 flex items-center justify-between gap-3 text-xs text-ink-muted"><span>{submitted && !valid ? 'Write something before submitting.' : 'Local only; resets on refresh.'}</span><span>{content.length} / {COMMENT_LIMITS.max}</span></div>
      <div className="mt-3 flex justify-end gap-2">{onCancel && <button className="button-secondary" type="button" onClick={onCancel}>Cancel</button>}<button className="button-primary" type="submit" disabled={!valid || busy}>{busy ? 'Adding…' : replyTo ? 'Add reply' : 'Add comment'}</button></div>
    </form>
  );
}

interface ItemProps { comment: CommentFixture; onReply: (id: string, content: string) => void; onDelete: (id: string) => void }
function CommentItem({ comment, onReply, onDelete }: ItemProps) {
  const [replying, setReplying] = useState(false);
  return (
    <article className="comment-item">
      <div className="flex items-center justify-between gap-3"><span className="text-xs font-bold text-ink-muted">Anonymous</span><time className="text-xs text-ink-muted">{comment.timestamp}</time></div>
      <p className="mt-2 whitespace-pre-line break-words text-sm leading-6">{comment.content}</p>
      <div className="mt-2 flex items-center gap-3 text-xs font-bold">
        <button className="text-button" type="button" onClick={() => setReplying((value) => !value)}>Reply</button>
        {comment.localOnly && <button className="text-button text-danger" type="button" onClick={() => onDelete(comment.id)}>Delete local comment</button>}
        <details className="relative ml-auto"><summary className="cursor-pointer text-ink-muted">More</summary><div className="action-menu">Reporting is unavailable in this local prototype.</div></details>
      </div>
      {replying && <CommentComposer replyTo={comment.id} onCancel={() => setReplying(false)} onAdd={(content) => { onReply(comment.id, content); setReplying(false); }} />}
      {comment.replies?.length ? <div className="reply-list">{comment.replies.map((reply) => <article className="comment-item comment-item--reply" key={reply.id}><div className="flex items-center justify-between gap-3"><span className="text-xs font-bold text-ink-muted">Anonymous</span><time className="text-xs text-ink-muted">{reply.timestamp}</time></div><p className="mt-2 whitespace-pre-line break-words text-sm leading-6">{reply.content}</p>{reply.localOnly && <button className="text-button mt-2 text-xs text-danger" type="button" onClick={() => onDelete(reply.id)}>Delete local reply</button>}</article>)}</div> : null}
    </article>
  );
}

export default function CommentsSection({ initialComments }: Props) {
  const [comments, setComments] = useState(initialComments);
  const statusRef = useRef<HTMLParagraphElement>(null);
  const total = useMemo(() => comments.reduce((sum, comment) => sum + 1 + (comment.replies?.length ?? 0), 0), [comments]);
  const makeLocal = (content: string): CommentFixture => ({ id: `local-comment-${Date.now()}-${Math.random().toString(36).slice(2)}`, content, timestamp: 'just now', localOnly: true });
  const announce = (message: string) => { if (statusRef.current) statusRef.current.textContent = message; };
  const addRoot = (content: string) => { setComments((current) => [...current, makeLocal(content)]); announce('Local comment added.'); };
  const addReply = (id: string, content: string) => { setComments((current) => current.map((comment) => comment.id === id ? { ...comment, replies: [...(comment.replies ?? []), makeLocal(content)] } : comment)); announce('Local reply added.'); };
  const remove = (id: string) => { setComments((current) => current.flatMap((comment) => comment.id === id ? [] : [{ ...comment, replies: comment.replies?.filter((reply) => reply.id !== id) }])); announce('Local comment removed.'); };
  return (
    <section aria-labelledby="comments-heading" className="space-y-3">
      <div className="flex items-end justify-between gap-3"><div><p className="text-xs font-bold uppercase tracking-wider text-ink-muted">Discussion prototype</p><h2 id="comments-heading" className="mt-1 text-xl font-extrabold">Comments</h2></div><span className="text-sm text-ink-muted">{total} shown</span></div>
      <CommentComposer onAdd={addRoot} />
      <p ref={statusRef} className="sr-only" aria-live="polite" />
      {comments.length ? <div className="surface divide-y divide-line px-4">{comments.map((comment) => <CommentItem comment={comment} onReply={addReply} onDelete={remove} key={comment.id} />)}</div> : <section className="surface p-6 text-center"><h3 className="font-extrabold">No comments yet.</h3><p className="mt-1 text-sm text-ink-muted">A perfectly good opportunity to make things more complicated.</p></section>}
    </section>
  );
}
