import { useMemo, useState } from 'react';
import type { FeedPost, PollChoice, Reaction } from '../../lib/feed';
import { TYPE_LABELS } from '../../lib/feed';

interface Props { post: FeedPost; detailed?: boolean }
const reactionLabels: Record<Reaction, string> = { same: 'Same', ouch: 'Ouch', wild: 'Wild' };

function roundedPercentages(first: number, second: number): [number, number] {
  const total = first + second;
  if (!total) return [0, 0];
  const firstPercent = Math.round((first / total) * 100);
  return [firstPercent, 100 - firstPercent];
}

export function BinaryVote({ post, detailed = false }: Props) {
  const [selected, setSelected] = useState<PollChoice | null>(null);
  const choices = post.choices;
  if (!choices) return null;
  const counts = useMemo(() => choices.map((choice) => choice.count + (selected === choice.key ? 1 : 0)) as [number, number], [choices, selected]);
  const percentages = roundedPercentages(counts[0], counts[1]);

  return (
    <div className={detailed ? 'mt-5' : 'mt-4'}>
      <div className="grid grid-cols-2 gap-2" aria-label={`Local prototype vote for ${TYPE_LABELS[post.type]}`}>
        {choices.map((choice, index) => (
          <button className="vote-button" type="button" aria-pressed={selected === choice.key}
            onClick={() => setSelected((current) => current === choice.key ? null : choice.key)} key={choice.key}>
            <span>{choice.label}</span><span className="text-xs font-normal">{counts[index]}</span>
          </button>
        ))}
      </div>
      {selected && (
        <div className="mt-3 space-y-2" aria-label="Local prototype vote results">
          {choices.map((choice, index) => (
            <div key={choice.key}>
              <div className="flex justify-between text-xs text-ink-muted"><span>{choice.label}</span><span>{percentages[index]}%</span></div>
              <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-surface-muted"><div className="h-full rounded-full bg-accent" style={{ width: `${percentages[index]}%` }} /></div>
            </div>
          ))}
        </div>
      )}
      <p className="sr-only" aria-live="polite">{selected ? 'Local demo choice selected. It resets on reload.' : 'No local demo choice selected.'}</p>
    </div>
  );
}

export function ConfessionReactions({ post, detailed = false }: Props) {
  const [selected, setSelected] = useState<Reaction | null>(null);
  if (!post.reactions) return null;
  return (
    <div className={`flex flex-wrap gap-2 ${detailed ? 'mt-5' : 'mt-4'}`} aria-label="Local prototype reactions">
      {(Object.keys(reactionLabels) as Reaction[]).map((reaction) => (
        <button className="reaction-button" type="button" aria-pressed={selected === reaction}
          onClick={() => setSelected((current) => current === reaction ? null : reaction)} key={reaction}>
          {reactionLabels[reaction]} <span className="font-normal">{post.reactions![reaction] + (selected === reaction ? 1 : 0)}</span>
        </button>
      ))}
      <p className="sr-only" aria-live="polite">{selected ? 'Local demo reaction selected. It resets on reload.' : 'No local demo reaction selected.'}</p>
    </div>
  );
}

export default function InteractionControls(props: Props) {
  return props.post.type === 'confession' ? <ConfessionReactions {...props} /> : <BinaryVote {...props} />;
}
