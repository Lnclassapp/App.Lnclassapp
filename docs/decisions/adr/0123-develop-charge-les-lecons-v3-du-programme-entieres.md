# ADR-0123 : Develop charge seul les leçons v3 du programme et remplace entières celles du même titre
<!-- index
titre: Develop charge les leçons v3 du programme, entières
statut: Accepté
problematique: Voir sur Develop, sans import à la main, toutes les leçons v3 du programme contenus-v3-tous-niveaux, à la place des leçons v1 du même titre, publiées ou non.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-02 |
| **Chantier** | `docs/chantiers/chargement-lecons-v3-develop` |
| **Remplace** | — (amende ADR-0122 pour Develop seul) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

ADR-0122 charge seul, sur Develop et Staging, les leçons du dépôt qui portent des sujets de devoir, et ne remplace que leurs exercices et sujets. Son option C (« toutes les leçons du dépôt ») avait été écartée : elle effaçait les résultats de test de 101 leçons. Le programme `contenus-v3-tous-niveaux` livre maintenant les leçons v3 de Tle et de 1ère (263 fichiers, ~320 avec les niveaux qui suivent), dont beaucoup portent le titre d'une leçon v1 déjà importée, souvent publiée : l'import à la main la refuse (`lesson_already_published`, ADR-0116 §4.4). Le porteur décide (2026-11-02) de les voir toutes sur **Develop**, à la place des leçons v1 du même titre, résultats d'élèves effacés compris. Staging et production ne changent pas.

## 2. Moteurs de décision

- Develop seul : ni Staging, ni production, ni un environnement de PR, même par erreur de configuration.
- La même chaîne d'import qu'ADR-0122 (mêmes contrôles, même ligne dans Imports, même empreinte, même reprise de publication).
- Le pré-déploiement n'échoue jamais à cause du contenu (ADR-0122 §4.6).
- L'import à la main garde son refus `lesson_already_published`.
- Pas de migration.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — **Develop : les fichiers v3 des dossiers du programme (liste explicite), remplacés entiers** | Le choix du porteur ; une liste relue en revue ; 3ème et les leçons à sujets inchangées | Retenue |
| B — Toutes les leçons v3 du dépôt (3ème comprise) | Develop identique au dépôt | Hors décision : 3ème vient d'un autre programme |
| C — Remplacer seulement exercices et sujets (mode ADR-0122) | Code déjà là | Une leçon v1 n'a pas les notions v3 : `notion_not_found` sur presque toutes |
| D — Découper le premier chargement (N leçons par démarrage) | Pré-déploiement plus court | Pas nécessaire : 3 min mesurées en local, sans limite de temps par défaut chez Railway (§5) ; gardée en réserve |

## 4. Décision

> **Sur l'environnement Railway nommé `Develop` (casse ignorée) seulement, le chargement automatique d'ADR-0122 prend aussi les fichiers au format 3 des dossiers de niveaux du programme `contenus-v3-tous-niveaux` (liste explicite `Entities::Catalog::V3ProgrammeLevels`) ; une leçon présente du même titre (même niveau, matière, série), publiée ou non, est remplacée entière ; puis la cascade de publication suit.**

1. **Repérage.** `AutomaticLoadStage#whole_lessons?` : vrai pour `Develop` seul (pas pour un environnement de PR, même nommé Develop). Staging garde exactement ADR-0122.
2. **Sélection.** `AutomaticLoadStage#mode_for` : une leçon à sujets de devoir garde le mode `:exercises` d'ADR-0122, partout (Develop et Staging), même dans un dossier du programme ; une leçon v3 sans sujet d'un dossier de `V3ProgrammeLevels` prend le mode `:lesson` sur Develop ; toute autre n'est pas chargée. La liste : `tle`, `tle-a1`, `tle-a2`, `tle-c`, `tle-d`, `1ere`, `1ere-a1`, `1ere-a2`, `1ere-c`, `1ere-d`, `2nde`, `2nde-a`, `2nde-c`, `4eme`, `5eme`, `6eme` ; les fichiers v1 qu'ils contiennent encore sont ignorés, si bien que chaque vague fusionnée arrive au déploiement suivant. `3eme` n'y est pas.
   > **Amendé le 2026-11-04 (§10).** Sur Develop, tout fichier v3 du dépôt prend le mode `:lesson`, 3ème comprise et leçons à sujets comprises ; la liste `V3ProgrammeLevels` ne sert plus qu'à Staging (`:create_only`).
