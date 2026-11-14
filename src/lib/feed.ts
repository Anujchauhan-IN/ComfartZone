export type PostType = 'confession' | 'petty_court' | 'am_i_weird' | 'hot_take';
export type Topic =
  | 'relationships'
  | 'family'
  | 'work'
  | 'social-awkwardness'
  | 'friends'
  | 'everyday-life'
  | 'food-habits'
  | 'internet-technology'
  | 'random';
export type FeedSort = 'fresh' | 'popular' | 'controversial';
export type PollChoice = 'guilty' | 'not_guilty' | 'me_too' | 'just_you' | 'agree' | 'disagree';
export type Reaction = 'same' | 'ouch' | 'wild';

export interface FeedPost {
  id: string;
  type: PostType;
  topic?: Topic;
  content: string;
  timestamp: string;
  ageMinutes: number;
  commentCount: number;
  choices?: readonly [
    { key: PollChoice; label: string; count: number },
    { key: PollChoice; label: string; count: number },
  ];
  reactions?: Record<Reaction, number>;
}

export const POST_TYPE_OPTIONS = [
  { value: 'all', label: 'All', shortLabel: 'Home' },
  { value: 'confession', label: 'Confessions', shortLabel: 'Confess' },
  { value: 'petty_court', label: 'Petty Court', shortLabel: 'Court' },
  { value: 'am_i_weird', label: 'Am I Weird?', shortLabel: 'Weird?' },
  { value: 'hot_take', label: 'Hot Takes', shortLabel: 'Takes' },
] as const;

export const TOPIC_OPTIONS = [
  { value: 'all', label: 'All topics' },
  { value: 'relationships', label: 'Relationships' },
  { value: 'family', label: 'Family' },
  { value: 'work', label: 'Work' },
  { value: 'social-awkwardness', label: 'Social awkwardness' },
  { value: 'friends', label: 'Friends' },
  { value: 'everyday-life', label: 'Everyday life' },
  { value: 'food-habits', label: 'Food habits' },
  { value: 'internet-technology', label: 'Internet & technology' },
  { value: 'random', label: 'Random' },
] as const;

export const TYPE_LABELS: Record<PostType, string> = {
  confession: 'Confession',
  petty_court: 'Petty Court',
  am_i_weird: 'Am I Weird?',
  hot_take: 'Hot Take',
};

export const TOPIC_LABELS = Object.fromEntries(
  TOPIC_OPTIONS.filter((topic) => topic.value !== 'all').map((topic) => [topic.value, topic.label]),
) as Record<Topic, string>;
