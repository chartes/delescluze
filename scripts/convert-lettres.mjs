// Rétro-conversion de la rubrique "lettres" (lettres/lettreNN/pageNN.html).
import { readFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import {
  parseHtml, loadPage, makeNoteResolver, buildPageDiv, alignLeaf,
  convertStraight, escapeXml, escapeAttr, tokensPlain
} from './lib/core.mjs';

const ROOT = resolve('data/legacy/lettres');

function parseCorrespEntry(text) {
  // "Henri Delescluze à Charles Delescluze. 15 décembre 1851 (2 pages)"
  const clean = text.replace(/\s+/g, ' ').trim();
  const m = /^(.+?)\s+à\s+(.+?)\.\s*(.+?)(?:\s*\(\d+\s*pages?\))?$/i.exec(clean);
  if (!m) return { raw: clean };
  return { sender: m[1].trim(), receiver: m[2].trim(), date: m[3].trim() };
}

export async function convertLettres(globalCtx) {
  const dirs = (await readdir(ROOT, { withFileTypes: true }))
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort((a, b) => a.localeCompare(b, 'fr', { numeric: true }));

  let lettresXml = '';
  let pageCount = 0;
  for (const dirName of dirs) {
    const num = (/lettre(\d+)/.exec(dirName) || [])[1];
    const lettreId = `lettre${num.padStart(2, '0')}`;
    const files = (await readdir(resolve(ROOT, dirName)))
      .filter((f) => /^page\d+\.html$/.test(f))
      .sort((a, b) => a.localeCompare(b, 'fr', { numeric: true }));

    let corresp = null;
    let pagesXml = '';
    for (const file of files) {
      const pnum = (/page(\d+)/.exec(file) || [])[1];
      const pageId = `${lettreId}-page${pnum.padStart(2, '0')}`;
      const raw = await readFile(resolve(ROOT, dirName, file), 'utf8');
      const doc = parseHtml(raw);
      const { editionArticle, transcriptionArticle, editionNotes, facsimile } = loadPage(doc);
      pageCount++;

      if (!corresp) {
        const li = doc.querySelector('#letters-list li.selected');
        if (li) corresp = parseCorrespEntry(li.textContent);
      }

      const ctx = {
        pageId,
        log: globalCtx.log,
        refsUsed: globalCtx.refsUsed,
        biblRefsUsed: globalCtx.biblRefsUsed,
        noteCount: 0,
        inlinePbCount: () => { globalCtx.inlinePb++; },
        resolveNote: makeNoteResolver(editionNotes, pageId, globalCtx, 'edition')
      };

      let inner = '';
      const eOpener = editionArticle?.querySelector('.opener') || null;
      const tOpener = transcriptionArticle?.querySelector('.opener') || null;
      if (eOpener || tOpener) {
        const dateline = alignLeaf(eOpener?.querySelector('.dateline'), tOpener?.querySelector('.dateline'), ctx, 'dateline');
        const extra = alignLeaf(eOpener?.querySelector('.authorExtraNote'), tOpener?.querySelector('.authorExtraNote'), ctx, 'authorExtraNote');
        const salute = alignLeaf(eOpener?.querySelector('.salute'), tOpener?.querySelector('.salute'), ctx, 'salute');
        inner += `<opener>${dateline ? `<dateline>${dateline}</dateline>` : ''}${extra ? `<note type="authorial">${extra}</note>` : ''}${salute ? `<salute>${salute}</salute>` : ''}</opener>`;
      }
      const eParas = [...(editionArticle?.querySelectorAll(':scope > div > p') || [])].filter((p) => !p.closest('.opener'));
      const tParas = [...(transcriptionArticle?.querySelectorAll(':scope > div > p') || [])].filter((p) => !p.closest('.opener'));
      const n = Math.max(eParas.length, tParas.length);
      if (eParas.length !== tParas.length) {
        globalCtx.log.push({ page: pageId, leaf: 'paragraphes', type: 'nombre-different', edition: eParas.length, transcription: tParas.length });
      }
      for (let i = 0; i < n; i++) {
        const xml = alignLeaf(eParas[i] || null, tParas[i] || null, ctx, `p${i}`);
        if (xml.trim()) inner += `<p>${xml}</p>`;
      }
      globalCtx.noteCount += ctx.noteCount;
      pagesXml += buildPageDiv(pageId, pnum, facsimile, inner);
    }

    const correspDesc = corresp && corresp.sender
      ? `<correspDesc><correspAction type="sent"><persName>${escapeXml(corresp.sender)}</persName></correspAction><correspAction type="received"><persName>${escapeXml(corresp.receiver)}</persName></correspAction><date>${escapeXml(corresp.date)}</date></correspDesc>`
      : '';
    lettresXml += `<div type="lettre" xml:id="${lettreId}">${correspDesc}${pagesXml}</div>`;
  }

  return { xml: `<div type="rubrique" xml:id="lettres"><head>Lettres</head>${lettresXml}</div>`, pageCount };
}
