import type { CommentFixture } from './feed';

/** Development-only comment fixtures keyed by the existing mock post IDs. */
export const MOCK_COMMENTS: Record<string, CommentFixture[]> = {
  'demo-quiet-kettle': [
    { id: 'comment-kettle-1', content: 'I do this with the microwave at 0:01. We are apparently at war with completion.', timestamp: '5 min ago', replies: [
      { id: 'reply-kettle-1', content: 'The beep feels judgmental. This is self-defence.', timestamp: '3 min ago' },
    ] },
    { id: 'comment-kettle-2', content: 'My kettle clicks before I reach it, which somehow feels smug.', timestamp: '2 min ago' },
  ],
  'demo-leftovers': [
    { id: 'comment-leftovers-1', content: 'A weekday label is not an expiry date. The court finds your roommate extremely creative and still guilty.', timestamp: '18 min ago' },
  ],
  'demo-crosswalk': [
    { id: 'comment-crosswalk-1', content: 'The little jog is mandatory. Bonus points for the apologetic hand wave.', timestamp: '31 min ago' },
  ],
  'demo-voice-notes': [
    { id: 'comment-voice-1', content: 'At seven minutes it needs chapters and show notes.', timestamp: '52 min ago', replies: [
      { id: 'reply-voice-1', content: 'And a transcript for those of us trapped in public.', timestamp: '47 min ago' },
    ] },
  ],
  'demo-fridge-light': [],
  'demo-meeting': [
    { id: 'comment-meeting-1', content: '“One more thing” should automatically disconnect the call.', timestamp: '2 hr ago' },
  ],
};
