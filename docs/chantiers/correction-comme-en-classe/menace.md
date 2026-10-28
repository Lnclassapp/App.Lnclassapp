# Menace — réponse rédigée et nouvelles clés d'import (Lot 0)

> Écrite avant le code du Lot 0 (règle CLAUDE.md « Menace écrite d'abord »). Deux surfaces nouvelles : un **texte libre**
> de l'élève (2 000 caractères par question, gardé en base, affiché à l'enseignant ; ADR-0115 §5) et des **clés d'import**
> (`points`, `unit`, `starter`, `criteria`, types `select` / `written` / `notebook`, `statement_blocks`) lues dans un fichier
> JSON envoyé par l'équipe contenu, dont le contenu est ensuite montré aux élèves. Le socle pose les règles et les colonnes ;
> le rendu et l'import sont aux Lots A, C, D et E, qui reprennent les lignes « à prouver au Lot X » ci-dessous.

## Qui envoie, et ce qu'il gagne

- **Texte rédigé** : un élève (compte ordinaire, parfois un enfant). Il cherche à faire exécuter du script chez son
  enseignant (XSS stockée), à saturer la base ou la page, à faire planter l'envoi de sa copie, ou à lire la correction
  avant d'avoir vérifié sa copie.
- **Clés d'import** : un compte équipe contenu compromis, ou un fichier préparé ailleurs et importé de bonne foi. Le
  fichier est traité comme hostile (même hypothèse que [menace-import-v2](../refonte-page-lecon/menace-import-v2.md)).
  Les bornes de nombre et de taille du fichier entier (M1 à M6 de cette menace) restent celles de l'import v2.

## A. Le texte rédigé de l'élève

