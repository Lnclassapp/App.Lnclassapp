# Journal — Corriger une copie comme en classe

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-28 | Lot 0 : `CloseExerciseSession` reçoit `exercises:` (port `ExerciseRepositoryPort#find`) pour lire les points des questions ; une ligne de câblage dans `ExerciseCopiesController#submit_copy`. | L'ADR §6 écrit `questions.select(&:auto_graded?)` sans dire d'où viennent les questions ; le compte des tentatives ne suffit plus. Seul le câblage touche un fichier du Lot C. | Non |
| 2026-10-28 | Lot 0 : `Grading.score_percent(correct:, total:)` est gardé (tests système existants), seul le use case passe à `points_percent`. | Ne pas modifier des tests hors du lot. À retirer au Lot A si plus personne ne l'appelle. | Non |
| 2026-10-28 | Lot 0 : la contrainte `questions_question_type_values` est étendue aux trois types ; `Appreciation` porte aussi la liste « à revoir » ; règles de structure ajoutées : unité sans chiffre ni signe, propositions d'un `select` distinctes et non vides, corrigé type obligatoire. | L'ADR §6 oublie la contrainte de type (la base refuserait `select`) ; les autres règles viennent de la menace (I2, I5, I6). | Non |
| 2026-10-28 | Lot 0 : le socle relit les nouvelles colonnes (`ExerciseRepository#map_question`, `statement_blocks`) mais n'écrit rien : l'écriture est au Lot D. | Plan : `exercise_repository.rb` est dans les fichiers du Lot D. | Non |
| 2026-10-29 | Lot C : `AttemptInput` borne à 2 000 (`WRITTEN_TEXT_MAX`, code `:text_too_long`) car il ne connaît pas le type ; `SubmitExerciseCopy` resserre à 200 (`:too_long`) les trous et le nombre. Le cahier n'a aucun champ : ce qui est posté est ignoré, la tentative est écrite neutre (`unanswered`, jamais juste). | Le DTO est construit avant de connaître la question ; le type seul sait sa borne. ADR-0115 §5 : une tentative est écrite pour `written` et `notebook`. | Non |
| 2026-10-29 | Lot C : la forme postée du choix dans une liste est un indice d'affichage (`display_order[]`), comme un choix : jamais l'identifiant de la proposition. | ADR-0091 §4.4 ; `AnswerShuffle.select` relit l'identifiant côté serveur. | Non |
| 2026-10-29 | Lot C : la feuille ne compte pas `written` ni `notebook` parmi les questions « répondues » (compteur et confirmation des questions vides). | Sinon le cahier, sans champ, ferait toujours dire « 1 question sans réponse comptera fausse ». Fichiers hors lot touchés : `copy_input.rb` (texte aux octets invalides), `exercises/show.html.erb` (trou en ……, pas de bloc « solution » vide pour les nouveaux types), `script/ci/test_timings.yml` (durée du test système). | Non |

## Ce qui a dérapé

- `bin/ci-quiet` et les tests de contrôleur demandent `yarn install` puis `yarn build` / `yarn build:css` dans un worktree neuf (pas de `node_modules`, pas d'assets).
- Le dump de `db/schema.rb` par la version locale de PostgreSQL réécrit des contraintes sans rapport (`::character varying::text`) : le schéma du lot est repris à la main du schéma de `Develop`, seules les lignes du lot changent.

## Ce qu'on a appris sur la codebase

- `test/infrastructure/repositories/catalog/content_tree_writer_characterization_test.rb` compare toutes les colonnes écrites à un instantané : toute colonne nouvelle d'`exercises` ou de `questions` doit entrer dans `ADDED_LATER`.
- Un texte aux octets invalides faisait lever `strip` et la regex de l'octet nul (500 possible hors Rails, qui refuse déjà les paramètres mal encodés) : `AttemptInput` et `CopyInput` le refusent proprement (menace W4).
- `QuestionKinds::Written::INVALID` renvoie le code `:invalid_text` : le Lot C ajoute sa phrase au fichier de locales des erreurs de saisie.
