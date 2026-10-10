# Prompt « lot » — Rédaction des leçons d'une matière, d'un niveau et d'une série

> Utilisation : ouvrir une session **dans le dépôt Lnclass** (le prompt lit des fichiers de `docs/contenus/` et lance un script), copier tout ce qui suit la ligne `---`, puis remplir le bloc **ENTRÉE** en bas. Un appel = un **lot** : une matière, un niveau, une série, soit au plus 10 leçons et autant de fichiers.
>
> Ce prompt ne répète pas les règles de rédaction : elles vivent dans [`prompt-redaction.md`](prompt-redaction.md), la source unique. Il ajoute ce qu'un lot demande en plus : tirer les leçons de la progression, les rédiger sans qu'elles se ressemblent, les contrôler, les ranger.

---

## /goal

Tu rédiges en lot les leçons de **une matière, un niveau et une série** de Lnclass (application de soutien scolaire, secondaire ivoirien, programmes de la DPFC). Chaque leçon donne **un fichier** `lnclass.course-tree` : le cours, ses fiches essentielles, leurs exercices. Les leçons à rédiger sont celles de la progression 2026-2027 qui est dans le dépôt.

Chaque leçon est rédigée **exactement** comme le décrit `docs/contenus/prompt-redaction.md` : le rôle, la règle d'or (l'image, le pont, la notion exacte, la limite de l'image), la structure des fiches, les 3 exercices par fiche, les types de questions, le vocabulaire imposé, le format de sortie, le contrôle final. Rien de ce fichier n'est facultatif et rien n'est assoupli parce que le travail est en série.

## Étape 0 — Lire avant d'écrire

1. Lis en entier `docs/contenus/prompt-redaction.md`.
2. Lis `docs/contenus/progressions-2026-2027/README.md` (règles de la progression, numéro de leçon) et le fichier de la matière : `docs/contenus/progressions-2026-2027/progressions-2026-2027-<matière>.json`.
3. Regarde une leçon déjà traitée de la même matière dans `docs/contenus/lecons-traitees/` (par exemple `tle-d/mathematiques/`) pour le niveau de détail attendu : longueur des fiches, qualité des images, style des explications.

## Étape 1 — Établir le plan du lot

1. Dans le fichier de progression, garde les cours dont `level_name` est le niveau demandé et dont `series_name` est la série demandée (au 1er cycle, aucun `series_name`). Le rang de la leçon est le `N` de son `subtitle` (« Leçon N — … »). Ordre = rang.
2. Écarte les leçons **déjà traitées** : un fichier existe dans `docs/contenus/lecons-traitees/<niveau>-<série>/<matière>/` dont `courses[0].name` est le même intitulé. Ne les réécris pas, ne les écrase jamais.
3. Si l'ENTRÉE limite les leçons (« Leçons demandées »), applique la limite.
4. Affiche le plan : rang, intitulé exact, état (« à rédiger » ou « déjà traité »). Puis enchaîne sans attendre de réponse. Si le plan est vide, dis-le et arrête-toi.
5. **Attribue à chaque leçon un décor dominant différent** pour les images : cour de l'école, marché, gbaka, maquis, football, champ, famille, téléphone et mobile money, cuisine, fête de village, atelier, hôpital, port, plantation… C'est une dominante, pas une obligation : si le décor fausse la notion, l'auteur de la leçon en choisit un autre. Le but est qu'un élève qui fait toutes les leçons ne retrouve pas le même marché à chaque page.

## Étape 2 — Rédiger : un sous-agent par leçon

Une leçon pèse environ 85 Ko de JSON. Dix leçons dans une seule conversation saturent le contexte, et les dernières seraient plus pauvres que les premières. **Lance donc un sous-agent par leçon**, au plus 5 en parallèle. Si tu ne disposes pas de sous-agents, rédige les leçons une par une, écris chaque fichier sur le disque dès qu'il est fini et ne le recopie pas dans la conversation.

Chaque sous-agent reçoit, et lui seul le lit :

- le texte intégral de `docs/contenus/prompt-redaction.md` (c'est son prompt) ;
- son **ENTRÉE** remplie : intitulé exact, niveau et série, rang, matière, place dans la progression, contraintes du lot ;
- le **contexte du lot** : la liste ordonnée des intitulés du plan. Les leçons précédentes sont des **acquis** (il peut s'y appuyer), les leçons suivantes sont **interdites** (une notion qui leur appartient n'est pas traitée) ;
- son **décor dominant** (étape 1.5) ;
- le chemin du fichier à écrire (étape 4) et la commande de contrôle (étape 3).

Règles de fond, pour toutes les leçons :

- **Programme officiel.** La progression ne donne que des intitulés. Appuie-toi sur le programme éducatif officiel ivoirien du niveau et de la série. Si tu n'es pas certain qu'une notion y figure, ne l'écris pas : mets-la dans « À compléter : … » et dans les points à faire valider (étape 5). Une notion fausse ou hors programme est pire qu'une notion absente.
- **Aucune invention.** Pas de date, de chiffre, de citation, de nom d'auteur ou de valeur numérique dont tu ne sois sûr. En Histoire-Géographie, Français et Philosophie, cela vaut surtout pour les dates, les auteurs, les œuvres et les citations.
- **Les exercices restent des questions à choix** (les quatre types autorisés), même en Français, Philosophie et Histoire-Géographie : on y vérifie les connaissances, le vocabulaire et la méthode, pas la rédaction libre.
- **Une leçon = un fichier = un seul cours.** Le fichier ne contient que le JSON.

## Étape 3 — Contrôler

1. **Contrôle mécanique.** Exécute `ruby script/contenus/valider.rb <fichier>` sur chaque fichier. Il vérifie le format, le nombre de fiches (2 à 5), les sections de chaque fiche, les balises autorisées, les 3 exercices (Comprendre, Appliquer, S'évaluer) de 5 à 6 questions, les types de questions et leurs bonnes propositions, les longueurs, l'absence de formule dans les noms et titres, le vocabulaire interdit. Corrige toute **erreur** et relance, jusqu'à ce que le fichier passe (3 tours au plus, puis signale l'erreur restante dans le bilan). Corrige aussi les **avertissements** de vocabulaire et d'explication au-delà de 400 caractères quand tu le peux sans appauvrir l'explication.
2. **Relecture de fond par un autre sous-agent**, distinct de l'auteur de la leçon (sauf si l'ENTRÉE dit « Relecture : non »). Il ouvre le fichier et vérifie, sans le réécrire :
   - chaque proposition marquée correcte l'est, chaque proposition marquée fausse l'est ; il **refait chaque calcul** et **relit chaque énoncé** ;
   - l'explication est cohérente avec la bonne réponse ;
   - aucune analogie ne contredit la notion, et chaque image correspond à l'énoncé qu'elle prépare ;
   - rien n'est faux, rien n'est hors programme du niveau et de la série ;
   - aucune question ne dépend d'une figure ou d'une autre question.

   Il rend la liste des défauts, avec leur chemin dans le JSON (`essentials[1].exercises[2].questions[3]`). L'auteur les corrige, puis le contrôle mécanique est relancé. Un seul tour de relecture ; ce qui reste est écrit dans le bilan.

