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
  return <form className={replyTo ? 'comment-composer comment-composer--reply' : 'comment-composer'} onSubmit={submit} noValidate>
    <label htmlFor={id}>{replyTo ? 'Write a reply' : 'Add your two cents'}</label>
    <textarea id={id} name={replyTo ? 'reply' : 'comment'} autoComplete="off" maxLength={COMMENT_LIMITS.max} value={content} onChange={(event) => setContent(event.target.value)} aria-invalid={submitted && !valid} placeholder={replyTo ? 'Keep the thread going…' : 'Write a comment…'} />
    <div className="comment-composer__meta"><span>{submitted && !valid ? 'Write something before submitting.' : 'Plain text'}</span><span>{content.length} / {COMMENT_LIMITS.max}</span></div>
    <div className="comment-composer__actions">{onCancel && <button className="button-secondary" type="button" onClick={onCancel}>Cancel</button>}<button className="button-primary" type="submit" disabled={!valid || busy}>{busy ? 'Adding…' : replyTo ? 'Reply' : 'Add comment'}</button></div>
  </form>;
}

interface ItemProps { comment: CommentFixture; onReply: (id: string, content: string) => void; onDelete: (id: string) => void }
function CommentItem({ comment, onReply, onDelete }: ItemProps) {
  const [replying, setReplying] = useState(false);
  return <article className="comment-item">
    <div className="comment-item__head"><span className="comment-mark" aria-hidden="true">CZ</span><span>{comment.localOnly ? 'Local comment' : 'Anonymous comment'}</span><time>{comment.timestamp}</time></div>
    <p className="comment-item__copy">{comment.content}</p>
    <div className="comment-item__actions"><button className="text-button" type="button" onClick={() => setReplying((value) => !value)}>Reply</button>{comment.localOnly && <button className="text-button text-danger" type="button" onClick={() => onDelete(comment.id)}>Delete</button>}<details><summary>More</summary><div className="action-menu">Reporting is unavailable in this local prototype.</div></details></div>
    {replying && <CommentComposer replyTo={comment.id} onCancel={() => setReplying(false)} onAdd={(content) => { onReply(comment.id, content); setReplying(false); }} />}
    {comment.replies?.length ? <div className="reply-list">{comment.replies.map((reply) => <article className="comment-item comment-item--reply" key={reply.id}><div className="comment-item__head"><span className="comment-mark" aria-hidden="true">CZ</span><span>{reply.localOnly ? 'Local reply' : 'Anonymous reply'}</span><time>{reply.timestamp}</time></div><p className="comment-item__copy">{reply.content}</p>{reply.localOnly && <button className="text-button mt-2 text-xs text-danger" type="button" onClick={() => onDelete(reply.id)}>Delete</button>}</article>)}</div> : null}
  </article>;
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
  return <section aria-labelledby="comments-heading" className="comments-section">
    <div className="section-heading"><h2 id="comments-heading">Comments</h2><span>{total} shown</span></div>
    <CommentComposer onAdd={addRoot} /><p ref={statusRef} className="sr-only" aria-live="polite" />
    {comments.length ? <div className="comments-list">{comments.map((comment) => <CommentItem comment={comment} onReply={addReply} onDelete={remove} key={comment.id} />)}</div> : <section className="state-card state-card--compact"><h3>No comments yet.</h3><p>A perfectly good opportunity to make things more complicated.</p></section>}
  </section>;
}
