import { useEffect, useMemo, useRef, useState } from 'react';
import { MOCK_POSTS } from '../../lib/mockFeed';
import type { FeedPost, FeedSort, NewPostInput, PostType, Topic } from '../../lib/feed';
import { POLL_CHOICES, TOPIC_OPTIONS } from '../../lib/feed';
import MascotIcon from '../brand/MascotIcon';
import PostComposer from '../interactive/PostComposer';
import PostCard from './PostCard';
import { EmptyState, ErrorState, LoadingState } from './FeedStates';

type TypeFilter = PostType | 'all';
type TopicFilter = Topic | 'all';
type QueryState = { type: TypeFilter; topic: TopicFilter; sort: FeedSort };
const feedTypes: TypeFilter[] = ['all', 'confession', 'petty_court', 'am_i_weird', 'hot_take'];

function validType(value: string | null): TypeFilter { return feedTypes.includes(value as TypeFilter) ? value as TypeFilter : 'all'; }
function validTopic(value: string | null): TopicFilter { return TOPIC_OPTIONS.some((option) => option.value === value) ? value as TopicFilter : 'all'; }
function validSort(value: string | null): FeedSort { return value === 'popular' || value === 'controversial' ? value : 'fresh'; }
function readQuery(): QueryState {
  const params = new URLSearchParams(window.location.search);
  return { type: validType(params.get('type')), topic: validTopic(params.get('topic')), sort: validSort(params.get('sort')) };
}
function writeQuery(next: Partial<QueryState>, mode: 'push' | 'replace' = 'push') {
  const current = readQuery();
  const value = { ...current, ...next };
  const params = new URLSearchParams();
  if (value.type !== 'all') params.set('type', value.type);
  if (value.topic !== 'all') params.set('topic', value.topic);
  if (value.sort !== 'fresh') params.set('sort', value.sort);
  const url = params.size ? `/?${params}` : '/';
  window.history[mode === 'push' ? 'pushState' : 'replaceState']({}, '', url);
  window.dispatchEvent(new Event('cz:querychange'));
}

export default function FeedExperience() {
  const [type, setType] = useState<TypeFilter>('all');
  const [topic, setTopic] = useState<TopicFilter>('all');
  const [sort, setSort] = useState<FeedSort>('fresh');
  const [composerOpen, setComposerOpen] = useState(false);
  const [localPosts, setLocalPosts] = useState<FeedPost[]>([]);
  const [notice, setNotice] = useState('');
  const [state, setState] = useState<'ready' | 'loading' | 'error'>('ready');
  const composerTriggerRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const syncFromUrl = () => { const next = readQuery(); setType(next.type); setTopic(next.topic); setSort(next.sort); };
    syncFromUrl();
    window.addEventListener('popstate', syncFromUrl);
    window.addEventListener('cz:querychange', syncFromUrl);
    return () => { window.removeEventListener('popstate', syncFromUrl); window.removeEventListener('cz:querychange', syncFromUrl); };
  }, []);

  const posts = useMemo(() => {
    const filtered = [...localPosts, ...MOCK_POSTS].filter((post) => (type === 'all' || post.type === type) && (topic === 'all' || post.topic === topic));
    return [...filtered].sort((a, b) => {
      if (sort === 'fresh') return a.ageMinutes - b.ageMinutes;
      const aTotal = a.choices ? a.choices[0].count + a.choices[1].count : Object.values(a.reactions ?? {}).reduce((sum, count) => sum + count, 0);
      const bTotal = b.choices ? b.choices[0].count + b.choices[1].count : Object.values(b.reactions ?? {}).reduce((sum, count) => sum + count, 0);
      if (sort === 'popular') return (bTotal + b.commentCount) - (aTotal + a.commentCount);
      const controversy = (post: typeof a) => post.choices ? Math.min(post.choices[0].count, post.choices[1].count) : -1;
      return controversy(b) - controversy(a);
    }).filter((post) => sort !== 'controversial' || post.type !== 'confession');
  }, [type, topic, sort, localPosts]);

  const reset = () => { writeQuery({ type: 'all', topic: 'all', sort: 'fresh' }); setState('ready'); };
  const addLocalPost = (input: NewPostInput) => {
    const base = { id: `local-${Date.now()}`, ...input, timestamp: 'just now', ageMinutes: -1, commentCount: 0, localOnly: true };
    const post: FeedPost = input.type === 'confession' ? { ...base, reactions: { same: 0, ouch: 0, wild: 0 } } : { ...base, choices: POLL_CHOICES[input.type] };
    setLocalPosts((current) => [post, ...current]);
    writeQuery({ type: 'all', topic: 'all', sort: 'fresh' }, 'replace');
    setNotice('Local preview added. It disappears when this page reloads.');
  };

  return <>
    <section className="composer-prompt" aria-labelledby="composer-heading">
      <div className="composer-prompt__copy">
        <h1 id="composer-heading">What ruined your day today?</h1>
        <button ref={composerTriggerRef} className="composer-trigger" type="button" onClick={() => setComposerOpen(true)}><span>Go on…</span><span aria-hidden="true">↗</span></button>
      </div>
      <div className="composer-prompt__mascot"><MascotIcon className="h-16 w-16" /></div>
      <button className="button-primary spill-button" type="button" onClick={() => setComposerOpen(true)}><span aria-hidden="true">➤</span> Spill it</button>
    </section>

    <section className="feed-toolbar" aria-labelledby="feed-controls-heading">
      <div className="feed-toolbar__heading"><h2 id="feed-controls-heading">Latest from the zone</h2></div>
      <div className="filter-row">
        <label className="field-label"><span>Topic</span><select name="topic" className="field-control" value={topic} onChange={(event) => writeQuery({ topic: event.target.value as TopicFilter })}>{TOPIC_OPTIONS.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label>
        <label className="field-label"><span>Sort</span><select name="sort" className="field-control" value={sort} onChange={(event) => writeQuery({ sort: event.target.value as FeedSort })}><option value="fresh">Newest</option><option value="popular">Popular</option><option value="controversial">Controversial</option></select></label>
      </div>
      <p className="development-notice">Development preview: fixture posts and local interactions reset on refresh.</p>
    </section>

    <p className="sr-only" aria-live="polite">{notice}</p>{notice && <p className="local-notice">{notice}</p>}
    {state === 'loading' && <LoadingState />}{state === 'error' && <ErrorState onReset={reset} />}
    {state === 'ready' && (posts.length ? <div className="feed-list" aria-live="polite">{posts.map((post) => <PostCard post={post} key={post.id} />)}</div> : <EmptyState onReset={reset} />)}
    <PostComposer open={composerOpen} onClose={() => setComposerOpen(false)} onSubmit={addLocalPost} returnFocusRef={composerTriggerRef} />
  </>;
}
