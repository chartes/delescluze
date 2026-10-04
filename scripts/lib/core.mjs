// Bibliothèque commune à toutes les rétro-conversions HTML -> TEI de Delescluze.
// - conversion "directe" (non alignée) du balisage sémantique ELEC -> TEI,
//   réutilisée partout où il n'y a qu'un seul état du texte (notes, biographies,
//   bibliographie) ;
// - conversion "alignée" (choice/orig+reg, del, add) pour les paragraphes qui
//   existent en double, édition ET transcription.
import { DOMParser } from 'linkedom';

export const escapeXml = (s) =>
  String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');

export const escapeAttr = (s) => escapeXml(s).replace(/"/g, '&quot;');

export const slug = (s) =>
  String(s ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-zA-Z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase();

const LANG_MAP = { eng: 'en', lat: 'la', fre: 'fr', fra: 'fr' };
export const mapLang = (l) => LANG_MAP[l] ?? l ?? '';

// -- extraction de la fraction de chemin utile à l'@ref à partir d'un href du
// site (../../index-personnes/lettre-L.html#personDelescluzeMarie) --------
export function refFromHref(href) {
  if (!href) return null;
  const hash = href.split('#')[1];
  return hash ? `#${hash}` : null;
}

export function parseHtml(raw) {
  return new DOMParser().parseFromString(raw, 'text/html');
}

// ---------------------------------------------------------------------------
// Conversion directe (pas d'alignement) : utilisée pour le corps des notes,
// les biographies de l'index, la bibliographie, les extraits de teiHeader.
// ---------------------------------------------------------------------------
export function convertStraight(node, ctx = {}) {
  if (!node) return '';
  let out = '';
  for (const child of node.childNodes) out += convertNodeStraight(child, ctx);
  return out;
}

function convertNodeStraight(node, ctx) {
  if (node.nodeType === 3) return escapeXml(node.textContent);
  if (node.nodeType !== 1) return '';
  const tag = node.tagName?.toLowerCase();
  const cls = node.getAttribute?.('class') || '';
  const inner = () => convertStraight(node, ctx);

  // Personnes / lieux liés à l'index --------------------------------------
  if (cls.includes('rs-linked') || cls.includes('persName-linked')) {
    const a = node.querySelector('a.linkToIndex');
    const ref = a ? refFromHref(a.getAttribute('href')) : null;
    const title = a ? a.getAttribute('title') : null;
    const isRs = cls.includes('rs-linked');
    const tagName = isRs ? 'rs' : 'persName';
    const attrs = [ref ? ` ref="${escapeAttr(ref)}"` : '', isRs ? ' type="person"' : '']
      .join('');
    const norm = title ? ` n="${escapeAttr(title)}"` : '';
    if (ref) { if (ctx.refsUsed) { ctx.refsUsed.add(ref); ctx.refsUsed.occ = (ctx.refsUsed.occ||0)+1; } }
    return `<${tagName}${attrs}${norm}>${a ? convertStraight(a, ctx) : inner()}</${tagName}>`;
  }
  if (cls === 'placeName' || cls.split(/\s+/).includes('placeName')) {
    return `<placeName>${inner()}</placeName>`;
  }
  if (cls.split(/\s+/).includes('settlement')) {
    return `<settlement>${inner()}</settlement>`;
  }
  if (cls.includes('linkToIndex')) {
    // persName-linked/rs-linked non détecté au niveau span (rare, lien nu)
    const ref = refFromHref(node.getAttribute('href'));
    if (ref) { if (ctx.refsUsed) { ctx.refsUsed.add(ref); ctx.refsUsed.occ = (ctx.refsUsed.occ||0)+1; } }
    return `<persName${ref ? ` ref="${escapeAttr(ref)}"` : ''}>${inner()}</persName>`;
  }
  if (cls.includes('linkToBibl')) {
    const ref = refFromHref(node.getAttribute('href'));
    if (ref) { if (ctx.biblRefsUsed) { ctx.biblRefsUsed.add(ref); ctx.biblRefsUsed.occ = (ctx.biblRefsUsed.occ||0)+1; } }
    return `<ref type="bibl"${ref ? ` target="${escapeAttr(ref)}"` : ''}>${inner()}</ref>`;
  }
  if (cls.includes('internalLink') || cls === 'top' || cls === 'back') {
    const href = node.getAttribute('href') || '';
    return inner(); // navigation pure : on ne restitue que le texte
  }
  // Notes de bas de page "simples" (introduction, paratextes) : un lien
  // #FootnoteN / #introFootnoteN pointant vers un <p id="..."> de la même
  // page (mécanisme différent de celui, par ancre onmousemove, des lettres
  // et carnets, mais même fonction).
  if (tag === 'a' && (node.getAttribute('href') || '').startsWith('#') && ctx.doc) {
    const targetId = node.getAttribute('href').slice(1);
    const target = targetId && /^[\w.-]+$/.test(targetId) ? ctx.doc.querySelector(`[id="${targetId}"]`) : null;
    // Restreint aux notes de bas de page réelles (toujours un <p id="...">) :
    // les liens "Voir aussi" de l'index des personnes pointent eux aussi en
    // #ancre-locale vers d'autres <article id="personX"> de la même page, ce
    // qui provoquerait une expansion récursive (et parfois circulaire) si on
    // les traitait comme des notes.
    if (target && target !== node && target.tagName?.toLowerCase() === 'p' && !target.contains(node)) {
      const clone = target.cloneNode(true);
      const numEl = clone.querySelector('.number');
      let n = '';
      if (numEl) { n = numEl.textContent.replace(/\D/g, ''); numEl.remove(); }
      ctx.noteCount = (ctx.noteCount || 0) + 1;
      return `<note xml:id="${escapeAttr((ctx.pageId || 'note') + '-' + targetId)}" n="${escapeAttr(n)}" type="edition">${convertStraight(clone, ctx).trim()}</note>`;
    }
  }
  if (cls.includes('externalLink')) {
    const href = node.getAttribute('href') || '';
    return `<ref target="${escapeAttr(href)}">${inner()}</ref>`;
  }
  if (tag === 'cite') {
    const m = /level-([a-z]?)/.exec(cls);
    const level = m && m[1] ? m[1] : 'm';
    return `<title level="${escapeAttr(level)}">${inner()}</title>`;
  }
  if (cls === 'author') return `<author>${inner()}</author>`;
  if (cls === 'surname') return `<surname>${inner()}</surname>`;
  if (cls === 'forename') return `<forename>${inner()}</forename>`;
  if (cls === 'pubPlace') return `<pubPlace>${inner()}</pubPlace>`;
  if (cls === 'publisher') return `<publisher>${inner()}</publisher>`;
  if (cls === 'date') return `<date>${inner()}</date>`;
  if (cls === 'biblScope') return `<biblScope>${inner()}</biblScope>`;
  if (cls === 'ref') return `<note type="reference">${inner()}</note>`;
  if (cls === 'number') return ''; // numéro de note affiché par le site, régénéré côté rendu
  if (cls.includes('title_underline') || cls === 'title') return `<title>${inner()}</title>`;
  if (tag === 'sup') return `<hi rend="sup">${inner()}</hi>`;
  if (tag === 'em') return `<hi rend="italic">${inner()}</hi>`;
  if (tag === 'br') return ' ';
  if (tag === 'span' && cls === '') return inner();
  if (tag === 'span') return inner();
  return inner();
}

// ---------------------------------------------------------------------------
// Résolution des notes rattachées à une ancre a[onmousemove*=noteId]
// ---------------------------------------------------------------------------
export function findNoteAnchors(root) {
  const anchors = [];
  for (const a of root.querySelectorAll('a[onmousemove*="noteId"]')) {
    const m = /noteId\s*=\s*'([^']+)'/.exec(a.getAttribute('onmousemove') || '');
    if (m) anchors.push({ el: a, noteId: m[1] });
  }
  return anchors;
}

