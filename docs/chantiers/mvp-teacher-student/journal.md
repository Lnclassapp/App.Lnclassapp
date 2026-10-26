# Journal — MVP Lnclass Teacher & Student — pilote du 27 octobre

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-26 | « Maths » et « PC » comme noms courts, vouvoiement de l'enseignant partout | Le nom long ne tient pas sur une ligne ; un seul ton par rôle | Non (UDR enseignant §3.1) |
| 2026-10-26 | Enseignant sur ordinateur : barre du haut à filet jaune, profil en tête de la barre latérale, accueil sans bandeau avec classes et annonces en carrousel | Retours du porteur sur les maquettes du 2026-10-24 | Non (UDR enseignant §3.3, §3.14) |
| 2026-10-26 | Mon compte de l'élève sur ordinateur sans classe ni établissement sous le nom | Répétition déjà refusée ailleurs | Non (UDR écrans élève) |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- 2026-10-23 — La session cloud n'avait ni gems ni base : `.claude/hooks/session-start.sh` s'arrêtait sans message sur `ls -d …/chrome-linux/chrome` (Playwright range désormais Chromium sous `chrome-linux64/`), tué par `set -o pipefail` avant `bin/setup`. Corrigé par la PR `fix/session-start-chromium` (motif `chrome-linux*`, `|| true`). Leçon : un hook `set -euo pipefail` ne doit jamais laisser un `ls` sans correspondance tuer la suite.
- 2026-10-26 — Même hook, deuxième arrêt : Corepack télécharge Yarn sur `repo.yarnpkg.com`, que le proxy cloud refuse (403), et `bin/setup` échoue sur `yarn`. Corrigé dans la même PR : `COREPACK_NPM_REGISTRY=https://registry.npmjs.org`, exporté aussi dans l'environnement de la session.
- **Maquettes jamais commitées ni rassemblées** (2026-10-23 au 25) : chaque session gardait ses maquettes dans un conteneur éphémère et n'en envoyait qu'une archive. Le 26, il a fallu les reconstituer en rejouant les transcriptions de quatre sessions. Désormais, chaque envoi est une archive versionnée « vNN-date-contenu », avec un HISTORIQUE.txt, et une mémoire de passation est commitée dans `.ecc/memory/team/`.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Les annonces portent déjà une illustration choisie à la rédaction (`illustration`, `communication/messages/illustrations/`) et une lecture audio (`communication--audio`) : l'accueil enseignant sur ordinateur n'a rien à construire pour elles.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
