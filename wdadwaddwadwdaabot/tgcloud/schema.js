import { table, text, integer } from 'sdk/db';

export const botState = table('bot_state', {
  key: text('key').primaryKey(),
  val: text('val').notNull(),
  updatedAt: integer('updated_at', { mode: 'timestamp' }),
});
