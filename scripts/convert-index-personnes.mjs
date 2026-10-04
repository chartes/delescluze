// Rétro-conversion de l'index des personnes (index-personnes/lettre-X.html)
// en <listPerson> pour <back>. Conserve les @xml:id d'origine (article/@id).
import { readFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { parseHtml, convertStraight, escapeXml, escapeAttr } from './lib/core.mjs';

const ROOT = resolve('data/legacy/index-personnes');

function idnoType(href) {
  if (/isni\.org/i.test(href)) return 'ISNI';
  if (/idref\.fr/i.test(href)) return 'IDREF';
  if (/bnf\.fr/i.test(href)) return 'BNF';
  if (/viaf\.org/i.test(href)) return 'VIAF';
  return 'url';
}

export async function convertIndexPersonnes(globalCtx) {
  const files = (await readdir(ROOT))
    .filter((f) => /^lettre-[A-Z]\.html$/.test(f))
    .sort((a, b) => a.localeCompare(b));

  let persons = '';
  let pageCount = 0;
  let personCount = 0;
  const knownIds = new Set();

  for (const file of files) {
    const raw = await readFile(resolve(ROOT, file), 'utf8');
    const doc = parseHtml(raw);
    pageCount++;
    const ctx = { pageId: file.replace('.html', ''), log: globalCtx.log, refsUsed: globalCtx.refsUsed, biblRefsUsed: globalCtx.biblRefsUsed, doc, noteCount: 0 };

    const articles = doc.querySelectorAll('#content section > article[id]');
    for (const article of articles) {
      const id = article.getAttribute('id');
      if (!id) continue;
      knownIds.add(id);
      personCount++;
      const nameEl = article.querySelector('h4 .persName') || article.querySelector('h4');
      const name = nameEl ? nameEl.textContent.replace(/\s+/g, ' ').trim() : id;
      const occupation = article.querySelector('.occupation');
      const biography = article.querySelector('.biography');
      const externalMappings = article.querySelector('.externalMappings');
      const crossRefs = article.querySelector('.crossReferences');

      let idnos = '';
      if (externalMappings) {
        for (const a of externalMappings.querySelectorAll('a.externalLink')) {
          const href = a.getAttribute('href') || '';
          idnos += `<idno type="${escapeAttr(idnoType(href))}" target="${escapeAttr(href)}">${escapeXml(a.textContent.trim())}</idno>`;
        }
      }

      let xml = `<person xml:id="${escapeAttr(id)}"><persName>${escapeXml(name)}</persName>`;
      if (occupation) xml += `<occupation>${convertStraight(occupation, ctx)}</occupation>`;
      if (biography) xml += `<note type="biography">${convertStraight(biography, ctx)}</note>`;
      xml += idnos;
      if (crossRefs) xml += `<note type="seeAlso">${convertStraight(crossRefs, ctx)}</note>`;
      xml += `</person>`;
      persons += xml;
    }
    globalCtx.noteCount += ctx.noteCount;
  }

  return { xml: `<listPerson>${persons}</listPerson>`, pageCount, personCount, knownIds };
}