3. **Changement.** Inchangé : empreinte SHA-256 comparée au dernier chargement réussi du même nom (`chargement-automatique-<niveau>-<matière>-<fichier>`) ; égale : rien, ou reprise seule de la publication si la leçon n'est pas entièrement publiée.
4. **Remplacement.** `ImportCourseTree` prend `replace: :draft | :exercises | :lesson` (remplace le booléen `replace_exercises`) ; `:draft` est la valeur par défaut et la seule de l'écran Imports. En `:lesson`, l'écrivain (`ContentTreeWriter#replace_lesson`) fait ce que fait `replace_draft` sans sa garde « tout en brouillon » : la leçon garde son id, son slug, son auteur et son statut ; tout ce qui s'y rattache est effacé (notions et fiches v1, lectures, exercices, questions, séances, tentatives, badges, lacunes, devoirs envoyés, sujets, texte de cours v1) ; le cours, ses notions, exercices et sujets sont réécrits en brouillon depuis le fichier.
5. **Compte rendu.** Le journal du déploiement dit `created` ou `replaced` pour chaque leçon du programme (`loaded` reste celui des leçons à sujets).

## 5. Conséquences

### 🟢 Positives

- Une fusion d'une vague dans `Develop` suffit à voir ses leçons sur Develop, à la place des v1.
- Aucun nouveau chemin d'écriture : la chaîne d'import et ses erreurs, lisibles dans Imports.

### 🔴 Coûts consentis

- Sur Develop, les résultats des élèves, les devoirs envoyés et les lectures des fiches attachés à une leçon remplacée sont effacés, à chaque changement de son fichier.
- Premier déploiement plus long : mesuré en local (base de développement, 264 fichiers examinés) **174 s** pour 261 leçons créées, **191 s** pour 261 leçons remplacées, **11 s** quand rien n'a changé (démarrage de Rails compris). Railway n'impose pas de limite au pré-déploiement par défaut (réglage facultatif « Pre-deploy Timeout », 1 à 3600 s) ; si une limite inférieure à ~10 min était posée sur Develop, l'option D (N leçons par démarrage, la suite au suivant) serait à prendre.
- Un fichier refusé par l'import (contenu invalide) est retenté à chaque démarrage, comme sous ADR-0122.
- Une leçon v1 dont le titre diffère de la v3 n'est pas remplacée : les deux coexistent.
- Le remplacement entier d'une leçon publiée existe dans le code ; il n'est atteignable que par la tâche `contenus:charger` sur Develop, et des tests gardent le refus de l'import à la main.

## 6. Liens

- ADR-0122 (chargement automatique, amendé ici pour Develop), ADR-0116 §4.4, ADR-0108, ADR-0052.

## 7. Comment vérifier

- `test/domain/entities/catalog/automatic_load_stage_test.rb` : Develop seul remplace entier ; Staging, production, PR, nom inconnu jamais.
- `test/domain/use_cases/catalog/load_repository_lessons_test.rb`, `test/integration/catalog/automatic_lesson_load_test.rb` : leçon v1 publiée remplacée, publiée, `replaced` puis `unchanged` ; absente `created` ; Staging et production n'y touchent pas ; à la main, `lesson_already_published`.
- Après déploiement de Develop : le journal du pré-déploiement liste `created` / `replaced` par fichier ; l'écran Imports montre une ligne par fichier.

## 8. Amendement du 2026-11-02 : Develop complète son référentiel avant le chargement

**Contexte.** Le premier déploiement a refusé chaque leçon du programme : le référentiel de Develop, créé à l'écran, n'avait ni 1ère ni les séries A1/A2 (journal de #443 : `unknown_level … (value: 1ère)`, `unknown_series … (value: A1)`). Décision du porteur (2026-11-02) : Develop doit recevoir les leçons.

**Décision.** Sur Develop seul (`AutomaticLoadStage#whole_lessons?`, la garde du §4.1 : jamais Staging, production ni PR), `contenus:charger` crée, avant le chargement, ce qui manque du référentiel de base `Entities::Catalog::BaseReferential` (celui des semis de développement, ADR-0034, que `db/seeds/catalog.rb` lit désormais) : niveaux 6ème à Tle, séries 2nde A C, 1ère et Tle A1 A2 C D, leurs couples, les 6 matières.
- Idempotent par slug ; aucun enregistrement existant n'est modifié ni supprimé (position et cycle d'un niveau existant intacts).
- Un niveau créé prend la position du référentiel, ou la première libre après la plus haute si un autre niveau la tient ; une matière, son rang du programme (ADR-0090).
- Un nom ou un nom court déjà pris par un autre enregistrement n'est pas créé : le journal le dit (« non créé, nom déjà pris »), les couples qui en dépendent sont sautés.
- Le barème des classes n'est pas touché.
- Le journal du pré-déploiement liste ce qui a été créé ; un échec est journalisé et le chargement continue.

**Conséquence.** Develop porte désormais les niveaux, séries et matières du référentiel de base, même si l'équipe ne les avait pas créés ; les renommer à l'écran reste possible (le slug est figé), un niveau, une série, un couple ou une matière supprimé revient au déploiement suivant (pas de mémoire des suppressions). Un niveau du même sens sous un autre nom (« Terminale ») n'empêche pas la création de « Tle » : les deux coexistent, le journal dit la position décalée.

