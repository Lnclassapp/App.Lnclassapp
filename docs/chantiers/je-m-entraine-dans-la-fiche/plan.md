# Plan d'exécution — « Je m’entraîne » dans la fiche de révision

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Spécification : [`prd.md`](prd.md) · ADR-XXXX-entrainement-de-notion-corrige-sans-trace · ADR-XXXX-questions-a-plusieurs-cases-et-indice · UDR-XXXX-je-m-entraine-dans-la-fiche.

## Graphe

```
Lot 0 — SOCLE : migration, entités, ports, import, schéma, routes, libellés (séquentiel)
  ↓
  ├─► Lot A — cases multiples dans la copie notée ──┬─► Lot B — indice dans la copie notée   ┐
  │                                                 └─► Lot C — « Je m'entraîne » dans la fiche ┘ en parallèle
  └─► Lot D — contenu : entraînement des 6 leçons pilotes (en parallèle de A, B et C)
```

A doit précéder B et C : la règle de correction par case (classes `QuestionKinds`) appartient à A, et C l'utilise pour juger la fiche. B et A touchent les mêmes vues de la copie (`exercise_sessions/show`, `_question_review`). D ne touche que des fichiers de contenu et dépend seulement du schéma gelé au Lot 0.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : `db/migrate/…_add_blanks_and_hints.rb` · `db/schema.rb`
                     `app/domain/entities/assessment/question.rb` (attributs `hint`, `blanks`, contrat `blank_results(response)` qui lève `NotImplementedError` pour les kinds pas encore portés)
                     `app/domain/entities/assessment/answer.rb` (attribut `blank`)
                     `app/domain/entities/assessment/question_attempt.rb` (`blank_responses`, `blank_results`)
                     `app/domain/entities/assessment/exercise_session.rb` (`hinted_question_ids`)
                     `app/domain/entities/catalog/notion_practice.rb` (nouveau : `from_raw`, `errors_for`, `digest`, `without_correction`)
                     `app/domain/entities/catalog/notion_sheet.rb` (attribut `practice`)
                     `app/domain/ports/assessment/exercise_session_repository_port.rb` (`record_hint(session_id:, question_id:)`, `record_copy` accepte `blank_responses:` et `blank_results:`)
                     `app/domain/ports/catalog/essential_repository_port.rb` (`practice_for(course_slug:, notion_slug:, statuses:)`)
                     `app/domain/ports/catalog/content_tree_writer_port.rb` (`QuestionNode` : `hint`, réponses avec `blank`)
                     `app/domain/use_cases/catalog/import_course_tree.rb` · `app/domain/entities/catalog/content_node.rb` (lecture de `practice`, `hint`, `blank` ; `NotionPractice.errors_for`)
                     `app/infrastructure/repositories/catalog/content_tree_writer.rb` (écrit `answers.blank`, `questions.hint`, `sheet.practice`)
                     `app/infrastructure/orm/…` (colonnes nouvelles, si un modèle les déclare)
                     `config/schemas/lnclass.course-tree.v3.json` (`notion.practice`, `question.hint`, `answer.blank`)
                     `config/routes/catalog.rb` (`POST courses/:course_slug/notions/:slug/practice_check`) · `config/routes/assessment.rb` (`POST exercise_sessions/:public_id/hints`)
                     `config/locales/catalog/revision_sheets.fr.yml` · `config/locales/assessment/exercise_sessions.fr.yml` · `config/locales/assessment/session_results.fr.yml` · `config/locales/catalog/imports.fr.yml`
                     `app/helpers/assessment/blanks_helper.rb` (nouveau : `blank_segments(content)`, partagé par A et C)
                     `test/fixtures/questions.yml` · `test/fixtures/answers.yml` · `test/fixtures/essentials.yml` (une question à 2 cases, une avec indice, une notion avec `practice`)
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/catalog/notion_practice_test.rb` (forme, clés interdites `points`/`image`/`criteria`, empreinte stable, `without_correction` sans `correct` ni réponses saisies) · `test/domain/use_cases/catalog/import_course_tree_practice_test.rb` (un fichier avec `practice`, `hint` et `blank` s'importe, et la base porte les valeurs) · `test/helpers/assessment/blanks_helper_test.rb`
- **Done quand**   : `bin/rails db:migrate` passe ; un fichier v3 avec `practice`, `hint` et `blank` s'importe sur la base de développement, et la notion, la question et la réponse portent ces valeurs ; les contrats (entités, ports, routes, libellés) sont gelés et poussés sur `feature/je-m-entraine-dans-la-fiche`

> Le Lot 0 est plus gros que d'habitude, parce que l'import (schéma, validation, écriture) est un contrat partagé par A, C et D. Il ne contient aucune règle de correction : celle-ci est dans le Lot A.

---

## Lot A — Une question à plusieurs cases, notée case par case, dans la copie notée

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/entities/assessment/question_kinds/numeric.rb` · `select.rb` · `fill_blank.rb` (jugement case par case, `structure_errors` par case, levée de « un seul `___` »)
                     `app/domain/entities/assessment/question_kinds/choice.rb` · `ordering.rb` · `matching.rb` · `written.rb` · `notebook.rb` (`blank_results` à une case, refus de `blank` > 0)
                     `app/domain/entities/assessment/grading.rb` (`share`, `points_percent` en `Rational`)
                     `app/domain/use_cases/assessment/close_exercise_session.rb` · `app/domain/use_cases/assessment/submit_exercise_copy.rb`
                     `app/domain/dtos/assessment/attempt_input.rb` · `app/domain/dtos/assessment/copy_input.rb`
                     `app/infrastructure/repositories/assessment/exercise_session_repository.rb` (`record_copy` avec cases)
                     `app/infrastructure/repositories/assessment/exercise_repository.rb` (hydrate `blank` et `hint`)
                     `app/infrastructure/queries/assessment/session_result_query.rb` · `app/infrastructure/queries/assessment/session_play_query.rb` (cases ; et, pour B, `hint?` par question, `hinted_question_ids` de la copie, `hinted?` dans `ReviewQuestion`)
                     `app/controllers/assessment/exercise_copies_controller.rb` (params `blanks`)
                     `app/views/assessment/exercise_sessions/kinds/_numeric.html.erb` · `_fill_blank.html.erb` · `_select.html.erb`
                     `app/views/assessment/session_results/kinds/_numeric_review.html.erb` · `_fill_blank_review.html.erb` · `_select_review.html.erb`
                     `app/views/teams/answer_keys/show.html.erb` (cases et indice ; l'entraînement est ajouté par C, voir collision)
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/entities/assessment/grading_test.rb` (CA-11) · `test/domain/entities/assessment/question_kinds/numeric_test.rb` · `select_test.rb` · `fill_blank_test.rb` (CA-13 : case sans réponse refusée) · `test/infrastructure/grading_regression_test.rb` (CA-12) · `test/integration/assessment/multi_blank_copy_test.rb` (CA-11 de bout en bout)
- **Done quand**   : sur `bin/dev`, un élève fait un exercice dont une question chiffrée a 2 cases et vaut 2 points, juste sur la 1re et faux sur la 2e ; sa page de résultat montre « Juste », « À revoir » et 1 / 2 pt ; les notes des copies existantes sont inchangées (CA-12) ; à 390 px, les cases passent à la ligne sans défilement horizontal

---

## Lot B — L'indice dans une copie notée

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/assessment/open_hint.rb` (nouveau)
                     `app/controllers/assessment/hints_controller.rb` (nouveau)
                     `app/views/assessment/hints/_hint.html.erb` · `app/views/assessment/hints/create.turbo_stream.erb` (nouveaux)
                     `app/views/assessment/exercise_sessions/show.html.erb` (bouton « Indice », indices déjà ouverts, `hint_notice`)
                     `app/views/assessment/session_results/_question_review.html.erb` (badge « Indice ouvert »)
- **Dépend de**    : Lot A (qui implémente `record_hint` et expose les indices dans les deux queries de la copie)
- **Test associé** : `test/domain/use_cases/assessment/open_hint_test.rb` (idempotence, question sans indice, autre exercice) · `test/controllers/assessment/hints_controller_test.rb` (CA-15 : 404 sur une copie rendue ou celle d'un autre élève ; indice absent du HTML avant le POST) · `test/integration/assessment/hint_in_copy_test.rb` (CA-14)
- **Done quand**   : sur `bin/dev`, l'élève ouvre l'indice de la question 2 d'une copie, le lit, rend sa copie avec la même note que sans indice ; sa page de résultat et la copie vue par l'enseignant montrent « Indice ouvert » sur la question 2 seulement

---

## Lot C — « Je m'entraîne » dans la fiche de révision

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/catalog/check_practice.rb` (nouveau)
                     `app/domain/entities/catalog/revision_preview.rb` (`PRACTICE`, 0 mot)
                     `app/infrastructure/repositories/catalog/essential_repository.rb` (`practice_for`)
                     `app/infrastructure/queries/catalog/revision_sheet_query.rb` (`Notion#practice`, sans correction)
                     `app/controllers/catalog/practice_checks_controller.rb` (nouveau, `rate_limit` 30/min)
                     `app/views/catalog/revision_sheets/_sheet.html.erb` · `app/views/catalog/revision_sheets/_practice.html.erb` (nouveau)
                     `app/views/catalog/practice_checks/_result.html.erb` · `app/views/catalog/practice_checks/show.html.erb` (nouveaux)
                     `app/assets/stylesheets/course_sheet.css` (ton `practice`, `.sheet-input`, `.sheet-button`, `.sheet-verdict`, `.sheet-practice-*`)
                     `app/views/teams/answer_keys/_practice.html.erb` (nouveau : « Je m'entraîne (non noté) » dans le corrigé de l'équipe, rendu par `show` via un appel posé au Lot A)
- **Dépend de**    : Lot A
- **Test associé** : `test/domain/use_cases/catalog/check_practice_test.rb` (CA-4 : aucune ligne écrite ; CA-7 : empreinte) · `test/domain/entities/catalog/revision_preview_test.rb` (CA-10) · `test/domain/entities/assessment/practice_parity_test.rb` (CA-5) · `test/controllers/catalog/practice_checks_controller_test.rb` (CA-6, CA-7, CA-8, CA-9) · `test/views/catalog/revision_sheets/practice_leak_test.rb` (CA-3) · `test/integration/catalog/practice_in_sheet_test.rb` (CA-1, CA-2, CA-16, CA-17, CA-18) · `test/system/catalog/practice_in_sheet_test.rb` (Turbo Frame, 390 px)
- **Done quand**   : sur `bin/dev`, dans la fiche d'une leçon pilote, la notion 1 montre « Je m'entraîne » entre l'exemple et le piège ; « Vérifier » rend les verdicts par case sans recharger la page, puis « Correction » ; aucune ligne n'est écrite ; le HTML de la page ne contient aucune bonne réponse ; le JavaScript commun reste ≤ 61 Ko (`bin/check-asset-budget`)

---

## Lot D — Contenu : l'entraînement des 6 leçons pilotes

- **Couche**       : contenu (aucun fichier de `app/`)
- **Fichiers**     : `docs/contenus/lecons-traitees/3eme/mathematiques/proprietes-de-thales-dans-un-triangle.json`
                     `docs/contenus/lecons-traitees/3eme/francais/le-texte-argumentatif.json`
                     `docs/contenus/lecons-traitees/3eme/physique-chimie/les-lentilles.json`
                     `docs/contenus/lecons-traitees/3eme/svt/la-circulation-sanguine.json`
                     `docs/contenus/lecons-traitees/3eme/histoire-geographie/histoire-l-accession-de-la-cote-d-ivoire-a-l-independance.json`
                     `docs/contenus/lecons-traitees/3eme/edhc/le-scrutin-electoral.json`
                     (et leurs copies sous `leçons/<matière>/…` si le dépôt les tient en double)
                     `test/integration/contenus/pilotes_je_m_entraine_test.rb` (nouveau)
- **Dépend de**    : Lot 0 (schéma `practice`, `hint`, `blank` gelé)
- **Test associé** : `test/integration/contenus/pilotes_je_m_entraine_test.rb` (les 6 fichiers passent `ImportCourseTree` à blanc ; chaque notion a un `practice` de 1 à 6 questions ; au moins une question à plusieurs cases et un indice par leçon) — CA-19
- **Done quand**   : les 6 leçons s'importent sans erreur sur la base de développement ; chaque notion a son exercice d'entraînement, distinct de son exercice noté (aucune question identique, vérifié par le test) ; les exercices sont relus par l'équipe avant la recette

---

## Dispatch

```
Vague 1 : Lot 0                    → 1 agent (executant-lot), séquentiel
Vague 2 : Lot A ‖ Lot D            → 2 agents, worktrees isolés
Vague 3 : Lot B ‖ Lot C            → 2 agents, worktrees isolés (après fusion de A dans la branche de chantier)
Puis    : challenger (rôle distinct), bin/ci-quiet sur le head final, revues (security-reviewer, silent-failure-hunter, pr-test-analyzer : une route, deux use cases et un import sont touchés)
```

Worktrees, depuis la branche de chantier une fois le lot amont fusionné :

```bash
git worktree add ../lnclass-je-m-entraine-lot-a -b feature/je-m-entraine-dans-la-fiche-lot-a feature/je-m-entraine-dans-la-fiche
git worktree add ../lnclass-je-m-entraine-lot-d -b feature/je-m-entraine-dans-la-fiche-lot-d feature/je-m-entraine-dans-la-fiche
```

Le brief de chaque agent contient le chemin absolu de son worktree, son lot recopié en entier, `prd.md`, l'UDR et l'ADR qui le concernent, l'ordre test rouge → domaine → infrastructure → delivery → UI. Il ne touche aucun fichier hors de son champ `Fichiers` : s'il en a besoin, il s'arrête et remonte.

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `db/migrate/…`, `db/schema.rb` | Lot 0 |
| `config/routes/catalog.rb`, `config/routes/assessment.rb` | Lot 0 |
| `config/locales/catalog/revision_sheets.fr.yml`, `imports.fr.yml` | Lot 0 |
| `config/locales/assessment/exercise_sessions.fr.yml`, `session_results.fr.yml` | Lot 0 |
| `config/schemas/lnclass.course-tree.v3.json` | Lot 0 |
| `app/domain/entities/assessment/question.rb`, `answer.rb`, `question_attempt.rb`, `exercise_session.rb` | Lot 0 |
| `app/domain/entities/catalog/notion_practice.rb`, `notion_sheet.rb`, `content_node.rb` | Lot 0 |
| `app/domain/use_cases/catalog/import_course_tree.rb`, `app/infrastructure/repositories/catalog/content_tree_writer.rb` | Lot 0 |
| `app/helpers/assessment/blanks_helper.rb` (A et C) | Lot 0 |
| `test/fixtures/questions.yml`, `answers.yml`, `essentials.yml` | Lot 0 |
| `app/infrastructure/repositories/assessment/exercise_session_repository.rb` (`record_copy` et `record_hint`) | Lot A (A implémente aussi `record_hint`, une ligne `array_append` sous le verrou ; B l'appelle sans toucher au fichier) |
| `app/infrastructure/queries/assessment/session_play_query.rb`, `session_result_query.rb` | Lot A (ils exposent aussi les champs d'indice que B affiche) |
| `app/views/teams/answer_keys/show.html.erb` | Lot A (il pose `render "teams/answer_keys/practice", …` sous chaque notion ; C écrit le partial) |
| `app/views/assessment/exercise_sessions/show.html.erb`, `session_results/_question_review.html.erb` | Lot B (A ne touche que les partials `kinds/`) |
| `app/domain/entities/assessment/question_kinds/*` | Lot A |
| `app/views/catalog/revision_sheets/_sheet.html.erb`, `app/assets/stylesheets/course_sheet.css` | Lot C |
| `docs/contenus/lecons-traitees/3eme/**` | Lot D |

Contrôle mécanique (`awk … | uniq -d`) : à relancer avant chaque vague.

---

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

## Couverture des critères d'acceptation

| CA | Lot |
|---|---|
| CA-1, CA-2, CA-3, CA-4, CA-5, CA-6, CA-7, CA-8, CA-9, CA-10, CA-16, CA-17, CA-18 | C |
| CA-11, CA-12, CA-13 | A (CA-13 : import au Lot 0, refus par case au Lot A) |
| CA-14, CA-15 | B |
| CA-19 | D, puis le challenger sur la recette |

Aucun critère orphelin.

## Challenger empirique — non négociable

Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.

Mandat pour ce chantier :

- **Parcours nominal**, sur une notion de chacune des 6 leçons pilotes, à 390 px et sur ordinateur : s'entraîner dans la fiche (indice, « Vérifier » faux puis juste, « Correction »), puis faire la copie notée d'une question à plusieurs cases avec un indice ouvert, et lire le résultat côté élève et côté enseignant.
- **Chemins d'erreur** : réimporter l'entraînement pendant que la fiche est ouverte puis « Vérifier » (409) ; 31 « Vérifier » en une minute (429) ; « Vérifier » sans JavaScript ; demander l'indice d'une copie rendue (404).
- **Mesures** : nombre de lignes en base avant et après 20 « Vérifier » (aucune différence) ; recherche dans le source de la page d'une valeur attendue (absente) ; `bin/check-asset-budget` (≤ 61 Ko).
