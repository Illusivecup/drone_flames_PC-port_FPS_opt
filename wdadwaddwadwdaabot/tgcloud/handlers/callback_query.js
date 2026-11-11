import { api } from 'sdk';
import { checkAndSend, getLatestTestRelease } from '../lib/github.js';

export default async function (query, ctx) {
  const data = query.data;
  const chatId = query.message?.chat?.id;

  if (data === 'check_now' || data === 'get_builds') {
    await api.answerCallbackQuery({
      callback_query_id: query.id,
      text: 'checking branch test...',
    });
    if (chatId) {
      await checkAndSend(chatId, true);
    }
    return;
  }

  if (data === 'notes' || data.startsWith('notes')) {
    await api.answerCallbackQuery({
      callback_query_id: query.id,
      text: 'fetching release notes...',
    });

    const release = await getLatestTestRelease();
    if (!release) {
      if (chatId) {
        await api.sendMessage({
          chat_id: chatId,
          text: '[error] release info not found',
          reply_to_message_id: query.message?.message_id,
        });
      }
      return;
    }

    const body = (release.body || 'no description').trim();
    let text = `[release notes: ${release.tagName}]\n` +
      `title: ${release.name || release.tagName}\n` +
      `published: ${release.publishedAt || 'recent'}\n` +
      `url: ${release.htmlUrl}\n\n` +
      `description:\n${body}`;

    if (text.length > 4000) {
      text = text.slice(0, 3980) + '\n\n[...truncated due to telegram limits]';
    }

    if (chatId) {
      await api.sendMessage({
        chat_id: chatId,
        text: text,
        reply_to_message_id: query.message?.message_id,
        disable_web_page_preview: true,
        reply_markup: {
          inline_keyboard: [
            [{ text: '[close]', callback_data: 'close_msg' }]
          ]
        }
      });
    }
    return;
  }

  if (data === 'close_msg') {
    await api.answerCallbackQuery({ callback_query_id: query.id });
    if (chatId && query.message?.message_id) {
      try {
        await api.deleteMessage({
          chat_id: chatId,
          message_id: query.message.message_id,
        });
      } catch (err) {
        console.error('Failed to delete message:', err);
      }
    }
    return;
  }

  await api.answerCallbackQuery({
    callback_query_id: query.id,
    text: 'ok',
  });
}
