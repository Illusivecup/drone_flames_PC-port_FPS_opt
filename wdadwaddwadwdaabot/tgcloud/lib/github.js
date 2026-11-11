import { fetch, api } from 'sdk';
import { db } from 'sdk/db';
import { eq } from 'sdk/db';
import { botState } from '../schema.js';

export const GITHUB_REPO = 'makkaX2/DroneFlames-PC-Port';
export const TARGET_CHAT_ID = -1003924572520;

export async function getState(key) {
  try {
    const row = await db.select().from(botState).where(eq(botState.key, key)).get();
    return row ? row.val : null;
  } catch (err) {
    console.error('getState error:', err);
    return null;
  }
}

export async function setState(key, val) {
  try {
    await db.insert(botState).values({
      key,
      val,
      updatedAt: new Date(),
    }).onConflictDoUpdate({
      target: botState.key,
      set: {
        val,
        updatedAt: new Date(),
      },
    }).run();
  } catch (err) {
    console.error('setState error:', err);
  }
}

export async function getLatestCommit(branch = 'test') {
  const url = `https://api.github.com/repos/${GITHUB_REPO}/commits?sha=${branch}&per_page=1`;
  const res = await fetch(url, {
    headers: {
      'User-Agent': 'DroneFlames-TGCloud-Bot',
      'Accept': 'application/vnd.github.v3+json',
    },
  });
  if (!res.ok) {
    console.error(`Failed to fetch commits: ${res.status} ${res.statusText}`);
    return null;
  }
  const data = await res.json();
  if (!Array.isArray(data) || data.length === 0) return null;
  const c = data[0];
  return {
    sha: c.sha,
    shortSha: c.sha.slice(0, 7),
    message: c.commit.message.split('\n')[0],
    fullMessage: c.commit.message,
    authorName: c.commit.author.name,
    date: c.commit.author.date,
    htmlUrl: c.html_url,
  };
}

export async function getLatestTestRelease() {
  const url = `https://api.github.com/repos/${GITHUB_REPO}/releases?per_page=10`;
  const res = await fetch(url, {
    headers: {
      'User-Agent': 'DroneFlames-TGCloud-Bot',
      'Accept': 'application/vnd.github.v3+json',
    },
  });
  if (!res.ok) {
    console.error(`Failed to fetch releases: ${res.status} ${res.statusText}`);
    return null;
  }
  const releases = await res.json();
  if (!Array.isArray(releases) || releases.length === 0) return null;

  let target = releases.find(r => r.tag_name.includes('test') || r.prerelease);
  if (!target) target = releases[0];

  const assets = target.assets || [];
  const apkAsset = assets.find(a => a.name.endsWith('.apk'));
  const winSetupAsset = assets.find(a => a.name.endsWith('.exe') && a.name.toLowerCase().includes('setup'));
  const winZipAsset = assets.find(a => a.name.endsWith('.zip') && (a.name.includes('_PC_') || !a.name.includes('macOS')));
  const macDmgAsset = assets.find(a => a.name.endsWith('.dmg'));
  const macZipAsset = assets.find(a => a.name.endsWith('.zip') && a.name.includes('macOS'));

  return {
    id: target.id,
    tagName: target.tag_name,
    name: target.name,
    body: target.body || '',
    htmlUrl: target.html_url,
    publishedAt: target.published_at,
    assets: {
      apk: apkAsset ? { name: apkAsset.name, url: apkAsset.browser_download_url, sizeMb: (apkAsset.size / (1024 * 1024)).toFixed(1) } : null,
      winSetup: winSetupAsset ? { name: winSetupAsset.name, url: winSetupAsset.browser_download_url, sizeMb: (winSetupAsset.size / (1024 * 1024)).toFixed(1) } : null,
      winZip: winZipAsset ? { name: winZipAsset.name, url: winZipAsset.browser_download_url, sizeMb: (winZipAsset.size / (1024 * 1024)).toFixed(1) } : null,
      macDmg: macDmgAsset ? { name: macDmgAsset.name, url: macDmgAsset.browser_download_url, sizeMb: (macDmgAsset.size / (1024 * 1024)).toFixed(1) } : null,
      macZip: macZipAsset ? { name: macZipAsset.name, url: macZipAsset.browser_download_url, sizeMb: (macZipAsset.size / (1024 * 1024)).toFixed(1) } : null,
    },
  };
}

export function buildMessagePayload(commit, release) {
  const tag = release ? release.tagName : 'test';
  const shortSha = commit ? commit.shortSha : 'unknown';
  const commitUrl = commit ? commit.htmlUrl : `https://github.com/${GITHUB_REPO}/commits/test`;
  const author = commit ? commit.authorName : 'unknown';
  const commitDesc = commit ? (commit.fullMessage || commit.message || '').trim() : '';

  let text = `[build:test] ${tag}\n`;
  text += `branch: test\n`;
  text += `commit: ${shortSha}\n`;
  text += `author: ${author}\n`;
  text += `url: ${commitUrl}\n\n`;

  text += `commit description:\n${commitDesc || '(no description)'}\n\n`;

  text += `artifacts:\n`;
  if (release && release.assets) {
    const a = release.assets;
    if (a.apk) text += `- android: ${a.apk.name} (${a.apk.sizeMb} MB)\n`;
    if (a.winZip) text += `- windows: ${a.winZip.name} (${a.winZip.sizeMb} MB)\n`;
    if (a.macDmg) text += `- macos: ${a.macDmg.name} (${a.macDmg.sizeMb} MB)\n`;
  } else {
    text += `- compiling artifacts...\n`;
  }

  const inlineKeyboard = [];
  const dlRow = [];

  if (release && release.assets) {
    const a = release.assets;
    if (a.apk) dlRow.push({ text: '[android apk]', url: a.apk.url });
    if (a.winZip) dlRow.push({ text: '[windows zip]', url: a.winZip.url });
    if (a.macDmg) dlRow.push({ text: '[macos dmg]', url: a.macDmg.url });
  }

  if (dlRow.length > 0) {
    inlineKeyboard.push(dlRow);
  }

  inlineKeyboard.push([
    { text: '[release notes]', callback_data: 'notes' },
    { text: '[check updates]', callback_data: 'check_now' },
  ]);

  const linkRow = [];
  if (release && release.htmlUrl) {
    linkRow.push({ text: '[release url]', url: release.htmlUrl });
  }
  if (commitUrl) {
    linkRow.push({ text: '[commit url]', url: commitUrl });
  }
  if (linkRow.length > 0) {
    inlineKeyboard.push(linkRow);
  }

  return { text, reply_markup: { inline_keyboard: inlineKeyboard } };
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

export async function checkAndSend(chatId = TARGET_CHAT_ID, force = false) {
  const commit = await getLatestCommit('test');
  const release = await getLatestTestRelease();

  if (!commit && !release) {
    if (force) {
      await api.sendMessage({
        chat_id: chatId,
        text: '[error] failed to fetch branch test info from github api',
      });
    }
    return false;
  }

  const lastNotifiedSha = await getState('last_notified_sha');
  const currentSha = commit ? commit.sha : null;

  if (!force && currentSha && lastNotifiedSha === currentSha) {
    return false;
  }

  const payload = buildMessagePayload(commit, release);
  await api.sendMessage({
    chat_id: chatId,
    text: payload.text,
    reply_markup: payload.reply_markup,
    disable_web_page_preview: true,
  });

  if (currentSha) {
    await setState('last_notified_sha', currentSha);
  }
  return true;
}
