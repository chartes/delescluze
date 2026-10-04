// Rétro-conversion de la rubrique "passages rédigés"
// (passages-rediges/passageNN/pageNN.html).
import { readFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import {
  parseHtml, loadPage, makeNoteResolver, buildPageDiv, alignLeaf, escapeXml, escapeAttr
} from './lib/core.mjs';

const ROOT = resolve('data/legacy/passages-rediges');

export async function convertPassages(globalCtx) {
  const dirs = (await readdir(ROOT, { withFileTypes: true }))
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort((a, b) => a.localeCompare(b, 'fr', { numeric: true }));

  let xml = '';
  let pageCount = 0;
  for (const dirName of dirs) {
    const num = (/passage(\d+)/.exec(dirName) || [])[1];
    const passageId = `passage${num.padStart(2, '0')}`;
    const files = (await readdir(resolve(ROOT, dirName)))
      .filter((f) => /^page\d+\.html$/.test(f))
      .sort((a, b) => a.localeCompare(b, 'fr', { numeric: true }));

    let title = null;
    let pagesXml = '';
    for (const file of files) {
      const pnum = (/page(\d+)/.exec(file) || [])[1];
      const pageId = `${passageId}-page${pnum.padStart(2, '0')}`;
      const raw = await readFile(resolve(ROOT, dirName, file), 'utf8');
      const doc = parseHtml(raw);
      const { editionArticle, transcriptionArticle, editionNotes, facsimile } = loadPage(doc);
      pageCount++;

      if (!title) {
        const li = doc.querySelector('#floatingTexts-list li.selected');
        if (li) title = li.textContent.replace(/\s+/g, ' ').trim().replace(/\s*\(\w+ pages?\)\s*$/i, '');
      }

      const ctx = {
        pageId, log: globalCtx.log, refsUsed: globalCtx.refsUsed, biblRefsUsed: globalCtx.biblRefsUsed,
        noteCount: 0,
        inlinePbCount: () => { globalCtx.inlinePb++; },
        resolveNote: makeNoteResolver(editionNotes, pageId, globalCtx, 'edition')
      };

      let inner = '';
      const eParas = [...(editionArticle?.querySelectorAll(':scope > div > p') || [])];
      const tParas = [...(transcriptionArticle?.querySelectorAll(':scope > div > p') || [])];
      if (eParas.length !== tParas.length) {
        globalCtx.log.push({ page: pageId, leaf: 'paragraphes', type: 'nombre-different', edition: eParas.length, transcription: tParas.length });
      }
      const n = Math.max(eParas.length, tParas.length);
      for (let i = 0; i < n; i++) {
        const xmlP = alignLeaf(eParas[i] || null, tParas[i] || null, ctx, `p${i}`);
        if (xmlP.trim()) inner += `<p>${xmlP}</p>`;
      }
      const eSigned = editionArticle?.querySelector('.signed') || null;
      const tSigned = transcriptionArticle?.querySelector('.signed') || null;
      if (eSigned || tSigned) {
        const signedXml = alignLeaf(eSigned, tSigned, ctx, 'signed');
        if (signedXml.trim()) inner += `<closer><signed>${signedXml}</signed></closer>`;
      }
      globalCtx.noteCount += ctx.noteCount;
      pagesXml += buildPageDiv(pageId, pnum, facsimile, inner);
    }

    xml += `<div type="passage" xml:id="${passageId}">${title ? `<head>${escapeXml(title)}</head>` : ''}${pagesXml}</div>`;
  }
  return { xml: `<div type="rubrique" xml:id="passages-rediges"><head>Passages rédigés</head>${xml}</div>`, pageCount };
}
