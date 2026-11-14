export type PostType = 'regular' | 'confession' | 'petty_court' | 'am_i_weird' | 'hot_take';
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
export type Reaction = 'funny' | 'love' | 'annoying' | 'same' | 'ouch' | 'wild';
export type ExpiryAction = 'archive_private' | 'delete_permanently';

export interface LocalAttachment {
  name: string;
  type: string;
  size: number;
  previewUrl: string;
  altText?: string;
}

export interface FeedPost {
  id: string;
  type: PostType;
  topic?: Topic;
  content: string;
  timestamp: string;
  ageMinutes: number;
  commentCount: number;
  anonymous?: boolean;
  expiresIn24Hours?: boolean;
  expiryAction?: ExpiryAction;
  attachment?: LocalAttachment;
  choices?: readonly [
    { key: PollChoice; label: string; count: number },
    { key: PollChoice; label: string; count: number },
  ];
  reactions?: Partial<Record<Reaction, number>>;
  localOnly?: boolean;
}

export interface CommentFixture {
  id: string;
  content: string;
  timestamp: string;
  replies?: CommentFixture[];
  localOnly?: boolean;
}

export interface NewPostInput {
  type: PostType;
  topic?: Topic;
  content: string;
  anonymous: boolean;
  expiresIn24Hours: boolean;
  expiryAction?: ExpiryAction;
  attachment?: LocalAttachment;
}

export const POST_LIMITS = { min: 1, max: 256 } as const;
export const COMMENT_LIMITS = { min: 1, max: 256 } as const;
export const MAX_MEDIA_BYTES = 2 * 1024 * 1024;

export const POST_TYPE_OPTIONS = [
  { value: 'all', label: 'All', shortLabel: 'Home' },
  { value: 'confession', label: 'Confessions', shortLabel: 'Confess' },
  { value: 'petty_court', label: 'Petty Court', shortLabel: 'Court' },
  { value: 'am_i_weird', label: 'Am I Weird?', shortLabel: 'Weird?' },
  { value: 'hot_take', label: 'Hot Takes', shortLabel: 'Takes' },
] as const;

export const POST_FORMAT_OPTIONS: readonly { value: PostType; label: string }[] = [
  { value: 'regular', label: 'Regular' },
  { value: 'confession', label: 'Confession' },
  { value: 'petty_court', label: 'Petty Court' },
  { value: 'am_i_weird', label: 'Am I Weird?' },
  { value: 'hot_take', label: 'Hot Take' },
];

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

export const POLL_CHOICES: Record<Exclude<PostType, 'regular' | 'confession'>, FeedPost['choices']> = {
  petty_court: [
    { key: 'guilty', label: 'Guilty', count: 0 },
    { key: 'not_guilty', label: 'Not guilty', count: 0 },
  ],
  am_i_weird: [
    { key: 'me_too', label: 'Me too', count: 0 },
    { key: 'just_you', label: 'Just you', count: 0 },
  ],
  hot_take: [
    { key: 'agree', label: 'Agree', count: 0 },
    { key: 'disagree', label: 'Disagree', count: 0 },
  ],
};

export const TYPE_LABELS: Record<PostType, string> = {
  regular: 'Regular',
  confession: 'Confession',
  petty_court: 'Petty Court',
  am_i_weird: 'Am I Weird?',
  hot_take: 'Hot Take',
};

export const TOPIC_LABELS = Object.fromEntries(
  TOPIC_OPTIONS.filter((topic) => topic.value !== 'all').map((topic) => [topic.value, topic.label]),
) as Record<Topic, string>;
