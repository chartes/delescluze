// Assemble le document TEI unique de Delescluze à partir des rétro-conversions
// par rubrique, ajoute le teiHeader reconstruit, écrit les sorties (data/ +
// dots-import/data/), calcule et journalise les contrôles quantitatifs.
import { mkdir, writeFile, readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { DOMParser as XmlDomParser } from '@xmldom/xmldom';
import { pbEmittedCount } from './lib/core.mjs';
import { convertIntroduction } from './convert-introduction.mjs';
import { convertEphemerides } from './convert-ephemerides.mjs';
import { convertPassages } from './convert-passages.mjs';
import { convertLettres } from './convert-lettres.mjs';
import { convertIndexPersonnes } from './convert-index-personnes.mjs';
import { convertBibliographie } from './convert-bibliographie.mjs';
import { convertParatextes } from './convert-paratextes.mjs';
import { buildHeader } from './build-header.mjs';

const globalCtx = {
  log: [],
  refsUsed: new Set(),
  biblRefsUsed: new Set(),
  noteCount: 0,
  refOccurrences: 0,
  biblRefOccurrences: 0,
  inlinePb: 0
};

console.log('Conversion introduction...');
const introduction = await convertIntroduction(globalCtx);
console.log('Conversion éphémérides...');
const ephemerides = await convertEphemerides(globalCtx);
console.log('Conversion passages rédigés...');
const passages = await convertPassages(globalCtx);
console.log('Conversion lettres...');
const lettres = await convertLettres(globalCtx);
console.log('Conversion index des personnes...');
const indexPersonnes = await convertIndexPersonnes(globalCtx);
console.log('Conversion bibliographie...');
const bibliographie = await convertBibliographie(globalCtx);
console.log('Conversion paratextes...');
const paratextes = await convertParatextes(globalCtx);
console.log('Construction du teiHeader...');
const header = await buildHeader();

const body = [
  paratextes.xml,
  introduction.xml,
  ephemerides.xml,
  passages.xml,
  lettres.xml
].join('\n');

const refsDecl = `<encodingDesc>
      <refsDecl n="delescluze">
        <citeStructure unit="rubrique" match="/TEI/text/body/div[@type='rubrique']" use="@xml:id">
          <citeData property="title" use="head[1]"/>
          <citeStructure unit="groupe" match="div[@type='lettre' or @type='carnet' or @type='passage']" use="@xml:id">
            <citeData property="title" use="head[1]"/>
            <citeStructure unit="page" match="div[@type='page']" use="@xml:id">
              <citeData property="title" use="@xml:id"/>
            </citeStructure>
          </citeStructure>
          <citeStructure unit="page" match="div[@type='page']" use="@xml:id">
            <citeData property="title" use="head[1]"/>
          </citeStructure>
        </citeStructure>
      </refsDecl>
    </encodingDesc>`;

const tei = `<?xml version="1.0" encoding="UTF-8"?>
<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="delescluze-edition">
  ${header}
  ${refsDecl}
  <text>
    <body>
${body}
    </body>
    <back>
${indexPersonnes.xml}
${bibliographie.xml}
    </back>
  </text>
</TEI>
`;

await mkdir(resolve('data'), { recursive: true });
await mkdir(resolve('dots-import/data'), { recursive: true });
await writeFile(resolve('data/delescluze.xml'), tei, 'utf8');
await writeFile(resolve('dots-import/data/delescluze.xml'), tei, 'utf8');

// --- Contrôles obligatoires --------------------------------------------
await mkdir(resolve('logs'), { recursive: true });

// 1. Bonne formation XML (parseur XML strict, pas le mode HTML tolérant)
let wellFormed = true;
let wellFormedError = '';
try {
  const errors = [];
  const parser = new XmlDomParser({
    onError: (level, msg) => errors.push(`${level}: ${msg}`)
  });
  parser.parseFromString(tei, 'application/xml');
  const fatal = errors.filter((e) => /error/i.test(e));
  if (fatal.length) { wellFormed = false; wellFormedError = fatal.slice(0, 5).join(' | '); }
} catch (e) {
  wellFormed = false;
  wellFormedError = e.message;
}

// 2. pages moissonnées vs pb émis
const pagesHarvestedTsv = await readFile(resolve('logs/harvest-pages.tsv'), 'utf8').catch(() => '');
const harvestedPaths = new Set(
  pagesHarvestedTsv.trim().split('\n').slice(1).map((l) => l.split('\t')[0])
);
const pagesHarvested = harvestedPaths.size; // fichiers distincts (index.html a été atteint par 2 URLs différentes)
const pbEmitted = pbEmittedCount();

// 3. cibles cassées (refs @ref vers listPerson / vers listBibl)
const brokenPersonRefs = [...globalCtx.refsUsed].filter((ref) => !indexPersonnes.knownIds.has(ref.slice(1)));
const brokenBiblRefs = [...globalCtx.biblRefsUsed].filter((ref) => !bibliographie.knownIds.has(ref.slice(1)));

// 4. journal des cas d'alignement non résolus
const alignLog = globalCtx.log;
const alignLogTsv = 'page\tfeuille\ttype\tdetail\n' + alignLog
  .map((e) => `${e.page}\t${e.leaf}\t${e.type}\t${JSON.stringify({ ...e, page: undefined, leaf: undefined, type: undefined })}`)
  .join('\n');
await writeFile(resolve('logs/alignment-log.tsv'), alignLogTsv + '\n', 'utf8');

const brokenRefsTsv = 'ref\ttype\n' +
  brokenPersonRefs.map((r) => `${r}\tpersonne`).join('\n') +
  (brokenPersonRefs.length && brokenBiblRefs.length ? '\n' : '') +
  brokenBiblRefs.map((r) => `${r}\tbibl`).join('\n');
await writeFile(resolve('logs/broken-refs.tsv'), brokenRefsTsv + '\n', 'utf8');

const report = {
  xmlBienForme: wellFormed,
  xmlErreur: wellFormedError,
  pagesMoissonnees: pagesHarvested,
  pagesConverties: introduction.pageCount + ephemerides.pageCount + passages.pageCount + lettres.pageCount + paratextes.pageCount + indexPersonnes.pageCount + 1,
  pagesParRubrique: {
    introduction: introduction.pageCount,
    ephemerides: ephemerides.pageCount,
    'passages-rediges': passages.pageCount,
    lettres: lettres.pageCount,
    paratextes: paratextes.pageCount,
    'index-personnes': indexPersonnes.pageCount,
    'sources-et-bibliographie': 1
  },
  pagesAvecFacsimileEtPb: ephemerides.pageCount + passages.pageCount + lettres.pageCount,
  pbEmisDansTEI: pbEmitted,
  notes: globalCtx.noteCount,
  renvoisIndexPersonneOccurrences: globalCtx.refsUsed.occ || 0,
  renvoisIndexPersonneCiblesUniques: globalCtx.refsUsed.size,
  renvoisBiblOccurrences: globalCtx.biblRefsUsed.occ || 0,
  personnesIndex: indexPersonnes.personCount,
  pagesIndexPersonnes: indexPersonnes.pageCount,
  entreesBibliographie: bibliographie.count,
  casAlignementJournalises: alignLog.length,
  detailAlignement: alignLog.reduce((acc, e) => { acc[e.type] = (acc[e.type] || 0) + 1; return acc; }, {}),
  ciblesCasseesPersonnes: brokenPersonRefs.length,
  ciblesCasseesBibl: brokenBiblRefs.length,
  pbInlineContinuation: (tei.match(/<pb break="no"\/>/g) || []).length,
  pbPageLevel: (tei.match(/<pb xml:id="pb-/g) || []).length
};

await writeFile(resolve('logs/controles.json'), JSON.stringify(report, null, 2), 'utf8');
console.log(JSON.stringify(report, null, 2));
