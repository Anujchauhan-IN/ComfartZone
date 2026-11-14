import type { FeedPost } from '../../lib/feed';
import { TOPIC_LABELS, TYPE_LABELS } from '../../lib/feed';
import InteractionControls from '../interactive/InteractionControls';

interface Props { post: FeedPost; detailed?: boolean }
export default function PostCard({ post, detailed = false }: Props) {
  const detailHref = post.localOnly ? undefined : `/post/${post.id}`;
  return <article className={`post-card post-card--${post.type} ${detailed ? 'post-card--detail' : ''}`} aria-labelledby={`post-${post.id}`}>
    <div className="post-card__meta">
      <span className={`type-badge type-badge--${post.type}`}>{TYPE_LABELS[post.type]}</span>
      {post.topic && <span className="topic-badge">{TOPIC_LABELS[post.topic]}</span>}
      {post.localOnly && <span className="topic-badge">Local preview</span>}
      <span className="post-card__time">{post.timestamp}</span>
    </div>
    {detailHref && !detailed ? <a className="post-link" href={detailHref}><p id={`post-${post.id}`} className="post-card__copy">{post.content}</p></a> : <p id={`post-${post.id}`} className="post-card__copy">{post.content}</p>}
    <InteractionControls post={post} detailed={detailed} />
    <footer className="post-card__footer">
      {detailHref && !detailed ? <a className="comment-link" href={detailHref}><span aria-hidden="true">◯</span>{post.commentCount} {post.commentCount === 1 ? 'comment' : 'comments'}</a> : <span>{post.commentCount} {post.commentCount === 1 ? 'comment' : 'comments'}</span>}
      <span className="prototype-note">Local demo · resets on refresh</span>
    </footer>
  </article>;
}
