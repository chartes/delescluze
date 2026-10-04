// Rétro-conversion de la rubrique "introduction" (introduction/partie-N-M.html).
// Un seul état du texte (prose éditoriale), pas de facsimilé : conversion
// directe, sans alignement.
import { readFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { parseHtml, convertStraight, escapeXml, escapeAttr } from './lib/core.mjs';

const ROOT = resolve('data/legacy/introduction');

export async function convertIntroduction(globalCtx) {
  const files = (await readdir(ROOT))
    .filter((f) => /^partie-[\d-]+\.html$/.test(f))
    .sort((a, b) => a.localeCompare(b, 'fr', { numeric: true }));

  let xml = '';
  let pageCount = 0;
  for (const file of files) {
    const id = file.replace(/\.html$/, '');
    const pageId = `introduction-${id}`;
    const raw = await readFile(resolve(ROOT, file), 'utf8');
    const doc = parseHtml(raw);
    pageCount++;
    const article = doc.querySelector('#content article:not(#notes)');
    const h1 = article?.querySelector('h1');
    const title = h1 ? h1.textContent.replace(/\s+/g, ' ').trim() : id;

    const ctx = { pageId, log: globalCtx.log, refsUsed: globalCtx.refsUsed, biblRefsUsed: globalCtx.biblRefsUsed, doc, noteCount: 0 };
    let body = '';
    if (article) {
      for (const child of article.children) {
        if (child.tagName.toLowerCase() === 'h1') continue;
        if (child.tagName.toLowerCase() === 'p') body += `<p>${convertStraight(child, ctx)}</p>`;
        else if (child.tagName.toLowerCase() === 'ul') {
          body += `<list>${[...child.children].map((li) => `<item>${convertStraight(li, ctx)}</item>`).join('')}</list>`;
        } else body += convertStraight(child, ctx);
      }
    }
    globalCtx.noteCount += ctx.noteCount;
    xml += `<div type="page" xml:id="${escapeAttr(pageId)}"><head>${escapeXml(title)}</head>${body}</div>`;
  }
  return { xml: `<div type="rubrique" xml:id="introduction"><head>Introduction</head>${xml}</div>`, pageCount };
}
