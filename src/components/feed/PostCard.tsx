import type { FeedPost } from '../../lib/feed';
import { TOPIC_LABELS, TYPE_LABELS } from '../../lib/feed';
import InteractionControls from '../interactive/InteractionControls';

interface Props { post: FeedPost; detailed?: boolean }

export default function PostCard({ post, detailed = false }: Props) {
  const detailHref = post.localOnly ? undefined : `/post/${post.id}`;
  return (
    <article className={`surface overflow-hidden ${detailed ? 'p-5 sm:p-6' : 'p-4 sm:p-5'}`} aria-labelledby={`post-${post.id}`}>
      <div className="flex flex-wrap items-center gap-2 text-xs text-ink-muted">
        <span className={`type-badge type-badge--${post.type}`}>{TYPE_LABELS[post.type]}</span>
        {post.topic && <span className="topic-badge">{TOPIC_LABELS[post.topic]}</span>}
        {post.localOnly && <span className="topic-badge">Local preview</span>}
        <span className="ml-auto whitespace-nowrap">{post.timestamp}</span>
      </div>
      {detailHref && !detailed ? (
        <a className="post-link" href={detailHref}><p id={`post-${post.id}`} className="mt-3 whitespace-pre-line break-words text-[0.98rem] leading-6">{post.content}</p></a>
      ) : (
        <p id={`post-${post.id}`} className={`mt-3 whitespace-pre-line break-words leading-6 ${detailed ? 'text-[1.05rem]' : 'text-[0.98rem]'}`}>{post.content}</p>
      )}
      <InteractionControls post={post} detailed={detailed} />
      <div className="mt-4 flex items-center justify-between border-t border-line pt-3 text-sm text-ink-muted">
        {detailHref && !detailed ? <a className="text-link" href={detailHref}>{post.commentCount} {post.commentCount === 1 ? 'comment' : 'comments'}</a> : <span>{post.commentCount} {post.commentCount === 1 ? 'comment' : 'comments'}</span>}
        <span className="text-xs">Local demo interaction</span>
      </div>
    </article>
  );
}
