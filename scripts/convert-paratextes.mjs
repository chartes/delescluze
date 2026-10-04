// Rétro-conversion des paratextes (accueil, le projet, sources et
// bibliographie déjà traité à part, contact, crédits, mentions légales).
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { parseHtml, convertStraight, escapeXml, escapeAttr } from './lib/core.mjs';

const PAGES = [
  { id: 'accueil', file: 'index.html' },
  { id: 'le-projet-choix-editoriaux', file: 'le-projet/choix-editoriaux.html' },
  { id: 'le-projet-choix-techniques', file: 'le-projet/choix-techniques.html' },
  { id: 'contact', file: 'contact.html' },
  { id: 'credits', file: 'credits.html' },
  { id: 'mentions-legales', file: 'mentions-legales.html' }
];

export async function convertParatextes(globalCtx) {
  let xml = '';
  let pageCount = 0;
  for (const { id, file } of PAGES) {
    const raw = await readFile(resolve('data/legacy', file), 'utf8');
    const doc = parseHtml(raw);
    pageCount++;
    const content = doc.querySelector('#content');
    const h1 = content?.querySelector('h1');
    const title = h1 ? h1.textContent.replace(/\s+/g, ' ').trim() : id;
    const ctx = { pageId: id, log: globalCtx.log, refsUsed: globalCtx.refsUsed, biblRefsUsed: globalCtx.biblRefsUsed, doc, noteCount: 0 };
    let body = '';
    if (content) {
      for (const child of content.children) {
        const tag = child.tagName.toLowerCase();
        if (tag === 'h1') continue;
        if (tag === 'nav') continue;
        if (tag === 'p') body += `<p>${convertStraight(child, ctx)}</p>`;
        else if (tag === 'ul') body += `<list>${[...child.children].map((li) => `<item>${convertStraight(li, ctx)}</item>`).join('')}</list>`;
        else if (tag === 'section') {
          for (const gc of child.children) {
            const gtag = gc.tagName.toLowerCase();
            if (gtag === 'h1') continue;
            if (gtag === 'article') {
              const ah1 = gc.querySelector('h1, h4');
              body += `<div>${ah1 ? `<head>${escapeXml(ah1.textContent.replace(/\s+/g, ' ').trim())}</head>` : ''}`;
              for (const a of gc.children) {
                const atag = a.tagName.toLowerCase();
                if (atag === 'h1' || atag === 'h4') continue;
                if (atag === 'p') body += `<p>${convertStraight(a, ctx)}</p>`;
                else if (atag === 'ul') body += `<list>${[...a.children].map((li) => `<item>${convertStraight(li, ctx)}</item>`).join('')}</list>`;
                else body += convertStraight(a, ctx);
              }
              body += `</div>`;
            } else if (gtag === 'p') body += `<p>${convertStraight(gc, ctx)}</p>`;
            else if (gtag === 'ul') body += `<list>${[...gc.children].map((li) => `<item>${convertStraight(li, ctx)}</item>`).join('')}</list>`;
          }
        } else body += convertStraight(child, ctx);
      }
    }
    globalCtx.noteCount += ctx.noteCount;
    xml += `<div type="page" xml:id="${escapeAttr(id)}"><head>${escapeXml(title)}</head>${body}</div>`;
  }
  return { xml: `<div type="rubrique" xml:id="paratextes"><head>Paratextes</head>${xml}</div>`, pageCount };
}
