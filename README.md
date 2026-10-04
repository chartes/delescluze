# Carnets de prison et correspondance d'Henri Delescluze à Belle-Île (1851-1853)

Édition critique des carnets de prison et de la correspondance privée d'Henri Delescluze, dirigée par Christine Nougaret (École nationale des chartes – PSL, Archives nationales). Documents originaux : Archives nationales, 494AP/1. Première publication : site ÉLEC `http://elec.enc.sorbonne.fr/delescluze/` (Elec 26).

## Origine du TEI

Aucune source TEI n'avait été publiée pour ce corpus. Le TEI de ce dépôt est une **rétro-conversion du site XHTML de l'ÉLEC**, lui-même produit par XSLT depuis un TEI dont il a gardé les noms d'éléments dans ses `@class`. La chaîne de conversion est versée dans `scripts/` et ses journaux dans `logs/` (voir plus bas). Le TEI a ensuite été repris à la main (restitutions du 29/09/2026 : vers, textes insérés, post-scriptum, ratures, soulignements, exposants, notes d'apparat ; voir le `revisionDesc`).

## Structure du dépôt (DoTS)

```
data/delescluze.xml                  le document TEI unique (xml:id="delescluze-edition")
metadata/collection.tsv              métadonnées de la collection
metadata/dots_metadata_mapping.xml   règles de métadonnées (espace de noms dots-suite)
transform/delescluze-edition.xsl     feuille de rendu, au nom de la ressource ; importe hteiml
scripts/                             chaîne de rétro-conversion (Node.js)
logs/                                journaux de moisson, d'alignement et contrôles
```

Le document compte 498 unités citables : 5 rubriques, 56 groupes (carnets, lettres), 279 pages, 19 lettres d'index et 139 personnes. Les métadonnées du document sont lues dans son `teiHeader` par le mapping ; il n'y a pas de fichier de métadonnées par document.

## Déploiement

- La feuille vise le serveur de dev : `$elec-base = '/elec'` et import `../../renderers/hteiml/xsl/tei2html.xsl`. La copie servie en local (`dots-clean`) porte `''` et `../hteiml/xsl/tei2html.xsl`.
- La feuille ne lit aucun fichier compagnon (`document()`) : rien à poser à côté d'elle.
- Les images (fac-similés des Archives nationales et figures de l'introduction) ne sont pas dans ce dépôt : la feuille les appelle sous `/images/delescluze/img/`, à déposer avec l'application.

## Chaîne de rétro-conversion

À lancer depuis un dossier de travail qui contient `data/legacy/` (miroir du site) et `data/img/`, après `npm install` (dépendances dans `scripts/package.json`) :

```
node scripts/harvest-legacy-site.mjs   # moisson du site ÉLEC → data/legacy/, logs/harvest-*
node scripts/harvest-images.mjs        # images référencées → data/img/, logs/images-*
node scripts/build-single-xml.mjs      # rétro-conversion et assemblage → data/delescluze.xml, logs/controles.json
```

`scripts/lib/core.mjs` porte la logique commune : conversion directe (notes, biographies, bibliographie) et alignement mot à mot de la transcription et de l'édition (`choice`/`orig`+`reg`, `del`, `add`). `logs/alignment-log.tsv` liste les alignements repliés, à relire. La chaîne produit l'état du 08/09/2026 : les corrections et restitutions faites ensuite dans le TEI ne sont pas rejouées par elle.
