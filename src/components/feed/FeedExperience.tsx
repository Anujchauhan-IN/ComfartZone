import { useEffect, useMemo, useRef, useState } from 'react';
import { MOCK_POSTS } from '../../lib/mockFeed';
import type { FeedPost, FeedSort, NewPostInput, PostType, Topic } from '../../lib/feed';
import { POLL_CHOICES, POST_TYPE_OPTIONS, TOPIC_OPTIONS } from '../../lib/feed';
import PostComposer from '../interactive/PostComposer';
import PostCard from './PostCard';
import { EmptyState, ErrorState, LoadingState } from './FeedStates';

type TypeFilter = PostType | 'all';
type TopicFilter = Topic | 'all';

function validType(value: string | null): TypeFilter {
  return POST_TYPE_OPTIONS.some((option) => option.value === value) ? value as TypeFilter : 'all';
}
function validTopic(value: string | null): TopicFilter {
  return TOPIC_OPTIONS.some((option) => option.value === value) ? value as TopicFilter : 'all';
}
function validSort(value: string | null): FeedSort {
  return value === 'popular' || value === 'controversial' ? value : 'fresh';
}

interface Props {
  initialType?: string;
  initialTopic?: string;
  initialSort?: string;
}

export default function FeedExperience({ initialType, initialTopic, initialSort }: Props) {
  const [type, setType] = useState<TypeFilter>(() => validType(initialType ?? null));
  const [topic, setTopic] = useState<TopicFilter>(() => validTopic(initialTopic ?? null));
  const [sort, setSort] = useState<FeedSort>(() => validSort(initialSort ?? null));
  const [composerOpen, setComposerOpen] = useState(false);
  const [localPosts, setLocalPosts] = useState<FeedPost[]>([]);
  const [notice, setNotice] = useState('');
  const [state, setState] = useState<'ready' | 'loading' | 'error'>('ready');
  const composerTriggerRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    setType(validType(params.get('type')));
    setTopic(validTopic(params.get('topic')));
    setSort(validSort(params.get('sort')));
  }, []);

  useEffect(() => {
    if (state !== 'ready') return;
    const params = new URLSearchParams();
    if (type !== 'all') params.set('type', type);
    if (topic !== 'all') params.set('topic', topic);
    if (sort !== 'fresh') params.set('sort', sort);
    const query = params.toString();
    window.history.replaceState({}, '', query ? `/?${query}` : '/');
  }, [type, topic, sort, state]);

  const posts = useMemo(() => {
    const filtered = [...localPosts, ...MOCK_POSTS].filter((post) =>
      (type === 'all' || post.type === type) && (topic === 'all' || post.topic === topic));
    return [...filtered].sort((a, b) => {
      if (sort === 'fresh') return a.ageMinutes - b.ageMinutes;
      const aTotal = a.choices ? a.choices[0].count + a.choices[1].count : Object.values(a.reactions ?? {}).reduce((sum, count) => sum + count, 0);
      const bTotal = b.choices ? b.choices[0].count + b.choices[1].count : Object.values(b.reactions ?? {}).reduce((sum, count) => sum + count, 0);
      if (sort === 'popular') return (bTotal + b.commentCount) - (aTotal + a.commentCount);
      const controversy = (post: typeof a) => post.choices ? Math.min(post.choices[0].count, post.choices[1].count) : -1;
      return controversy(b) - controversy(a);
    }).filter((post) => sort !== 'controversial' || post.type !== 'confession');
  }, [type, topic, sort, localPosts]);

  const reset = () => { setType('all'); setTopic('all'); setSort('fresh'); setState('ready'); };
  const addLocalPost = (input: NewPostInput) => {
    const base = { id: `local-${Date.now()}`, ...input, timestamp: 'just now', ageMinutes: -1, commentCount: 0, localOnly: true };
    const post: FeedPost = input.type === 'confession'
      ? { ...base, reactions: { same: 0, ouch: 0, wild: 0 } }
      : { ...base, choices: POLL_CHOICES[input.type] };
    setLocalPosts((current) => [post, ...current]);
    setType('all'); setTopic('all'); setSort('fresh');
    setNotice('Local post preview added. It will disappear when this page reloads.');
  };

  return (
    <>
      <section className="surface p-4 sm:p-5" aria-labelledby="composer-heading">
        <div className="flex items-center gap-3 sm:gap-4">
          <button ref={composerTriggerRef} className="composer-trigger flex-1 text-left" type="button" onClick={() => setComposerOpen(true)}>
            <span id="composer-heading" className="block font-extrabold">What ruined your day today?</span>
            <span className="mt-0.5 block text-xs text-ink-muted">Open the non-persistent prototype composer</span>
          </button>
          <button className="button-primary shrink-0" type="button" onClick={() => setComposerOpen(true)}>Spill it</button>
        </div>
      </section>

      <section className="surface p-3 sm:p-4" aria-labelledby="feed-controls-heading">
        <div className="flex items-center justify-between gap-3">
          <h1 id="feed-controls-heading" className="text-base font-extrabold">Latest from the zone</h1>
          <span className="rounded-full bg-accent-soft px-2.5 py-1 text-[0.68rem] font-bold uppercase tracking-wide text-ink">Sample feed</span>
        </div>
        <div className="scrollbar-none -mx-1 mt-3 flex overflow-x-auto px-1 pb-1" role="tablist" aria-label="Post type">
          {POST_TYPE_OPTIONS.map((option) => (
            <button className="filter-tab" role="tab" aria-selected={type === option.value} type="button" onClick={() => setType(option.value)} key={option.value}>{option.label}</button>
          ))}
        </div>
        <div className="mt-3 grid grid-cols-2 gap-2">
          <label className="field-label">Topic
            <select className="field-control" value={topic} onChange={(event) => setTopic(event.target.value as TopicFilter)}>
              {TOPIC_OPTIONS.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}
            </select>
          </label>
          <label className="field-label">Sort
            <select className="field-control" value={sort} onChange={(event) => setSort(event.target.value as FeedSort)}>
              <option value="fresh">Fresh</option><option value="popular">Popular</option><option value="controversial">Controversial</option>
            </select>
          </label>
        </div>
        <p className="mt-3 text-xs leading-5 text-ink-muted">Development fixtures only. Filters and interactions are local and reset on refresh.</p>
      </section>

      <p className="sr-only" aria-live="polite">{notice}</p>
      {notice && <p className="rounded-input border border-line bg-accent-soft px-3 py-2 text-xs leading-5">{notice}</p>}
      {state === 'loading' && <LoadingState />}
      {state === 'error' && <ErrorState onReset={reset} />}
      {state === 'ready' && (posts.length ? <div className="space-y-3" aria-live="polite">{posts.map((post) => <PostCard post={post} key={post.id} />)}</div> : <EmptyState onReset={reset} />)}

      <PostComposer open={composerOpen} onClose={() => setComposerOpen(false)} onSubmit={addLocalPost} returnFocusRef={composerTriggerRef} />
    </>
  );
}
