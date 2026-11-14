import { useState } from 'react';
import type { CommentFixture, FeedPost } from '../../lib/feed';
import CommentsSection from '../comments/CommentsSection';
import PostCard from '../feed/PostCard';

interface Props { post: FeedPost; comments: CommentFixture[] }
export default function PostDetailExperience({ post, comments }: Props) {
  const [shareStatus, setShareStatus] = useState('');
  const copyLink = async () => {
    try { await navigator.clipboard.writeText(window.location.href); setShareStatus('Link copied.'); }
    catch { setShareStatus('Could not copy automatically. Use your browser address bar.'); }
  };
  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between gap-3"><a className="text-link text-sm" href="/">← Back to feed</a><button className="button-secondary" type="button" onClick={copyLink}>Copy link</button></div>
      <p className="rounded-input border border-line bg-accent-soft px-3 py-2 text-xs leading-5">Prototype page: votes, reactions and comments are local to this tab and reset on reload.</p>
      <PostCard post={post} detailed />
      <p className="sr-only" aria-live="polite">{shareStatus}</p>
      {shareStatus && <p className="text-center text-xs text-ink-muted">{shareStatus}</p>}
      <CommentsSection initialComments={comments} />
    </div>
  );
}
