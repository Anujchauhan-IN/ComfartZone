import { useMemo, useState } from 'react';
import type { FeedPost, PollChoice, Reaction } from '../../lib/feed';
import { TOPIC_LABELS, TYPE_LABELS } from '../../lib/feed';

interface Props { post: FeedPost }

const reactionLabels: Record<Reaction, string> = { same: 'Same', ouch: 'Ouch', wild: 'Wild' };

function TypeBadge({ post }: Props) {
  return <span className={`type-badge type-badge--${post.type}`}>{TYPE_LABELS[post.type]}</span>;
}

function BinaryVote({ post }: Props) {
  const [selected, setSelected] = useState<PollChoice | null>(null);
  const choices = post.choices!;
  const counts = useMemo(() => choices.map((choice) => choice.count + (selected === choice.key ? 1 : 0)), [choices, selected]);
  const total = counts[0] + counts[1];

  return (
    <div className="mt-4">
      <div className="grid grid-cols-2 gap-2" aria-label={`Demo vote for ${TYPE_LABELS[post.type]}`}>
        {choices.map((choice, index) => (
          <button
            className="vote-button"
            type="button"
            aria-pressed={selected === choice.key}
            onClick={() => setSelected((current) => current === choice.key ? null : choice.key)}
            key={choice.key}
          >
            <span>{choice.label}</span><span className="text-xs font-normal">{counts[index]}</span>
          </button>
        ))}
      </div>
      <p className="sr-only" aria-live="polite">{selected ? 'Demo choice selected. It will reset when the page reloads.' : 'No demo choice selected.'}</p>
      {total > 0 && selected && (
        <div className="mt-2 flex justify-between text-xs text-ink-muted" aria-label={`Demo result: ${Math.round(counts[0] / total * 100)} percent ${choices[0].label}, ${Math.round(counts[1] / total * 100)} percent ${choices[1].label}`}>
          <span>{Math.round(counts[0] / total * 100)}%</span><span>{Math.round(counts[1] / total * 100)}%</span>
        </div>
      )}
    </div>
  );
}

function ConfessionReactions({ post }: Props) {
  const [selected, setSelected] = useState<Reaction | null>(null);
  return (
    <div className="mt-4 flex flex-wrap gap-2" aria-label="Demo reactions">
      {(Object.keys(reactionLabels) as Reaction[]).map((reaction) => (
        <button
          className="reaction-button"
          type="button"
          aria-pressed={selected === reaction}
          onClick={() => setSelected((current) => current === reaction ? null : reaction)}
          key={reaction}
        >
          {reactionLabels[reaction]} <span className="font-normal">{post.reactions![reaction] + (selected === reaction ? 1 : 0)}</span>
        </button>
      ))}
      <p className="sr-only" aria-live="polite">{selected ? 'Demo reaction selected. It will reset when the page reloads.' : 'No demo reaction selected.'}</p>
    </div>
  );
}

export default function PostCard({ post }: Props) {
  return (
    <article className="surface overflow-hidden p-4 sm:p-5" aria-labelledby={`post-${post.id}`}>
      <div className="flex flex-wrap items-center gap-2 text-xs text-ink-muted">
        <TypeBadge post={post} />
        {post.topic && <span className="topic-badge">{TOPIC_LABELS[post.topic]}</span>}
        <span className="ml-auto whitespace-nowrap">{post.timestamp}</span>
      </div>
      <p id={`post-${post.id}`} className="mt-3 whitespace-pre-line break-words text-[0.98rem] leading-6">{post.content}</p>
      {post.type === 'confession' ? <ConfessionReactions post={post} /> : <BinaryVote post={post} />}
      <div className="mt-4 flex items-center justify-between border-t border-line pt-3 text-sm text-ink-muted">
        <span>{post.commentCount} {post.commentCount === 1 ? 'comment' : 'comments'}</span>
        <span className="text-xs">Demo interaction</span>
      </div>
    </article>
  );
}