export function noteBodyById(notesArticle, id) {
  if (!notesArticle) return null;
  return notesArticle.querySelector(`[id="${id}"]`);
}

// ---------------------------------------------------------------------------
// Tokenisation pour alignement : transforme un fragment édition OU
// transcription en liste de tokens comparables mot à mot.
// ---------------------------------------------------------------------------
function normCmp(s) {
  return s
    .toLowerCase()
    .replace(/[’‘]/g, "'")
    .replace(/^[«»"'.,;:!?()\[\]—–-]+|[«»"'.,;:!?()\[\]—–-]+$/g, '')
    .trim();
}

let zeroCounter = 0;
const nextZeroId = () => `z${zeroCounter++}`;

// Marche dans le DOM et produit un flux plat de tokens :
//  { cmp, out, deleted, isPb }
// Les décorations sans largeur (notes, marqueurs apparat, sup) sont fondues
// dans le token précédent (ou suivant si aucun n'existe encore).
export function tokenize(node, ctx) {
  const tokens = [];
  let pendingSuffix = '';
  let pendingPrefix = '';

  const pushWord = (word, cmp, deleted) => {
    if (!word) return;
    // Un "mot" fait uniquement de ponctuation (cmp vide) n'est pas fiable a
    // apparier seul : l'autre canal l'a souvent soude au mot voisin. On le
    // rattache au token precedent plutot que de creer un token orphelin qui
    // provoquerait un <add>/<del> parasite sur la seule ponctuation.
    if (!deleted && cmp === '' && tokens.length) {
      tokens[tokens.length - 1].out += (pendingPrefix + word);
      pendingPrefix = '';
      return;
    }
    const out = pendingPrefix + word;
    pendingPrefix = '';
    tokens.push({ cmp: deleted ? `zdel${nextZeroId()}` : cmp, out, deleted: !!deleted, plain: word.replace(/<[^>]+>/g, '') });
  };
  const attachSuffix = (xml) => {
    if (tokens.length) tokens[tokens.length - 1].out += xml;
    else pendingPrefix += xml;
  };
  const attachPrefix = (xml) => {
    pendingPrefix += xml;
  };

  const walk = (n, opts) => {
    if (n.nodeType === 3) {
      const text = n.textContent;
      const words = text.split(/(\s+)/).filter((w) => w !== '');
      for (const w of words) {
        if (/^\s+$/.test(w)) continue;
        pushWord(escapeXml(w), normCmp(w), opts.deleted);
      }
      return;
    }
    if (n.nodeType !== 1) return;
    const tag = n.tagName.toLowerCase();
    const cls = n.getAttribute('class') || '';

    // Ancre de note (édition) -----------------------------------------
    if (tag === 'a' && /noteId/.test(n.getAttribute('onmousemove') || '')) {
      const m = /noteId\s*=\s*'([^']+)'/.exec(n.getAttribute('onmousemove'));
      if (m && ctx.resolveNote) {
        const xml = ctx.resolveNote(m[1]);
        if (xml) attachSuffix(xml);
      }
      return;
    }
    // Marqueur d'apparat (transcription) --------------------------------
    if (cls.includes('noteAnchor')) return; // le texte "[a]" lui-même est ignoré
    if (cls.includes('apparatusNote')) {
      const letterMatch = /^([a-z])\.\s*/i.exec(n.textContent.trim());
      const label = letterMatch ? letterMatch[1] : slug(n.textContent).slice(0, 4);
      const body = n.textContent.replace(/^[a-z]\.\s*/i, '');
      attachSuffix(`<note type="apparatus" xml:id="${escapeAttr(ctx.pageId + '-app-' + label)}" n="${escapeAttr(label)}">${escapeXml(body)}</note>`);
      return;
    }
    if (cls.includes('editorialComment')) {
      attachSuffix(`<note type="editorial">${escapeXml(n.textContent.trim())}</note>`);
      return;
    }
    if (tag === 'sup') {
      attachSuffix(`<hi rend="sup">${escapeXml(n.textContent)}</hi>`);
      return;
    }
    // Rupture de page (marqueur inline, distinct du pb de tête de page) -
    if (cls.split(/\s+/).includes('pb')) {
      pushWord('<pb break="no"/>', ' pb', opts.deleted);
      ctx.inlinePbCount && ctx.inlinePbCount();
      return;
    }
    // Suppression (transcription) ---------------------------------------
    if (tag === 'del' || cls.includes('deleted')) {
      for (const c of n.childNodes) walk(c, { ...opts, deleted: true });
      return;
    }
    // Personnes / rs liées -------------------------------------------
    if (cls.includes('rs-linked') || cls.includes('persName-linked')) {
      const a = n.querySelector('a.linkToIndex');
      const ref = a ? refFromHref(a.getAttribute('href')) : null;
      const isRs = cls.includes('rs-linked');
      const tagName = isRs ? 'rs' : 'persName';
      if (ref) { if (ctx.refsUsed) { ctx.refsUsed.add(ref); ctx.refsUsed.occ = (ctx.refsUsed.occ||0)+1; } }
      const text = n.textContent.replace(/\s+/g, ' ').trim();
      const xml = `<${tagName}${ref ? ` ref="${escapeAttr(ref)}"` : ''}${isRs ? ' type="person"' : ''}>${escapeXml(text)}</${tagName}>`;
      pushWord(xml, normCmp(text), opts.deleted);
      return;
    }
    if (cls.split(/\s+/).includes('placeName')) {
      const settlement = n.querySelector('.settlement');
      const text = n.textContent.replace(/\s+/g, ' ').trim();
      const xml = settlement
        ? `<placeName><settlement>${escapeXml(settlement.textContent.trim())}</settlement></placeName>`
        : `<placeName>${escapeXml(text)}</placeName>`;
      pushWord(xml, normCmp(text), opts.deleted);
      return;
    }
    if (cls.includes('title_underline') || cls === 'title') {
      const text = n.textContent.replace(/\s+/g, ' ').trim();
      pushWord(`<title>${escapeXml(text)}</title>`, normCmp(text), opts.deleted);
      return;
    }
    // "lem" (passages en langue étrangère des carnets) et "em" (mise en
    // relief) peuvent contenir plusieurs mots : les traiter comme des
    // décorations préfixe/suffixe romprait la balise ouvrante et la balise
    // fermante si un choice/reg venait à s'intercaler entre les deux (bonne
    // formation XML cassée). On les rend donc atomiques : un seul token,
    // converti sans alignement mot à mot interne (mais toujours bien formé).
    if (cls === 'lem') {
      const lang = mapLang(n.getAttribute('lang'));
      const text = n.textContent.replace(/\s+/g, ' ').trim();
      const xml = `<foreign${lang ? ` xml:lang="${escapeAttr(lang)}"` : ''}>${convertStraight(n, ctx).trim()}</foreign>`;
      pushWord(xml, normCmp(text), opts.deleted);
      return;
    }
    if (tag === 'em') {
      const text = n.textContent.replace(/\s+/g, ' ').trim();
      pushWord(`<hi rend="italic">${convertStraight(n, ctx).trim()}</hi>`, normCmp(text), opts.deleted);
      return;
    }
    if (tag === 'br') return;
    // Par défaut : descendre dans les enfants (span sans classe connue, etc.)
    for (const c of n.childNodes) walk(c, opts);
  };

  for (const c of node.childNodes) walk(c, { deleted: false });
  return tokens;
}

