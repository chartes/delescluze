// Rétro-conversion de sources-et-bibliographie.html en <listBibl> pour <back>.
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { parseHtml, convertStraight, escapeAttr } from './lib/core.mjs';

export async function convertBibliographie(globalCtx) {
  const raw = await readFile(resolve('data/legacy/sources-et-bibliographie.html'), 'utf8');
  const doc = parseHtml(raw);
  const ctx = { pageId: 'sources-et-bibliographie', log: globalCtx.log, refsUsed: globalCtx.refsUsed, biblRefsUsed: globalCtx.biblRefsUsed, doc, noteCount: 0 };

  let xml = '';
  let count = 0;
  const knownIds = new Set();
  for (const article of doc.querySelectorAll('article.bibliographicReference[id], article.archivalReference[id]')) {
    const id = article.getAttribute('id');
    if (!id) continue;
    knownIds.add(id);
    count++;
    xml += `<bibl xml:id="${escapeAttr(id)}">${convertStraight(article, ctx)}</bibl>`;
  }
  globalCtx.noteCount += ctx.noteCount;
  return { xml: `<listBibl>${xml}</listBibl>`, count, knownIds };
}
