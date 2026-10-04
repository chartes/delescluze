// Rapatrie les images de contenu (facsimilés des Archives nationales
// images/FRAN_*.jpg + figures d'introduction introduction/images/*.jpg)
// en relisant les pages déjà moissonnées dans data/legacy/ (pas de nouvelle
// requête HTML). Téléchargement sérialisé, avec journal des échecs.
import { mkdir, writeFile, appendFile, readFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { globSync } from 'node:fs';

const root = new URL('http://elec.enc.sorbonne.fr/delescluze/');
const legacyDir = resolve('data/legacy');
const imgDir = resolve('data/img');
const logPath = resolve('logs/images-errors.log');
const DELAY_MS = 250;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

await mkdir(imgDir, { recursive: true });
await writeFile(logPath, '', 'utf8');

const files = globSync('data/legacy/**/*.html');
const images = new Map(); // absolute url -> local filename

for (const file of files) {
  const html = await readFile(file, 'utf8');
  // URL de la page d'origine, pour résoudre les chemins relatifs (n'importe
  // quel nombre de "../").
  const relFromLegacy = file.replace(/^data[\\/]legacy[\\/]/, '').replace(/\\/g, '/');
  const pageUrl = new URL(relFromLegacy, root);
  for (const match of html.matchAll(/\bsrc\s*=\s*"([^"]*\bimages\/[^"]+\.(?:jpe?g|png|gif))"/gi)) {
    const abs = new URL(match[1], pageUrl).href;
    if (!images.has(abs)) {
      const base = abs.split('/').pop();
      images.set(abs, base);
    }
  }
}

console.log(`${images.size} images uniques repérées dans les pages moissonnées.`);

let ok = 0, failed = 0;
for (const [url, filename] of images) {
  const outFile = resolve(imgDir, filename);
  try {
    const response = await fetch(url);
    if (!response.ok) {
      failed++;
      await appendFile(logPath, `HTTP ${response.status}\t${url}\n`, 'utf8');
      await sleep(DELAY_MS);
      continue;
    }
    const buffer = Buffer.from(await response.arrayBuffer());
    await mkdir(dirname(outFile), { recursive: true });
    await writeFile(outFile, buffer);
    ok++;
    if (ok % 20 === 0) console.log(`${ok} images rapatriées`);
  } catch (error) {
    failed++;
    await appendFile(logPath, `ERREUR ${error.message}\t${url}\n`, 'utf8');
  }
  await sleep(DELAY_MS);
}
console.log(`Terminé : ${ok} images rapatriées, ${failed} échecs (voir logs/images-errors.log).`);
