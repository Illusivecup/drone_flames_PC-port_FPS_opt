import { api } from 'sdk';
import { checkAndSend, getLatestCommit, TARGET_CHAT_ID } from '../lib/github.js';

export default async function (msg, ctx) {
  const text = (msg.text || '').trim();
  const chatId = msg.chat?.id;

  if (!text) return;

  if (text.startsWith('/start') || text.startsWith('/help')) {
    const welcome = `[droneflames test bot]\n` +
      `tracking: branch test\n` +
      `chat: ${TARGET_CHAT_ID}\n\n` +
      `commands:\n` +
      `• /test, /builds - get latest test builds\n` +
      `• /lastcommit - show latest commit on branch test\n` +
      `• /status - check bot status`;

    await api.sendMessage({
      chat_id: chatId,
      text: welcome,
      reply_markup: {
        inline_keyboard: [
          [{ text: 'get builds', callback_data: 'get_builds' }],
          [{ text: 'check branch', callback_data: 'check_now' }]
        ]
      }
    });
    return;
  }

  if (text.startsWith('/test') || text.startsWith('/check') || text.startsWith('/builds')) {
    await api.sendMessage({
      chat_id: chatId,
      text: '[status] checking branch test...',
    });
    await checkAndSend(chatId, true);
    return;
  }

  if (text.startsWith('/lastcommit')) {
    const commit = await getLatestCommit('test');
    if (!commit) {
      await api.sendMessage({ chat_id: chatId, text: '[error] commit not found.' });
      return;
    }
    const t = `[commit:test]\n` +
      `sha: ${commit.shortSha} (${commit.htmlUrl})\n` +
      `author: ${commit.authorName}\n` +
      `date: ${commit.date}\n` +
      `msg: ${commit.fullMessage}`;

    await api.sendMessage({
      chat_id: chatId,
      text: t,
      disable_web_page_preview: true,
    });
    return;
  }

  if (text.startsWith('/status')) {
    await api.sendMessage({
      chat_id: chatId,
      text: `[bot status]\n` +
        `platform: telegram serverless (tgcloud)\n` +
        `chat: ${TARGET_CHAT_ID}\n` +
        `branch: test\n` +
        `repo: makkaX2/DroneFlames-PC-Port`,
    });
    return;
  }

}