| # | Attaque | Ce qui l'arrête | Preuve |
|---|---|---|---|
| W1 | **Script ou HTML dans la réponse** (`<script>`, `<img onerror=…>`), lu par l'enseignant | Le texte est stocké tel quel, jamais marqué sûr : toute vue l'imprime échappé (`<%= %>`, jamais `raw` ni `html_safe`), à l'élève comme à l'enseignant. Aucun code du socle ne le rend | **À prouver au Lot C** : `exercise_copies_controller_test.rb` et la vue `_written_review` (CA-13, texte « Non, car <b>AM/AB</b> » lu en clair). Au socle : `QuestionKinds::Written` ne transforme jamais le texte (`written_test.rb`, « le texte est gardé tel quel ») |
| W2 | **Texte énorme** (100 Mo en un champ) | Trois bornes à 2 000 caractères : la règle du type (`Written::TEXT_MAX`, `well_formed?`), la colonne `question_attempts.response_text` (`limit: 2000`, migration), et le DTO d'envoi (`AttemptInput::RESPONSE_TEXT_MAX`, **Lot C**). Le serveur de Rack/Rails borne déjà la requête entière | `test/domain/entities/assessment/question_kinds/written_test.rb` (2 000 accepté, 2 001 refusé, `INVALID`) ; `test/infrastructure/orm/question_attempt_test.rb` (2 001 caractères refusés par la base) ; DTO : Lot C |
| W3 | **Octet nul** (`\0`) : PostgreSQL le refuse et l'envoi plante en 500 | `Written.well_formed?` refuse tout texte contenant `\0` (même garde que `AttemptInput` pour les trous) ; la copie revient en 422 avec le message du champ | `written_test.rb` (« un octet nul est refusé ») |
| W4 | **Texte non UTF-8 ou mal formé** | `well_formed?` exige une chaîne UTF-8 valide (`valid_encoding?`) ; sinon refus du champ | `written_test.rb` (« un texte mal encodé est refusé ») |
| W5 | **Réponse rédigée comptée juste** pour gonfler la note, ou pour la faire échouer | `Written::AUTO_GRADED = false` et `Written.correct?` toujours faux ; `Grading.points_percent` ne reçoit que les questions corrigées automatiquement ; une copie dont les réponses rédigées sont vides ou pleines a la même note | `written_test.rb` ; `grading_test.rb` (CA-15) ; `close_exercise_session_test.rb` (une question rédigée ne change pas la note) |
| W6 | **Lire la correction avant de vérifier la copie**, ou sur une copie abandonnée, ou la copie d'un autre élève | `Policies::Assessment::RevealCorrectionPolicy` : élève auteur d'une copie `completed` seulement ; équipe et enseignant comme `RevealAnswersPolicy`. La feuille garde `RevealAnswersPolicy` (jamais une bonne réponse à l'élève) | `reveal_correction_policy_test.rb` (CA-07 : en cours, abandonnée, autre élève, direction, visiteur refusés). Rendu : Lot A |
| W7 | **Le début de phrase (`starter`) envoyé comme réponse** (l'élève rend la copie sans rien écrire et la machine y voit un texte) | `starter` n'est qu'un attribut d'affichage de la question ; il n'entre jamais dans une tentative. Une zone vide envoie `nil`/vide, la question est `unanswered` | **À prouver au Lot C** (`submit_exercise_copy_test.rb`) |
| W8 | **La grille de vérification enregistrée** (surface d'écriture inutile) | Aucune colonne ne reçoit les cases cochées ; `criteria` est une propriété de la question, en lecture seule côté élève | Le schéma : `db/schema.rb` ne gagne aucune colonne de tentative ; `test/infrastructure/orm/question_attempt_test.rb` (colonnes des tentatives) |
| W9 | **Contourner la pause** de « Recommencer » | `RestartPause` (règle) et `ExerciseSessionRepositoryPort#recent_completions` ne comptent que les copies `completed` | `restart_pause_test.rb` (CA-29 à CA-33) ; `exercise_session_repository_test.rb` (abandonnées exclues, autre exercice exclu, 3 au plus). Le refus à la création : Lot B |

## B. Les nouvelles clés d'import

| # | Attaque | Ce qui l'arrête | Preuve |
|---|---|---|---|
| I1 | **Points hors bornes** (0, 25, 0,3, négatif, `NaN`) : fausse la note ou la division par zéro | Règle du domaine (`Question#structure_errors`, `:points_out_of_range` : 0,5 à 20 par demi-point) ; `Grading.points_percent` renvoie 0 sans question corrigée automatiquement ; contrainte SQL `questions_points_range` (ADR-0115 §6). Le schéma JSON (`minimum`, `maximum`, `multipleOf`) : Lot D | `question_test.rb` (une ligne par borne) ; `grading_test.rb` (total nul) ; `test/infrastructure/orm/question_test.rb` (la base refuse 0, 25 et 0,3) |
| I2 | **Unité piégée** : trop longue, ou qui change le sens de la réponse (unité `0` : « 40 » deviendrait « 4 », donc juste pour une réponse attendue de 4) | 10 caractères au plus (colonne `limit: 10` et règle `:unit_too_long`) ; une unité n'a ni chiffre ni signe ni séparateur décimal (`:unit_invalid`) ; l'unité est retirée **en fin de réponse seulement** et jamais si elle est refusée à la structure (défense en profondeur), sans expression régulière construite depuis elle (aucun ReDoS ni injection de motif) ; une autre unité reste une saisie mal formée | `question_test.rb` ; `numeric_test.rb` (« 40 » avec l'unité « 0 » n'est pas lu « 4 » ; « 48 mm » mal formée pour « cm » ; unité à métacaractères `^$|(` inoffensive) |
| I3 | **Unité sur un autre type que `numeric`**, début de phrase ou grille sur un autre type que `written` : clés sans effet qui masquent une erreur de rédaction | Refus à la structure : `:unit_not_allowed`, `:starter_not_allowed`, `:criteria_not_allowed` | `question_test.rb` |
| I4 | **Début de phrase ou grille démesurés** | `starter` : 150 caractères (colonne et règle `:starter_too_long`) ; `criteria` : 8 critères de 150 caractères au plus, aucun vide (`:criteria_too_many`, `:criteria_too_long`, `:criteria_blank`) | `question_test.rb` (8 acceptés, 9 refusés, 150/151) |
| I5 | **`select` sans bonne réponse, avec deux, avec 1 ou 11 propositions, deux trous, doublons ou proposition vide** | `QuestionKinds::Select.structure_errors` : 2 à 10 propositions, une seule correcte, `___` au plus une fois, propositions distinctes (normalisées) et non vides | `select_test.rb` (une ligne par règle) |
| I6 | **`written` ou `notebook` sans corrigé type** (l'élève ne verrait rien en face de son texte), ou avec des propositions | Refus : `:explanation_required`, `:answers_not_allowed`. `notebook` n'a ni `starter` ni grille | `written_test.rb`, `notebook_test.rb` |
| I7 | **Exercice sans question corrigée automatiquement** (note impossible, `points_percent` à 0 sans fin) | `Exercise#publishable?` exige au moins une question `auto_graded?` ; l'enregistrement en brouillon reste permis (CA-28) | `exercise_test.rb` |
| I8 | **Type inconnu glissé dans la base** | Contrainte `questions_question_type_values` étendue aux trois types ; `Question.kind_for` renvoie nil pour tout autre (`:unknown_question_type`) | `test/infrastructure/orm/question_test.rb` (un type inconnu refusé) ; `question_test.rb` |
| I9 | **`statement_blocks` : blocs hostiles** (HTML brut, 10 000 blocs, type inconnu) rendus aux élèves | Au socle, la colonne `jsonb` n'est lue que par `ExerciseRepository` et **aucune vue ne la rend** ; aucun code n'y écrit avant le Lot D. La validation (`SheetDocument` : `paragraph`, `box`, `table`, 10 au plus) est au **Lot E**, et le rendu passe par les partiels des fiches, jamais en HTML brut. Le Lot D n'écrit la clé qu'après cette validation | **À prouver aux Lots D et E** (`sheet_document_test.rb`, `import_course_tree_test.rb`). Socle : `exercise_repository_test.rb` (lecture à l'identique) |
| I10 | **Note faussée par un exercice ancien** (régression : un exercice existant change de note) | Défauts : `points` 1, aucune unité, grille vide ; avec toutes les questions à 1 point, `points_percent` = ancien calcul | `grading_test.rb` (CA-16, comparaison avec `score_percent` sur 0 à 30 questions) ; `close_exercise_session_test.rb` (les tests d'origine restent verts) |
| I11 | **Échec silencieux** à la clôture : une question absente de l'exercice ou une tentative d'une autre question change la note sans erreur | `CloseExerciseSession` calcule sur les questions de l'exercice de la session (jamais sur le compte des tentatives) ; une tentative d'une question étrangère est ignorée ; une question sans tentative compte pour fausse | `close_exercise_session_test.rb` |

## Ce que le socle ne fait pas

- Aucune lecture de fichier : le socle n'ouvre pas de téléversement. Les clés d'import sont lues par l'import v2 (Lot D),
  qui garde ses garde-fous M1 à M21.
- Aucun rendu : W1, W7, I9 se prouvent là où le texte et les blocs s'affichent (Lots A, C, E).
