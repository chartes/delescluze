// Rétro-conversion de la rubrique "éphémérides" (ephemerides/carnetN-pageNNN.html).
import { readFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import {
  parseHtml, loadPage, makeNoteResolver, buildPageDiv, alignLeaf, alignTable, escapeAttr
} from './lib/core.mjs';

const ROOT = resolve('data/legacy/ephemerides');

function alignDay(eDay, tDay, ctx, label) {
  const eChildren = eDay ? [...eDay.children] : [];
  const tChildren = tDay ? [...tDay.children] : [];
  if (eChildren.length !== tChildren.length) {
    ctx.log.push({ page: ctx.pageId, leaf: label, type: 'nombre-different-enfants-jour', edition: eChildren.length, transcription: tChildren.length });
  }
  const n = Math.max(eChildren.length, tChildren.length);
  let inner = '';
  for (let i = 0; i < n; i++) {
    const e = eChildren[i] || null, t = tChildren[i] || null;
    const tag = (e || t).tagName.toLowerCase();
    if (tag === 'time') {
      const when = e?.getAttribute('datetime') || t?.getAttribute('datetime') || '';
      const xml = alignLeaf(e, t, ctx, `${label}-time`);
      inner += `<head${when ? ` when="${escapeAttr(when)}"` : ''}>${xml}</head>`;
    } else if (tag === 'table') {
      inner += alignTable(e, t, ctx, `${label}-table${i}`);
    } else if (tag === 'p') {
      const xml = alignLeaf(e, t, ctx, `${label}-p${i}`);
      if (xml.trim()) inner += `<p>${xml}</p>`;
    } else {
      const xml = alignLeaf(e, t, ctx, `${label}-x${i}`);
      if (xml.trim()) inner += `<p>${xml}</p>`;
    }
  }
  return `<div type="day">${inner}</div>`;
}

export async function convertEphemerides(globalCtx) {
  const files = (await readdir(ROOT))
    .filter((f) => /^carnet\d+-page[\w-]+\.html$/.test(f))
    .sort((a, b) => a.localeCompare(b, 'fr', { numeric: true }));

  const carnets = new Map();
  let pageCount = 0;
  for (const file of files) {
    const m = /^carnet(\d+)-page([\w-]+)\.html$/.exec(file);
    const carnetNum = m[1];
    const pageLabel = m[2]; // peut être "de-titre" ou un nombre
    const carnetId = `carnet${carnetNum}`;
    const pageId = /^\d+$/.test(pageLabel) ? `${carnetId}-page${pageLabel.padStart(3, '0')}` : `${carnetId}-${pageLabel}`;

    const raw = await readFile(resolve(ROOT, file), 'utf8');
    const doc = parseHtml(raw);
    const { editionArticle, transcriptionArticle, editionNotes, facsimile } = loadPage(doc);
    pageCount++;

    const ctx = {
      pageId,
      log: globalCtx.log,
      refsUsed: globalCtx.refsUsed,
      biblRefsUsed: globalCtx.biblRefsUsed,
      noteCount: 0,
      inlinePbCount: () => { globalCtx.inlinePb++; },
      resolveNote: makeNoteResolver(editionNotes, pageId, globalCtx, 'edition')
    };

    const eDays = editionArticle ? [...editionArticle.querySelectorAll(':scope > div')] : [];
    const tDays = transcriptionArticle ? [...transcriptionArticle.querySelectorAll(':scope > div')] : [];
    if (eDays.length !== tDays.length) {
      globalCtx.log.push({ page: pageId, leaf: 'jours', type: 'nombre-different', edition: eDays.length, transcription: tDays.length });
    }
    const n = Math.max(eDays.length, tDays.length, editionArticle ? 1 : 0);
    let inner = '';
    if (eDays.length === 0 && tDays.length === 0 && editionArticle) {
      // page de titre / page sans entrées structurées : conversion directe
      const { convertStraight } = await import('./lib/core.mjs');
      inner = `<p>${convertStraight(editionArticle, ctx)}</p>`;
    } else {
      for (let i = 0; i < n; i++) {
        inner += alignDay(eDays[i] || null, tDays[i] || null, ctx, `jour${i}`);
      }
    }
    globalCtx.noteCount += ctx.noteCount;

    if (!carnets.has(carnetId)) carnets.set(carnetId, '');
    carnets.set(carnetId, carnets.get(carnetId) + buildPageDiv(pageId, pageLabel, facsimile, inner));
  }

  let xml = '';
  for (const [carnetId, pagesXml] of carnets) {
    xml += `<div type="carnet" xml:id="${carnetId}">${pagesXml}</div>`;
  }
  return { xml: `<div type="rubrique" xml:id="ephemerides"><head>Éphémérides</head>${xml}</div>`, pageCount };
}
