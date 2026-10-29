# Journal — Refonte des contenus de mathématiques

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-29 | Lot A : le schéma v3 refuse d'abord (5 questions, explanation 20-2000, 4 problèmes, 1 exercice par notion) ; le rapport donne alors le code `schema` au chemin de l'élément. Les raisons propres (`too_few_questions`, `lesson_exercise_count`…) restent dans l'adaptateur, pour un appel sans schéma. | Le moteur valide le schéma avant l'adaptateur ; les deux disent le même chemin. | Non |
| 2026-10-29 | Lot R : `essentials.sheet` devient `NOT NULL default {}` (l'ADR dit « non nul ») ; `{}` = notion sans fiche, exclue par `RevisionSheetQuery`. `SheetDocument` est remplacé par `StatementBlocks` (sujet en blocs, ADR-0115) et `CourseSheetTextHelper` par `Catalog::SheetTextHelper`, car encore utilisés. `/courses/:slug/fiche` répond 301 vers `#fiche-de-revision`. | Garder la validation des sujets en blocs et les vues cahier sans l'ancien code. | Non |
| 2026-10-29 | Lot A : `replace_draft` garde l'auteur de la leçon (le port n'a pas d'`author_id`) ; les séances de remédiation hors leçon dont la lacune disparaît deviennent ordinaires. | Pas de port à changer ; la base impose `remediation ⇔ lacune`. | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot A : le plan ne listait pas `import_error.rb` ni `run_import.rb` ; sans eux, aucun nouveau motif d'import (`format_retired`…) n'existe. Le champ du lot a été élargi en cours de route.
- Lot A : `saint_michel.rb` importe des leçons de Tle D au format 1, désormais retiré ; la démo s'arrête avec un message clair jusqu'au Lot P2.
- Lot R : retirés en plus du plan, car morts sans la fiche cahier : create/update_essential, essential_input, image_slot, helpers course_sheet_*, schéma `lnclass.essentials.v1`. Anciens tests système de la page v2 supprimés ; `course_catalog`, `boucle_pedagogique`, `import_flow`, `imports_end_to_end` migrés vers la fiche v3. Échecs préexistants : QuestionFillBlank/Numeric/Ordering/Matching (balisage du résultat), `figure_test` sans durée enregistrée, garde de migrations sans `origin/main` dans le worktree.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

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
