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
  return <div className="detail-page">
    <div className="detail-nav"><a className="text-link" href="/"><span aria-hidden="true">←</span> Back to feed</a><button className="button-secondary button-with-icon" type="button" onClick={copyLink}><span aria-hidden="true">⧉</span> Copy link</button></div>
    <p className="prototype-banner"><strong>Prototype page.</strong> Votes, reactions and comments are local to this tab and reset on reload.</p>
    <PostCard post={post} detailed />
    <p className="sr-only" aria-live="polite">{shareStatus}</p>{shareStatus && <p className="share-status">{shareStatus}</p>}
    <CommentsSection initialComments={comments} />
  </div>;
}
