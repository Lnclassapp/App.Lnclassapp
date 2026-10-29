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
| 2026-10-29 | Lot B : la pause se dit par la page de l'exercice (`#exercise_paused`, heure de reprise), sans message flash. | Le flash répétait la même phrase que la page. | Non |
| 2026-10-29 | Lot C (revue) : le texte rédigé ramène `\r\n` à `\n` avant de compter ; la règle « comptée dans les répondues » tient dans `SessionPlayQuery::Question#counted?` ; la clé `invalid_text`, inatteignable (le DTO refuse d'abord), est retirée. | Le navigateur compte 2 000 là où le serveur comptait plus ; une liste de types écrite en dur dans la vue divergeait. | Non |
| 2026-10-29 | Lot E : partiel `assessment/statement_blocks/_blocks` propre aux écrans d'exercice au lieu des partiels des fiches (UDR-0140 §3 précisée) ; une seule validation des blocs, `SheetDocument.statement_errors`, que l'import appelle ; au rendu, 10 blocs au plus et une ligne de journal pour un bloc ignoré. | Les partiels des fiches lisent `@sheet.glossary` et `course_sheet.css`, absents des écrans d'exercice ; deux validations divergeaient déjà. | Non (UDR-0140 précisée) |
| 2026-10-29 | Retouches après les captures : tuiles du résultat, réponse d'une liste qui n'est plus tronquée à 390 px, ponctuation collée au trou d'une liste. L'ordre des boutons de la confirmation, qui diffère entre téléphone et ordinateur, est voulu (porteur). | Défauts vus sur les captures du parcours complet. | Non |

## Ce qui a dérapé

- `bin/ci-quiet` et les tests de contrôleur demandent `yarn install` puis `yarn build` / `yarn build:css` dans un worktree neuf (pas de `node_modules`, pas d'assets).
- Un redémarrage du conteneur a tué l'exécutant du Lot D et deux revues du Lot A en cours : le travail non commité a survécu sur le disque, un nouvel agent l'a repris dans le même worktree.
- La garde de vocabulaire (`test/i18n/locale_files_test.rb`) a fait échouer la CI du Lot A : les deux phrases du PRD (CA-10) qui disent « leçon » sont entrées dans sa liste blanche.
- Un worktree en HEAD détaché a fait croire à un push du Lot D qui n'avait rien envoyé : pousser avec `git push origin HEAD:<branche>`.
- Les tests parallèles butent parfois sur `PG::TRDeadlockDetected` quand plusieurs worktrees partagent la base : `PARALLEL_WORKERS=1` les fait passer.
- Le dump de `db/schema.rb` par la version locale de PostgreSQL réécrit des contraintes sans rapport (`::character varying::text`) : le schéma du lot est repris à la main du schéma de `Develop`, seules les lignes du lot changent.

## Ce qu'on a appris sur la codebase

- `test/infrastructure/repositories/catalog/content_tree_writer_characterization_test.rb` compare toutes les colonnes écrites à un instantané : toute colonne nouvelle d'`exercises` ou de `questions` doit entrer dans `ADDED_LATER`.
- Un texte aux octets invalides faisait lever `strip` et la regex de l'octet nul (500 possible hors Rails, qui refuse déjà les paramètres mal encodés) : `AttemptInput` et `CopyInput` le refusent proprement (menace W4).
- `QuestionKinds::Written::INVALID` renvoyait `:invalid_text`, mais le DTO refuse d'abord un texte mal encodé : le code n'était jamais atteint. Il vaut `[:invalid]` depuis la revue du Lot C.
- La garde de vocabulaire refuse « leçon » dans les locales, sauf valeurs exactes listées : toute phrase de PRD qui le dit doit y entrer.

## Preuve

- 6 PR vers `Develop`, une par lot : #352 (Lot 0), #353 (B), #354 (A), #355 (D), #356 (C), #357 (E), puis #358 (retouches d'affichage). Chacune : `bin/ci-quiet` niveau pr vert sur son head final, ligne de preuve dans la PR.
- Revues `security-reviewer`, `silent-failure-hunter` et `pr-test-analyzer` sur le diff final de chaque lot ; aucune faille, tous les constats retenus corrigés avant la fusion.
- Contradiction empirique : un agent distinct des exécutants a monté l'application sur `Develop` (552ecbd1) avec un devoir Thalès en blocs, et refait le parcours à 390 px et 1 440 px : feuille, confirmation, « Vérifier ma copie », résultat de l'élève, pause de « Recommencer » après 3 copies, résultat vu par l'enseignant. Aucun débordement à 390 px ; les 3 défauts vus sont corrigés par #358.

## Ce qui reste ouvert

- Sur l'accueil de l'élève, les boutons « Refaire » restent visibles pendant la pause (le démarrage la refuse, la page de l'exercice la dit).
- `ExerciseSessionRepository#start` peut renvoyer `nil` après un `RecordNotUnique` (antérieur au chantier).
- La note d'une copie se calcule sur les questions actuelles de l'exercice : une leçon réimportée entre deux copies peut changer le total (cas accepté au cadrage).
- Le contenu « Lentilles » de la maquette de Konan n'est pas importé : seul Thalès sert de contenu de référence.
- L'heure de reprise de la pause s'affiche à l'heure du serveur (UTC), juste pour la Côte d'Ivoire.
