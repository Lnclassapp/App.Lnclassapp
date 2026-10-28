# Journal — Corriger une copie comme en classe

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-28 | Lot 0 : `CloseExerciseSession` reçoit `exercises:` (port `ExerciseRepositoryPort#find`) pour lire les points des questions ; une ligne de câblage dans `ExerciseCopiesController#submit_copy`. | L'ADR §6 écrit `questions.select(&:auto_graded?)` sans dire d'où viennent les questions ; le compte des tentatives ne suffit plus. Seul le câblage touche un fichier du Lot C. | Non |
| 2026-10-28 | Lot 0 : `Grading.score_percent(correct:, total:)` est gardé (tests système existants), seul le use case passe à `points_percent`. | Ne pas modifier des tests hors du lot. À retirer au Lot A si plus personne ne l'appelle. | Non |
| 2026-10-28 | Lot 0 : la contrainte `questions_question_type_values` est étendue aux trois types ; `Appreciation` porte aussi la liste « à revoir » ; règles de structure ajoutées : unité sans chiffre ni signe, propositions d'un `select` distinctes et non vides, corrigé type obligatoire. | L'ADR §6 oublie la contrainte de type (la base refuserait `select`) ; les autres règles viennent de la menace (I2, I5, I6). | Non |
| 2026-10-28 | Lot 0 : le socle relit les nouvelles colonnes (`ExerciseRepository#map_question`, `statement_blocks`) mais n'écrit rien : l'écriture est au Lot D. | Plan : `exercise_repository.rb` est dans les fichiers du Lot D. | Non |

## Ce qui a dérapé

- `bin/ci-quiet` et les tests de contrôleur demandent `yarn install` puis `yarn build` / `yarn build:css` dans un worktree neuf (pas de `node_modules`, pas d'assets).
- Le dump de `db/schema.rb` par la version locale de PostgreSQL réécrit des contraintes sans rapport (`::character varying::text`) : le schéma du lot est repris à la main du schéma de `Develop`, seules les lignes du lot changent.

## Ce qu'on a appris sur la codebase

- `test/infrastructure/repositories/catalog/content_tree_writer_characterization_test.rb` compare toutes les colonnes écrites à un instantané : toute colonne nouvelle d'`exercises` ou de `questions` doit entrer dans `ADDED_LATER`.
- Le DTO d'envoi `AttemptInput::RESPONSE_TEXT_MAX` vaut encore 200 : il passe à 2 000 pour `written` au Lot C, la colonne est déjà à 2 000.
- `QuestionKinds::Written::INVALID` renvoie le code `:invalid_text` : le Lot C ajoute sa phrase au fichier de locales des erreurs de saisie.