## Étape 4 — Ranger

- Dossier : `docs/contenus/lecons-traitees/<niveau>-<série>/<matière>/`. Le niveau s'écrit `6eme`, `5eme`, `4eme`, `3eme`, `2nde`, `1ere` ou `tle` ; la série suit en minuscules (`tle-d`, `1ere-a1`) et manque au 1er cycle (`3eme`). La matière s'écrit `mathematiques`, `physique-chimie`, `svt`, `francais`, `histoire-geographie`, `philosophie` ou `edhc`.
- Fichier : l'intitulé du cours en minuscules, sans accents, tout caractère non alphanumérique remplacé par un tiret, tirets multiples réduits à un (« L'ONU » devient `histoire-l-onu` quand l'intitulé est « Histoire — L'ONU »). Exemple : `tle-d/mathematiques/limites-et-continuite.json`.
- Ne remplace jamais un fichier existant : s'il existe, saute la leçon et dis-le.
- L'intitulé (`name`) est **celui de la progression, à l'identique** : l'import détecte les doublons à ce nom.

## Étape 5 — Bilan du lot

Rends, dans la conversation, **sans recopier les JSON** :

1. Un tableau : rang, intitulé, fichier, nombre de fiches, d'exercices, de questions, résultat du contrôle (✓ ou erreur restante).
2. **À faire valider par un enseignant de la discipline** : pour chaque leçon, les notions dont le rattachement au programme est incertain, celles laissées de côté faute de place (« À compléter : … »), les points où la relecture a hésité.
3. Les **défauts restants** de la relecture, s'il y en a.
4. Le rappel d'import : **Imports → Cours complets**, jusqu'à 50 fichiers d'un coup. Si la progression a déjà été importée, les cours de ces leçons existent vides et l'import les ignorera comme doublons : liste-les, ils sont à renommer puis archiver avant l'import (voir `docs/contenus/README.md`, « Ordre des imports »).
5. Si la matière est **EDHC** : elle n'existe pas encore dans le référentiel Lnclass, et l'import rejettera ces cours tant qu'elle n'est pas créée.

Selon le champ **Livraison** de l'ENTRÉE :

- `fichiers` (par défaut) : les fichiers sont écrits dans le dépôt, rien n'est committé.
- `pr` : crée la branche `docs/contenus-<niveau>-<série>-<matière>` depuis la dernière `Develop`, ajoute les lignes au tableau « Leçons traitées » de `docs/contenus/README.md`, committe (`docs(contenus): leçons <niveau> <série> <matière>`), pousse la branche et ouvre une pull request en brouillon vers `Develop`. Ne pousse jamais sur `Develop`.

---

## ENTRÉE (à remplir à chaque appel)

- **Matière** : <`Mathématiques`, `Physique-Chimie`, `SVT`, `Français`, `Histoire-Géographie`, `Philosophie` ou `EDHC`>
- **Niveau** : <`6ème`, `5ème`, `4ème`, `3ème`, `2nde`, `1ère` ou `Tle`>
- **Série** : <`A`, `C` en 2nde ; `A1`, `A2`, `C`, `D` en 1ère et Tle ; vide au 1er cycle>
- **Leçons demandées** (facultatif) : <ex. « 1 à 5 », « 3, 4 et 7 » ; vide = toutes celles qui restent>
- **Relecture** (facultatif) : <`oui` par défaut, `non` pour s'en passer>
- **Livraison** (facultatif) : <`fichiers` par défaut, ou `pr`>
- **Contraintes particulières** (facultatif) : <ex. « insister sur la méthode du BEPC »>

Combinaisons possibles : 6ème à 3ème = Mathématiques, Physique-Chimie, SVT, Français, Histoire-Géographie, EDHC (6 matières). 2nde = Mathématiques, Physique-Chimie, SVT, Français, Histoire-Géographie (5 matières, ni Philosophie ni EDHC). 1ère et Tle = Mathématiques, Physique-Chimie, SVT, Français, Histoire-Géographie, Philosophie (6 matières, pas d'EDHC).
