import type { FeedPost } from './feed';

/** Development-only fixture content for the Phase 1B interface prototype. */
export const MOCK_POSTS: readonly FeedPost[] = [
  {
    id: 'demo-quiet-kettle',
    type: 'confession',
    topic: 'everyday-life',
    content: 'I turn the kettle off one second before it clicks because apparently even appliances are not allowed to finish a sentence around me.',
    timestamp: '8 min ago',
    ageMinutes: 8,
    commentCount: 7,
    reactions: { same: 18, ouch: 3, wild: 2 },
  },
  {
    id: 'demo-leftovers',
    type: 'petty_court',
    topic: 'friends',
    content: 'My roommate ate the leftovers I labelled “Tuesday”. It was Wednesday, so they claim the food had become public property.',
    timestamp: '24 min ago',
    ageMinutes: 24,
    commentCount: 14,
    choices: [
      { key: 'guilty', label: 'Guilty', count: 31 },
      { key: 'not_guilty', label: 'Not guilty', count: 9 },
    ],
  },
  {
    id: 'demo-crosswalk',
    type: 'am_i_weird',
    topic: 'social-awkwardness',
    content: 'When a car stops for me at a crossing, I do a tiny apologetic jog as if walking normally would bankrupt the driver.',
    timestamp: '41 min ago',
    ageMinutes: 41,
    commentCount: 22,
    choices: [
      { key: 'me_too', label: 'Me too', count: 46 },
      { key: 'just_you', label: 'Just you', count: 5 },
    ],
  },
  {
    id: 'demo-voice-notes',
    type: 'hot_take',
    topic: 'internet-technology',
    content: 'A seven-minute voice note is a podcast episode sent without consent.',
    timestamp: '1 hr ago',
    ageMinutes: 68,
    commentCount: 35,
    choices: [
      { key: 'agree', label: 'Agree', count: 27 },
      { key: 'disagree', label: 'Disagree', count: 24 },
    ],
  },
  {
    id: 'demo-fridge-light',
    type: 'confession',
    topic: 'food-habits',
    content: 'I open the fridge repeatedly as though a better snack might spawn if I give the shelves enough opportunities.',
    timestamp: '2 hr ago',
    ageMinutes: 122,
    commentCount: 11,
    reactions: { same: 39, ouch: 6, wild: 1 },
  },
  {
    id: 'demo-meeting',
    type: 'hot_take',
    topic: 'work',
    content: 'If a meeting ends early, nobody should be allowed to fill the rescued minutes with “one more thing”. They have been pardoned. Let them go.',
    timestamp: '3 hr ago',
    ageMinutes: 183,
    commentCount: 19,
    choices: [
      { key: 'agree', label: 'Agree', count: 42 },
      { key: 'disagree', label: 'Disagree', count: 8 },
    ],
  },
];
