# Prompt « lot par niveau » — Rédaction des leçons d'une matière pour un niveau (format v3)

> Utilisation : ouvrir une session **dans le dépôt Lnclass** (le prompt lit des fichiers de `docs/contenus/` et lance un script), copier tout ce qui suit la ligne `---`, puis remplir le bloc **ENTRÉE** en bas. Un appel = une **matière** et un **niveau** (et sa série) : les leçons demandées pour ce niveau (en général les 10 premières de la progression). Exemples : Mathématiques 3ème (chantier refonte-contenus-maths), Français 3ème (chantier contenus-3e-francais).
>
> Ce prompt ne répète pas les règles de rédaction : elles vivent dans [`prompt-redaction.md`](prompt-redaction.md), la source unique. Il ajoute ce qu'un lot demande en plus : composer le plan du niveau, rédiger les leçons sans qu'elles se ressemblent, les contrôler, les ranger. Pipeline d'une leçon : **rédaction → script → relecture IA → import en brouillon → validation équipe → publication**.

---

## /goal

Tu rédiges en lot les **leçons d'une matière pour un niveau** de Lnclass (application de soutien scolaire, secondaire ivoirien, programmes de la DPFC). Pour chaque leçon demandée, tu produis **un fichier** `lnclass.course-tree` **version 3** : la leçon, ses notions (fiche de révision au gabarit en 4 blocs), l'exercice de chaque notion, les 4 problèmes de synthèse et les figures paramétrées.

Chaque leçon est rédigée **exactement** comme le décrit `docs/contenus/prompt-redaction.md` : le gabarit des notions, la méthode en étapes numérotées, l'exemple qui applique chaque étape, les corrections qui reprennent les étapes et les mots de la méthode, les figures paramétrées, les types de questions, la part corrigée automatiquement, les règles de la matière (« Selon la matière » : textes, faits, sources), le format de sortie, le contrôle final. Rien de ce fichier n'est facultatif et rien n'est assoupli parce que le travail est en série.

## Étape 0 — Lire avant d'écrire

1. Lis en entier `docs/contenus/prompt-redaction.md`.
2. Lis `docs/contenus/progressions-2026-2027/README.md` (règles de la progression, numéro de leçon, séries).
3. Regarde une leçon déjà traitée dans `docs/contenus/lecons-traitees/` (par exemple `tle-d/mathematiques/`) pour le niveau de détail attendu : longueur des fiches, qualité des images, style des explications.

## Étape 1 — Composer le plan du niveau

1. **Les leçons.** Ouvre `docs/contenus/progressions-2026-2027/progressions-2026-2027-<matière>.json` (`mathematiques`, `francais`, `histoire-geographie`, `svt`, `physique-chimie`, `edhc`, `philosophie`) et garde les fiches de cours du niveau demandé :
   - au 1er cycle : ceux sans `series_name` ;
   - à partir de la 2nde : ceux dont `series_name` est la série demandée.

   Le rang d'une leçon est le `N` de son `subtitle` (« Leçon N — … »). Prends les rangs demandés (par défaut 1 à 10 en 3ème).
