// Moisson du site ÉLEC "Delescluze" — suit les liens, ne devine aucune URL.
// Sérialise les requêtes (délai entre chaque fetch) pour ne pas bombarder le serveur.
// Écrit le miroir HTML dans data/legacy/<chemin d'origine>, journalise les échecs,
// et prépare la liste des images (facsimilés AN) à rapatrier séparément.
import { mkdir, writeFile, appendFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';

const root = new URL('http://elec.enc.sorbonne.fr/delescluze/');
const destination = resolve('data/legacy');
const logPath = resolve('logs/harvest-errors.log');
const imagesLogPath = resolve('logs/images-manifest.tsv');
const pagesLogPath = resolve('logs/harvest-pages.tsv');
const DELAY_MS = 300;

const ACCEPT = { 'Accept-Charset': 'utf-8', 'User-Agent': 'delescluze-migration-mirror/1.0 (serialized, one request at a time)' };

const decode = (buffer) => {
  const bytes = new Uint8Array(buffer);
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  } catch {
    return new TextDecoder('windows-1252').decode(bytes);
  }
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Chemin relatif au dossier racine du corpus (sans domaine), utilisé comme
// nom de fichier local ET comme identifiant stable pour le retour arrière.
const relPath = (url) => {
  const u = new URL(url);
  let p = u.pathname.replace(/^\/delescluze\/?/, '');
  if (p === '' || p.endsWith('/')) p += 'index.html';
  return p;
};

await mkdir(destination, { recursive: true });
await mkdir(resolve('logs'), { recursive: true });
await writeFile(logPath, '', 'utf8');
await writeFile(imagesLogPath, 'url\tsourcePage\n', 'utf8');
await writeFile(pagesLogPath, 'path\turl\tbytes\n', 'utf8');

const queue = [root.href];
const seen = new Set(queue);
const images = new Map(); // url -> Set(sourcePages)
let ok = 0, failed = 0;

while (queue.length) {
  const url = queue.shift();
  const path = relPath(url);
  try {
    const response = await fetch(url, { headers: ACCEPT });
    if (!response.ok) {
      failed++;
      await appendFile(logPath, `HTTP ${response.status}\t${url}\n`, 'utf8');
      await sleep(DELAY_MS);
      continue;
    }
    const html = decode(await response.arrayBuffer());

    // Liens internes .html (pages) — on ne suit que ce qui existe réellement.
    for (const match of html.matchAll(/\bhref\s*=\s*"([^"#?]+\.html)(#[^"]*)?"/gi)) {
      const link = new URL(match[1], url);
      if (link.origin === root.origin && link.pathname.startsWith(root.pathname) && !seen.has(link.href)) {
        seen.add(link.href);
        queue.push(link.href);
      }
    }
    // Images de contenu (facsimilés AN), PAS les assets de thème.
    for (const match of html.matchAll(/\bsrc\s*=\s*"(images\/[^"]+)"/gi)) {
      const imgUrl = new URL(match[1], url).href;
      if (!images.has(imgUrl)) images.set(imgUrl, new Set());
      images.get(imgUrl).add(path);
    }

    const outFile = resolve(destination, path);
    await mkdir(dirname(outFile), { recursive: true });
    await writeFile(outFile, html, 'utf8');
    await appendFile(pagesLogPath, `${path}\t${url}\t${html.length}\n`, 'utf8');
    ok++;
    if (ok % 20 === 0) console.log(`${ok} pages moissonnées (file d'attente : ${queue.length})`);
  } catch (error) {
    failed++;
    await appendFile(logPath, `ERREUR ${error.message}\t${url}\n`, 'utf8');
  }
  await sleep(DELAY_MS);
}

const imageLines = [...images.entries()].flatMap(([url, pages]) => [...pages].map((p) => `${url}\t${p}`));
await writeFile(imagesLogPath, 'url\tsourcePage\n' + imageLines.join('\n') + '\n', 'utf8');

console.log(`Terminé : ${ok} pages moissonnées, ${failed} échecs (voir logs/harvest-errors.log).`);
console.log(`${images.size} images de contenu repérées (voir logs/images-manifest.tsv), rapatriement séparé via harvest-images.mjs.`);
