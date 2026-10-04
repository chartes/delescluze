// Reconstruction du teiHeader depuis credits.html / mentions-legales.html /
// le-projet/choix-editoriaux.html. Ce header N'EST PAS le header d'origine
// (il n'existe pas de source TEI publiée) : la reconstruction est signalée
// explicitement dans revisionDesc, comme l'exige le brief.
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { parseHtml, escapeXml } from './lib/core.mjs';

export async function buildHeader() {
  const credits = parseHtml(await readFile(resolve('data/legacy/credits.html'), 'utf8'));
  const mentions = parseHtml(await readFile(resolve('data/legacy/mentions-legales.html'), 'utf8'));

  const creditItems = [...credits.querySelectorAll('#content ul li')].map((li) => li.textContent.replace(/\s+/g, ' ').trim());
  // "Édition critique des documents, ... : Benjamin d'Anfray et Natalia Pashkeeva, sous la direction de Christine Nougaret (École nationale des chartes, Centre Jean-Mabillon)"
  const respStmts = creditItems.map((line) => {
    const [role, names] = line.split(/\s*:\s*/, 2);
    if (!names) return '';
    return `<respStmt><resp>${escapeXml(role)}</resp><name>${escapeXml(names)}</name></respStmt>`;
  }).join('');

  const licenceText = mentions.querySelector('#content')?.textContent || '';
  const licenceMatch = /Paternité[^.]*\.(?:[^.]*2\.0 France[^.]*\.)?/i.exec(licenceText);

  const today = new Date().toISOString().slice(0, 10);

  return `<teiHeader>
    <fileDesc>
      <titleStmt>
        <title>Édition critique des carnets de prison et de la correspondance privée d’Henri Delescluze à Belle-Île (1851-1853)</title>
        <author>Henri Delescluze</author>
        ${respStmts}
        <principal>Christine Nougaret</principal>
      </titleStmt>
      <publicationStmt>
        <publisher>École nationale des chartes – PSL</publisher>
        <date>2015</date>
        <availability>
          <licence target="https://creativecommons.org/licenses/by-nc-nd/2.0/fr/">Creative Commons — Paternité, Pas d’utilisation commerciale, Pas de modification ; 2.0 France${licenceMatch ? '' : ''}</licence>
        </availability>
      </publicationStmt>
      <sourceDesc>
        <p>Documents originaux : Archives nationales, 494AP/1 (fonds Delescluze). Numérisation en mode image : Alain Berry et Jean-Yves Leridant (Archives nationales, direction de l’Appui scientifique, département de la Conservation, service Image).</p>
        <p>Édition électronique originellement publiée par l’École nationale des chartes sous forme de site XHTML statique produit par transformation XSLT d’un document TEI :
          <ref target="http://elec.enc.sorbonne.fr/delescluze/">http://elec.enc.sorbonne.fr/delescluze/</ref>. Édition liée à la thèse d’École des chartes de Benjamin d’Anfray (2012).</p>
      </sourceDesc>
    </fileDesc>
    <encodingDesc>
      <projectDesc>
        <p>Ce document TEI a été reconstruit par rétro-conversion du site XHTML publié (le dépôt des sources TEI d’origine n’est pas accessible : dépôt GitHub vide, /src/ en erreur 500). Le HTML publié étant lui-même une sortie XSLT d’un document TEI, il a conservé les noms d’éléments TEI dans ses attributs @class, ce qui a permis une restitution assez fidèle : persName/rs avec @ref vers l’index des personnes, placeName, pb, notes rattachées à leur ancre, opener/dateline/salute, apparat critique, biblStruct simplifiés, facsimile/graphic, métadonnées de correspondance, et un listPerson conservant les @xml:id d’origine.</p>
        <p>Chaque page publiait deux états du texte : une édition normalisée et une transcription diplomatique. Ils ont été fusionnés dans un seul flux TEI via choice/orig+reg, del et add, par alignement automatique mot à mot (programmation dynamique / plus longue sous-séquence commune) entre les deux paragraphes correspondants. Les cas non alignables avec confiance suffisante ont été repliés sur un choix au niveau du paragraphe entier et journalisés (voir logs/alignment-log.tsv) plutôt que fusionnés en silence.</p>
      </projectDesc>
    </encodingDesc>
    <profileDesc>
      <langUsage>
        <language ident="fr">Français</language>
        <language ident="en">Anglais (passages des carnets)</language>
        <language ident="la">Latin (passages des carnets)</language>
      </langUsage>
    </profileDesc>
    <revisionDesc>
      <change when="${today}" who="#retro-conversion">
        <p><hi rend="bold">Ce teiHeader est une reconstruction, PAS le header d’origine.</hi> Aucune source TEI n’était accessible pour ce corpus (dépôt GitHub vide, /src/ en erreur 500 au moment de la migration). Il a été rédigé à partir du contenu de credits.html, mentions-legales.html et le-projet/choix-editoriaux.html du site publié, et le corps du document a été rétro-converti depuis le HTML publié (voir projectDesc). Les @xml:id techniques générés par le moteur XSLT d’origine (type d2e27110) n’ont pas été conservés ; les @xml:id de l’index des personnes (article/@id du site) ont en revanche été conservés tels quels.</p>
      </change>
    </revisionDesc>
  </teiHeader>`;
}