2. **Écarte les leçons déjà traitées** : un fichier existe dans `docs/contenus/lecons-traitees/<niveau>/<matière>/` dont `courses[0].name` est le même intitulé et dont `version` vaut 3. Ne les réécris pas, ne les écrase jamais. Un fichier de version 1 ou 2 au même intitulé est **remplacé** (ces versions ne s'importent plus).
3. **Affiche le plan** : un tableau rang × intitulé exact × état (« à rédiger » ou « déjà traité »). Puis enchaîne sans attendre de réponse. Si le plan est vide, dis-le et arrête-toi.
4. **Attribue à chaque leçon un décor dominant** pour ses énoncés de problèmes (cour de l'école, marché, gbaka, football, champ, famille, téléphone et mobile money, atelier, port, plantation… ; en Français, un thème pour ses textes supports), le plus varié possible dans le niveau, et un **thème** (`blue`, `teal`, `burgundy`) en alternance. C'est une dominante, pas une obligation : si le décor fausse la notion, l'auteur en choisit un autre.

## Étape 2 — Rédiger : un sous-agent par leçon

Une leçon pèse plusieurs dizaines de Ko de JSON. Dix leçons dans une seule conversation saturent le contexte, et les dernières seraient plus pauvres que les premières. **Lance donc un sous-agent par leçon**, au plus 6 en parallèle, leçon par leçon. Si tu ne disposes pas de sous-agents, rédige les leçons une par une, écris chaque fichier sur le disque dès qu'il est fini et ne le recopie pas dans la conversation.

Chaque sous-agent reçoit, et lui seul le lit :

- le texte intégral de `docs/contenus/prompt-redaction.md` (c'est son prompt) ;
- son **ENTRÉE** remplie : intitulé exact, niveau et série, rang, matière, place dans la progression, contraintes du lot ;
- le **contexte de sa matière** : la liste ordonnée des intitulés de la progression de la matière pour ce niveau (pas seulement ceux du lot). Les leçons précédentes sont des **acquis**, les leçons suivantes sont **interdites** : une notion qui leur appartient n'est pas traitée ;
- son **décor dominant** (étape 1.5) ;
- le chemin du fichier à écrire (étape 4) et la commande de contrôle (étape 3).

Règles de fond, pour toutes les leçons :

- **Programme officiel.** La progression ne donne que des intitulés. Appuie-toi sur le programme éducatif officiel ivoirien du niveau et de la série. Si tu n'es pas certain qu'une notion y figure, ne l'écris pas : mets-la dans « À compléter : … » et dans les points à faire valider (étape 5). Une notion fausse ou hors programme est pire qu'une notion absente.
- **Aucune invention.** Pas de date, de chiffre, de citation, de nom d'auteur ou de valeur numérique dont tu ne sois sûr. En Histoire-Géographie, Français et Philosophie, cela vaut surtout pour les dates, les auteurs, les œuvres et les citations.
- **Types de questions** : ceux de `prompt-redaction.md`, variés ; **au moins 50 % de questions corrigées automatiquement** par leçon ; chaque question rédigée a son corrigé modèle, son barème et ses critères. **Un exercice par notion et exactement quatre problèmes, sans exception**, de 5 questions au moins chacun, avec une correction qui reprend la méthode.
- **La série du fichier** est celle de l'ENTRÉE (`series_name`). Au 1er cycle, pas de `series_name`.
- **Une leçon = un fichier = une seule fiche de cours.** Le fichier ne contient que le JSON.

## Étape 3 — Contrôler

1. **Contrôle mécanique.** Exécute `ruby script/contenus/valider.rb <fichier>` sur chaque fichier. Il refuse le fichier avec les mêmes raisons que l'import v3 : version retirée (`format_retired`), nombre de notions (`schema`), gabarit des 4 blocs, `example_steps_mismatch` (La méthode et l'exemple n'ont pas le même nombre d'étapes), `essential_exercise_count` (un exercice par notion), `lesson_exercise_count` (exactement 4 problèmes), `too_few_questions` (moins de 5) ou `invalid_count` (plus de 30), correction vide (`blank`), de moins de 20 caractères (`too_short`) ou de plus de 2 000 (`too_long`), `figure_invalid` (sorte inconnue, paramètre hors bornes, description absente), `figure_missing`, thème (`schema`). Il refuse aussi toute question mal construite pour son type (`question_structure`, comme l'import). Il avertit des défauts de rédaction : une correction d'exercice de notion qui ne cite aucune étape de La méthode, des mots interdits, des questions dépendantes, moins de 50 % de questions corrigées automatiquement. Corrige toute **erreur** et tout **avertissement**, jusqu'à ce que le fichier passe (3 tours au plus, puis signale ce qui reste dans le bilan).
2. **Relecture IA indépendante**, par un autre sous-agent que l'auteur de la leçon (sauf si l'ENTRÉE dit « Relecture : non »). Il ouvre le fichier et vérifie, sans le réécrire :
   - chaque proposition marquée correcte l'est, chaque proposition marquée fausse l'est ; il **refait chaque calcul**, de chaque exemple corrigé et de chaque question, et **relit chaque énoncé** ;
   - chaque correction est cohérente avec la bonne réponse et suit les étapes de La méthode ;
   - l'exemple corrigé applique bien chaque étape de La méthode ;
   - rien n'est faux, rien n'est hors programme du niveau ; chaque fait, date, auteur et citation est exact ; aucun extrait long d'œuvre protégée ;
   - chaque question rédigée a un corrigé modèle juste, un barème et des critères cohérents ;
   - les paramètres de chaque figure décrivent bien la situation annoncée par sa description ;
   - aucune question ne dépend d'une figure ou d'une autre question absente.

   Il rend la liste des défauts, avec leur chemin dans le JSON (`courses[0].notions[1].exercise.questions[3]`). L'auteur les corrige, puis le contrôle mécanique est relancé. Un seul tour de relecture ; ce qui reste est écrit dans le bilan.

## Étape 4 — Ranger

- Dossier : `docs/contenus/lecons-traitees/<niveau>-<série>/<matière>/` (`mathematiques`, `francais`, `histoire-geographie`, `svt`, `physique-chimie`, `edhc`, `philosophie`). Le niveau s'écrit `6eme`, `5eme`, `4eme`, `3eme`, `2nde`, `1ere` ou `tle` ; la série suit en minuscules (`tle-d`, `1ere-d`) et manque au 1er cycle (`3eme`).
- Fichier : l'intitulé de la fiche de cours en minuscules, sans accents, tout caractère non alphanumérique remplacé par un tiret, tirets multiples réduits à un (l'intitulé « Histoire — L'ONU » donne `histoire-l-onu.json`). Exemple : `3eme/mathematiques/racines-carrees.json`.
- Ne remplace jamais un fichier v3 existant : s'il existe, saute la leçon et dis-le. Un fichier v1 ou v2 au même nom est remplacé.
- L'intitulé (`name`) est **celui de la progression, à l'identique** : l'import détecte les doublons à ce nom.

## Étape 5 — Bilan du niveau

Rends, dans la conversation, **sans recopier les JSON** :

1. Un tableau rang × intitulé : fichier, nombre de notions, de figures, de questions, résultat du contrôle (✓ ou erreur restante).
2. **À faire valider par un enseignant de la matière** : pour chaque leçon, les notions dont le rattachement au programme est incertain et les points où la relecture a hésité. Pour le pilote 3ème, l'enseignant relit avant publication.
3. Les **défauts restants** de la relecture, s'il y en a.
4. Les **figures** pour lesquelles aucune sorte ne convenait (situation décrite dans l'énoncé à la place) : elles nourrissent une demande de sorte nouvelle.
5. Le rappel d'import : l'écran **Imports** (leçon complète, format v3). L'import crée la leçon **en brouillon** ; une leçon déjà publiée est refusée, une leçon encore en brouillon est remplacée. L'équipe relit dans l'application (fiche, figures, exercices, corrections), puis publie.

Selon le champ **Livraison** de l'ENTRÉE :

- `fichiers` (par défaut) : les fichiers sont écrits dans le dépôt, rien n'est committé.
- `pr` : crée la branche `docs/contenus-<niveau>-<série>` depuis la dernière `Develop`, ajoute les lignes au tableau « Leçons traitées » de `docs/contenus/README.md`, committe (`docs(contenus): leçons <niveau> <série>`), pousse la branche et ouvre une pull request vers `Develop`. Ne pousse jamais sur `Develop`.

---

## ENTRÉE (à remplir à chaque appel)

- **Matière** : <`Mathématiques`, `Français`, `Histoire-Géographie`, `SVT`, `Physique-Chimie`, `EDHC` ou `Philosophie`>
- **Niveau** : <`6ème`, `5ème`, `4ème`, `3ème`, `2nde`, `1ère` ou `Tle`>
- **Série** : <`A`, `C` en 2nde ; `A`, `C`, `D` en 1ère ; `A1`, `A2`, `C`, `D` en Tle ; vide au 1er cycle>
- **Rangs** (facultatif) : <vide = tous les rangs du niveau ; sinon une liste, ex. « 1 à 5 »>
- **Relecture** (facultatif) : <`oui` par défaut, `non` pour s'en passer>
- **Livraison** (facultatif) : <`fichiers` par défaut, ou `pr`>
- **Contraintes particulières** (facultatif) : <ex. « insister sur la méthode du BEPC »>

Exemple : `Français`, `3ème` sans série, rangs 1 à 10.