// ---------------------------------------------------------------------------
// Alignement mot à mot par LCS (programmation dynamique, O(n*m) — les
// paragraphes sont courts, ça reste rapide sur tout le corpus).
// ---------------------------------------------------------------------------
function lcsOps(a, b) {
  const n = a.length, m = b.length;
  const dp = Array.from({ length: n + 1 }, () => new Uint16Array(m + 1));
  for (let i = n - 1; i >= 0; i--) {
    for (let j = m - 1; j >= 0; j--) {
      dp[i][j] = a[i].cmp === b[j].cmp ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  const ops = [];
  let i = 0, j = 0;
  while (i < n && j < m) {
    if (a[i].cmp === b[j].cmp) { ops.push(['eq', i, j]); i++; j++; }
    else if (dp[i + 1][j] >= dp[i][j + 1]) { ops.push(['a', i, -1]); i++; }
    else { ops.push(['b', -1, j]); j++; }
  }
  while (i < n) { ops.push(['a', i, -1]); i++; }
  while (j < m) { ops.push(['b', -1, j]); j++; }
  return ops;
}

// Fusionne transcription (orig) et édition (reg) pour un couple de tokens.
// Retourne { xml, matched, total } où matched/total servent au calcul de
// qualité d'alignement (pour le repli paragraphe entier + journal).
export function mergeTokens(transcriptionTokens, editionTokens) {
  const ops = lcsOps(transcriptionTokens, editionTokens);
  let xml = '';
  let matched = 0;
  const total = Math.max(transcriptionTokens.length, editionTokens.length) || 1;
  let i = 0;
  while (i < ops.length) {
    const [kind] = ops[i];
    if (kind === 'eq') {
      xml += (xml ? ' ' : '') + editionTokens[ops[i][2]].out;
      matched++;
      i++;
      continue;
    }
    // Regrouper une plage contiguë a/b jusqu'au prochain 'eq'
    let runA = [], runB = [];
    while (i < ops.length && ops[i][0] !== 'eq') {
      if (ops[i][0] === 'a') runA.push(transcriptionTokens[ops[i][1]]);
      else runB.push(editionTokens[ops[i][2]]);
      i++;
    }
    const delOnly = runA.filter((t) => t.deleted);
    const otherA = runA.filter((t) => !t.deleted);
    if (delOnly.length) {
      xml += (xml ? ' ' : '') + `<del>${delOnly.map((t) => t.plain).join(' ')}</del>`;
    }
    if (otherA.length && runB.length) {
      xml += (xml ? ' ' : '') +
        `<choice><orig>${escapeXml(otherA.map((t) => t.plain).join(' '))}</orig><reg>${runB.map((t) => t.out).join(' ')}</reg></choice>`;
    } else if (otherA.length) {
      // présent seulement côté transcription, pas marqué supprimé : cas
      // suspect, on l'encode comme suppression tout de même mais on le
      // signale via le indicateur de qualité (matched non incrémenté).
      xml += (xml ? ' ' : '') + `<del>${otherA.map((t) => t.plain).join(' ')}</del>`;
    } else if (runB.length) {
      xml += (xml ? ' ' : '') + `<add>${runB.map((t) => t.out).join(' ')}</add>`;
    }
  }
  return { xml: xml.trim(), quality: matched / total };
}

export function tokensPlain(el) {
  return (el?.textContent || '').replace(/\s+/g, ' ').trim();
}

const QUALITY_THRESHOLD = 0.5;

// Aligne une "feuille" (élément textuel appairé édition/transcription : un
// <p>, une <time>, un <span class="dateline"> ...) et journalise tout cas non
// alignable au lieu de fusionner en silence.
export function alignLeaf(editionEl, transcriptionEl, ctx, label) {
  if (!editionEl && !transcriptionEl) return '';
  if (!transcriptionEl) {
    ctx.log.push({ page: ctx.pageId, leaf: label, type: 'transcription-absente' });
    return convertStraight(editionEl, ctx);
  }
  if (!editionEl) {
    ctx.log.push({ page: ctx.pageId, leaf: label, type: 'edition-absente' });
    // Pas de forme régularisée en face : rien à "choisir", on restitue le
    // texte diplomatique tel quel plutôt que d'ouvrir un <choice> à une
    // seule branche (non conforme au modèle TEI, qui en attend au moins deux).
    return escapeXml(tokensPlain(transcriptionEl));
  }
  const transcriptionTokens = tokenize(transcriptionEl, ctx);
  const editionTokens = tokenize(editionEl, ctx);
  if (!transcriptionTokens.length && !editionTokens.length) return '';
  const { xml, quality } = mergeTokens(transcriptionTokens, editionTokens);
  if (quality < QUALITY_THRESHOLD) {
    ctx.log.push({ page: ctx.pageId, leaf: label, type: 'repli-paragraphe-entier', quality: quality.toFixed(2) });
    return `<choice><orig>${escapeXml(tokensPlain(transcriptionEl))}</orig><reg>${convertStraight(editionEl, ctx)}</reg></choice>`;
  }
  return xml;
}

// Aligne deux listes d'éléments frères (ex. les <p> d'un même <div>, les <div>
// jours d'une même page d'éphémérides) en les appariant par position ; toute
// différence de nombre est journalisée puis traitée en repli page entière par
// l'appelant (le nombre de "feuilles" alignées un à un reste fiable sinon).
export function pairByPosition(editionList, transcriptionList, ctx, label) {
  const n = Math.max(editionList.length, transcriptionList.length);
  if (editionList.length !== transcriptionList.length) {
    ctx.log.push({
      page: ctx.pageId,
      leaf: label,
      type: 'nombre-different',
      edition: editionList.length,
      transcription: transcriptionList.length
    });
  }
  const pairs = [];
  for (let i = 0; i < n; i++) pairs.push([editionList[i] || null, transcriptionList[i] || null]);
  return pairs;
}

// ---------------------------------------------------------------------------
// Chargement générique d'une page moissonnée : articles édition/transcription,
// notes d'édition, facsimilé (image + cote AN + lien visionneuse).
// ---------------------------------------------------------------------------
export function loadPage(doc) {
  const editionArticle = doc.querySelector('#edition-text');
  const transcriptionArticle = doc.querySelector('#transcription-text');
  const editionNotes = doc.querySelector('#edition-notes');
  const transcriptionNotes = doc.querySelector('#transcription-notes');
  const facsFigure = doc.querySelector('#facsimile figure');
  let facsimile = null;
  if (facsFigure) {
    const img = facsFigure.querySelector('img');
    const link = facsFigure.querySelector('a');
    const figcaption = facsFigure.querySelector('figcaption');
    facsimile = {
      src: img ? img.getAttribute('src') : null,
      cote: figcaption ? figcaption.textContent.trim() : (img ? img.getAttribute('title') : ''),
      viewer: link ? link.getAttribute('href') : null
    };
  }
  return { editionArticle, transcriptionArticle, editionNotes, transcriptionNotes, facsimile };
}

// Fabrique une fonction resolveNote(id) qui va chercher le corps de la note
// dans l'article de notes fourni et le convertit (sans alignement : les notes
// n'ont pas de second état).
export function makeNoteResolver(notesArticle, pageId, ctx, type) {
  return (id) => {
    const body = noteBodyById(notesArticle, id);
    if (!body) return null;
    const clone = body.cloneNode(true);
    const numEl = clone.querySelector('.number');
    const n = numEl ? numEl.textContent.replace(/\D/g, '') : '';
    if (numEl) numEl.remove();
    ctx.noteCount = (ctx.noteCount || 0) + 1;
    return `<note xml:id="${escapeAttr(pageId + '-' + id)}" n="${escapeAttr(n)}" type="${escapeAttr(type)}">${convertStraight(clone, ctx).trim()}</note>`;
  };
}

// Chemin local de l'image de facsimilé, rebasé pour dots-vue (comme
// bellelay/img : servi depuis public/<corpus>/img/).
export function localImagePath(src, baseUrl) {
  if (!src) return null;
  const abs = new URL(src, baseUrl);
  return abs.pathname.split('/').pop();
}

let pbCounter = 0;
// Assemble une <div type="page"> : pb + figure de facsimilé + contenu déjà
// converti. Un <pb/> par page moissonnée -- c'est le compte de contrôle
// "pages moissonnées vs pb dans le TEI".
export function buildPageDiv(pageId, n, facsimile, innerXml, extraType) {
  pbCounter++;
  const facsXml = facsimile && facsimile.src
    ? `<facsimile xml:id="facs-${escapeAttr(pageId)}"><graphic url="/delescluze/img/${escapeAttr(localImagePath(facsimile.src, 'http://elec.enc.sorbonne.fr/delescluze/'))}"><desc>${escapeXml(facsimile.cote || '')}</desc></graphic>${facsimile.viewer ? `<ptr type="viewer" target="${escapeAttr(facsimile.viewer)}"/>` : ''}</facsimile>`
    : '';
  const pbAttrs = [
    ` xml:id="pb-${escapeAttr(pageId)}"`,
    n != null ? ` n="${escapeAttr(String(n))}"` : '',
    facsimile && facsimile.src ? ` facs="#facs-${escapeAttr(pageId)}"` : ''
  ].join('');
  return `<div type="page" xml:id="${escapeAttr(pageId)}">${facsXml}<pb${pbAttrs}/>${innerXml}</div>`;
}
export function pbEmittedCount() { return pbCounter; }

// Aligne une table.account (comptes des éphémérides) ligne à ligne puis
// cellule à cellule.
export function alignTable(eTable, tTable, ctx, label) {
  const eRows = eTable ? [...eTable.querySelectorAll('tr')] : [];
  const tRows = tTable ? [...tTable.querySelectorAll('tr')] : [];
  if (eRows.length !== tRows.length) {
    ctx.log.push({ page: ctx.pageId, leaf: label, type: 'nombre-different-lignes-table', edition: eRows.length, transcription: tRows.length });
  }
  const n = Math.max(eRows.length, tRows.length);
  let rows = '';
  for (let i = 0; i < n; i++) {
    const eRow = eRows[i] || null, tRow = tRows[i] || null;
    const eCells = eRow ? [...eRow.children] : [];
    const tCells = tRow ? [...tRow.children] : [];
    const m = Math.max(eCells.length, tCells.length);
    let cells = '';
    for (let j = 0; j < m; j++) {
      const eCell = eCells[j] || null, tCell = tCells[j] || null;
      const isLabel = (eCell || tCell)?.tagName?.toLowerCase() === 'th';
      const colspan = (eCell || tCell)?.getAttribute?.('colspan');
      const xml = alignLeaf(eCell, tCell, ctx, `${label}-r${i}c${j}`);
      cells += `<cell${isLabel ? ' role="label"' : ''}${colspan ? ` cols="${escapeAttr(colspan)}"` : ''}>${xml}</cell>`;
    }
    rows += `<row>${cells}</row>`;
  }
  return `<table>${rows}</table>`;
}