**Complément du 2026-11-02 (décision du porteur : configuration complète du référentiel sur Develop).** Le même mécanisme, sous la même garde et avec la même règle (création seule, rien d'existant modifié ni supprimé), crée aussi avant le chargement :
- la matière **EDHC** (`BaseReferential::PROGRAMME_MATERIALS`, septième matière du programme, D1) : catégorie `other`, rang du programme d'ADR-0090 (6 ; le semis de démo `trois_etablissements.rb` écrit 7, il n'est pas repris) ; les semis de développement gardent leurs 6 matières ;
- les entrées **absentes** du barème des classes (ADR-0058, `FillClassroomPlanEntries.fill`, `ON CONFLICT DO NOTHING`) : un nombre posé par l'équipe n'est jamais réécrit ;
- les **41 DRENA** de `db/seeds/data/drenas.yml`, par slug.

Aucun établissement ni aucune classe n'est créé. Le journal du pré-déploiement dit ce qui a été créé, par type (« matières EDHC ; barème 24 entrée(s) ; DRENA 41 »). Comme pour les niveaux, une DRENA ou une entrée du barème supprimée revient au déploiement suivant. Chaque étape (référentiel, matières, barème, DRENA) est à l'abri : une interruption est journalisée avec son message et n'empêche ni les étapes suivantes ni le chargement. Le barème s'écrit en une transaction ; une entrée saisie à l'écran pendant le pré-déploiement serait comptée comme créée (sur-compte possible, jamais d'écriture de plus).

## 9. Amendement du 2026-11-02 : un chargement tué en pleine leçon

**Constat (Develop, déploiements `1f7bbe5e` puis `1b8fa823`).** Le second déploiement a remplacé le premier pendant son pré-déploiement et a tué le chargement après ~45 leçons ; lui-même avait trouvé le verrou pris et sauté le chargement.

**Ce qui tient sans changement.**
- L'écriture d'une leçon (import, dans la transaction du lot) et sa publication (cascade, dans sa transaction) sont chacune tout ou rien : une leçon coupée n'est jamais à moitié écrite ni à moitié publiée.
- Coupée entre l'import et la publication : son rapport est terminé, l'empreinte ne change pas, la publication est reprise seule au déploiement suivant (`republished`). Coupée pendant l'import : pas de rapport terminé, elle est réimportée entière.

**Ce qui change.** Le rapport de la leçon coupée reste « en cours », et un rapport en cours fait refuser tout import du même type pendant 10 minutes (`StartImport`, `fail_stale`) : un déploiement relancé aussitôt aurait laissé chaque leçon `not_started`. Avant de charger, sous le verrou consultatif (aucun autre chargement ne tourne), le use case passe en échec les rapports `course_tree` encore en cours dont le fichier s'appelle `chargement-automatique-…` (`ImportReportRepository#fail_running_named`), et le journalise. Seul un rapport d'un seul fichier est visé, et le journal donne son `public_id` ; un échec de ce nettoyage est journalisé et le chargement continue. Limites consenties : un import à la main d'un seul fichier que l'équipe aurait nommé `chargement-automatique-…` serait passé en échec s'il tournait au même moment (l'écran le dirait en échec alors que le job écrit ses leçons) ; un verrou perdu par une reconnexion silencieuse de la base pendant le chargement laisserait un démarrage concurrent passer en échec l'import vivant. Un import à la main ordinaire en cours n'est pas touché : il fait seulement attendre les leçons au déploiement suivant (`not_started`, journalisé). Le démarrage qui trouve le verrou pris le dit à la sortie et au journal (« verrou pris par un autre démarrage : chargement sauté »), le déploiement suivant reprend.


## 10. Amendement du 2026-11-04 : §4.2 — 3ème incluse, leçons à sujets entières sur Develop

**Décision du pilote (ticket #473), coût accepté par le porteur (2026-11-04).** Détail et coûts : ADR-0124 §8, chantier `docs/chantiers/charger-toutes-les-lecons-develop`.

Le §4.2 devient, pour Develop : **tout fichier au format 3 de `docs/contenus/lecons-traitees/*/*/*.json` prend le mode `:lesson`**, quel que soit son dossier (3ème et tout autre dossier compris) et qu'il porte ou non des sujets de devoir (Thalès est remplacée entière, sujets compris). L'option B du §3, écartée alors, est retenue pour Develop. `V3ProgrammeLevels` n'est plus lue sur Develop ; elle reste la liste des dossiers où Staging crée les leçons absentes. Le §4.5 suit : sur Develop, le journal dit `created` ou `replaced` pour chaque fichier, et plus jamais `loaded`.

Staging, production, Demo et les environnements de PR ne changent pas ; une leçon à sujets reste en `:exercises` sur Staging (ADR-0122).
