# Plan d'exécution — Corriger une copie comme en classe

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Une branche et une PR par lot, vers `Develop` (décision du porteur du 2026-10-28). Références : [PRD](prd.md),
> [ADR-0115](../../decisions/adr/0115-correction-complete-note-en-points-et-types-de-questions.md),
> [UDR-0140](../../decisions/udr/0140-feuille-et-resultat-corriges-comme-en-classe.md).

## Graphe

```
Lot 0 — SOCLE : menace, migration, règles du domaine, port
  ↓
  ├─► Lot A — Le résultat corrigé et le bouton            ┐
  ├─► Lot B — La pause de « Recommencer »                  ├─ en parallèle
  └─► Lot D — L'import et le détail de l'exercice          ┘
        ↓ (A et D faits)
      Lot C — Les nouveaux types à l'écran (feuille, résultat, feuille de l'enseignant)
        ↓
      Lot E — Le sujet en blocs (document, tableau)
```

L'ADR-0115 et l'UDR-0140 sont numérotées dès le cadrage : `build_index --check` refuse une décision `XXXX` sur `Develop`,
et le chantier se livre en une PR par lot vers `Develop`.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats)
- **Fichiers**     : `docs/chantiers/correction-comme-en-classe/menace.md` *(écrite d'abord)*
                     `db/migrate/…_add_points_and_kinds_to_questions.rb` · `db/schema.rb`
                     `app/domain/entities/assessment/question.rb` (points, unit, starter, criteria, `auto_graded?`, `KINDS`)
                     `app/domain/entities/assessment/question_kinds/{select,written,notebook}.rb` · `AUTO_GRADED` dans les 5 existantes
                     `app/domain/entities/assessment/question_kinds/numeric.rb` (unité retirée de la réponse)
                     `app/domain/entities/assessment/grading.rb` (`points_percent`)
                     `app/domain/entities/assessment/appreciation.rb` · `restart_pause.rb`
                     `app/domain/entities/assessment/exercise.rb` (`publishable?` : une question corrigée automatiquement ; `statement_blocks`)
                     `app/domain/policies/assessment/reveal_correction_policy.rb`
                     `app/domain/use_cases/assessment/close_exercise_session.rb` (score en points)
                     `app/domain/ports/assessment/exercise_session_repository_port.rb` · `app/infrastructure/repositories/assessment/exercise_session_repository.rb` (`recent_completions`)
                     `app/infrastructure/orm/…` des questions et des tentatives si besoin
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/assessment/grading_test.rb` (CA-14, CA-15, CA-16) ; `appreciation_test.rb` (CA-08 à CA-11) ;
                     `restart_pause_test.rb` (CA-29 à CA-33) ; `question_kinds/{select,written,notebook,numeric}_test.rb` (CA-18 à CA-20, règles de structure) ;
                     `test/domain/policies/assessment/reveal_correction_policy_test.rb` (CA-07) ; `exercise_test.rb` (CA-28) ;
                     `close_exercise_session_test.rb` ; `exercise_session_repository_test.rb` (`recent_completions`)
- **Done quand**   : les règles passent leurs tests ; un exercice existant garde sa note (CA-16) ; aucune vue ne change

---

## Lot A — Le résultat corrigé et le bouton

- **Couche**       : delivery + ui (+ query de lecture)
- **Fichiers**     : `app/controllers/assessment/session_results_controller.rb`
                     `app/infrastructure/queries/assessment/session_result_query.rb`
                     `app/views/assessment/session_results/show.html.erb` · `_question_review.html.erb` · `kinds/_choice_review.html.erb` ·
                     `kinds/{_fill_blank,_numeric,_ordering,_matching}_review.html.erb`
                     `app/views/assessment/exercise_sessions/show.html.erb` (bouton, phrase, points des légendes)
                     `config/locales/assessment/session_results.fr.yml` · `config/locales/assessment/exercise_sessions.fr.yml`
                     tests de vue et de contrôleur qui figent « Rendre ma copie » ou « jamais la bonne réponse » (à inverser)
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/assessment/session_results_controller_test.rb` (CA-02 à CA-06, CA-09 à CA-13, CA-15) ;
                     `test/controllers/assessment/exercise_sessions_controller_test.rb` (CA-01, CA-17) ; test système du parcours nominal
- **Done quand**   : sur l'exercice Thalès, l'élève clique sur « Vérifier ma copie » et lit « Bien », « À revoir », la bonne réponse de chaque
                     question ; captures 390 px et ordinateur envoyées au porteur

---

## Lot B — La pause de « Recommencer »

- **Couche**       : domaine (use case) + delivery + ui
- **Fichiers**     : `app/domain/use_cases/assessment/start_exercise_session.rb`
                     `app/controllers/assessment/exercise_sessions_controller.rb` (`create`) · `app/controllers/assessment/exercises_controller.rb`
                     `app/infrastructure/queries/assessment/exercise_progress_query.rb`
                     `app/views/assessment/exercises/show.html.erb` (pied d'actions) · `config/locales/assessment/exercises.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/assessment/start_exercise_session_test.rb` (CA-29 à CA-33) ;
                     `test/controllers/assessment/exercise_sessions_pause_test.rb` *(fichier nouveau, pour ne pas toucher celui du Lot A)* ;
                     `test/controllers/assessment/exercises_controller_test.rb` (CA-34, côté exercice)
- **Done quand**   : après 3 copies d'affilée, l'élève ne peut plus recommencer ni depuis l'exercice, ni depuis l'accueil, ni par un `POST` direct,
                     et lit l'heure de reprise

La phrase de pause sur la page du résultat (CA-34, côté résultat) est posée par le Lot A, qui lit `RestartPause` du Lot 0.

---

## Lot D — L'import et le détail de l'exercice

- **Couche**       : domaine (use case) + infrastructure
- **Fichiers**     : `config/schemas/lnclass.course-tree.v2.json` (types `select`, `written`, `notebook` ; clés `points`, `unit`, `starter`, `criteria`, `statement_blocks`)
                     `app/domain/use_cases/catalog/import_course_tree.rb` · `app/domain/entities/catalog/content_node.rb`
                     `app/domain/dtos/assessment/question_input.rb`
                     `app/infrastructure/repositories/catalog/content_tree_writer.rb` · `app/infrastructure/repositories/assessment/exercise_repository.rb`
                     `app/infrastructure/queries/assessment/exercise_detail_query.rb` · `session_play_query.rb`
                     `app/views/teams/imports/kinds/*_example.html.erb` (exemples des nouveaux types) · `app/views/teams/imports/_question_examples.html.erb`
                     `test/fixtures/files/imports/…` (un fichier « Devoir » Thalès et Lentilles)
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/catalog/import_course_tree_test.rb` (CA-26, CA-27 : une ligne par règle) ;
                     `test/infrastructure/repositories/assessment/exercise_repository_test.rb` (points, unité, grille relus à l'identique)
- **Done quand**   : un fichier « Devoir » Thalès avec tous les nouveaux éléments s'importe en brouillon ; chaque question mal construite
                     fait refuser la leçon avec un message qui la nomme

---

## Lot C — Les nouveaux types à l'écran

- **Couche**       : domaine (use case) + delivery + ui
- **Fichiers**     : `app/views/assessment/exercise_sessions/kinds/{_select,_written,_notebook}.html.erb` · `kinds/_numeric.html.erb` (unité)
                     `app/views/assessment/session_results/kinds/{_select,_written,_notebook}_review.html.erb` · `_numeric_review` (unité)
                     `app/views/assessment/exercises/sheet_kinds/{_select,_written,_notebook}.html.erb` (feuille de l'enseignant)
                     `app/javascript/controllers/assessment/counter_controller.js`
                     `app/domain/use_cases/assessment/submit_exercise_copy.rb` · `app/domain/dtos/assessment/attempt_input.rb` (2 000 caractères pour `written`)
                     `app/controllers/assessment/exercise_copies_controller.rb`
                     `config/locales/assessment/exercise_sessions.fr.yml` · `session_results.fr.yml` (clés des nouveaux types)
- **Dépend de**    : Lot A (mêmes fichiers de locales et de résultat) et Lot D (exercices de démonstration importés)
- **Test associé** : `test/domain/use_cases/assessment/submit_exercise_copy_test.rb` (CA-21, CA-22) ;
                     `test/controllers/assessment/exercise_copies_controller_test.rb` (CA-22, CA-13 : texte échappé) ;
                     tests de vue des nouveaux partiels (CA-18 à CA-21, CA-23, CA-24) ; test système sans JavaScript (liste, zone, grille)
- **Done quand**   : le « Devoir » Thalès et le « Devoir » Lentilles se font de bout en bout, à 390 px et sur ordinateur ; captures envoyées au porteur

---

## Lot E — Le sujet en blocs

- **Couche**       : domaine + ui
- **Fichiers**     : `app/domain/entities/catalog/sheet_document.rb` (validation d'une liste de blocs de sujet : `paragraph`, `box`, `table`, 10 au plus)
                     `app/views/assessment/exercise_sessions/show.html.erb` (sujet) · `app/views/assessment/session_results/show.html.erb` (sujet)
                     `app/views/assessment/exercises/show.html.erb` *(si le sujet y est rendu)*
- **Dépend de**    : Lot C
- **Test associé** : `test/domain/entities/catalog/sheet_document_test.rb` (blocs de sujet : type refusé, 11 blocs refusés) ;
                     test de vue (CA-25) ; capture à 390 px du tableau Lentilles
- **Done quand**   : le document et le tableau des maquettes s'affichent sur la feuille et le résultat, sans débordement à 390 px

---

## Vérification de collision

> Les lots parallèles (A, B, D) ne partagent aucun fichier. C et E passent après.

| Fichier | Lot propriétaire |
|---|---|
| `db/migrate/…`, `db/schema.rb` | Lot 0 |
| `app/domain/entities/assessment/question.rb`, `question_kinds/*` | Lot 0 |
| `app/domain/policies/assessment/reveal_correction_policy.rb` | Lot 0 |
| `app/domain/ports/assessment/exercise_session_repository_port.rb` | Lot 0 |
| `app/views/assessment/session_results/**` | Lot A, puis Lot C, puis Lot E |
| `app/views/assessment/exercise_sessions/show.html.erb` | Lot A, puis Lot E |
| `config/locales/assessment/session_results.fr.yml` | Lot A, puis Lot C |
| `config/locales/assessment/exercise_sessions.fr.yml` | Lot A, puis Lot C |
| `app/domain/use_cases/assessment/start_exercise_session.rb` | Lot B |
| `app/views/assessment/exercises/show.html.erb` | Lot B, puis Lot E |
| `config/locales/assessment/exercises.fr.yml` | Lot B |
| `app/controllers/assessment/exercise_sessions_controller.rb` | Lot B |
| `test/controllers/assessment/exercise_sessions_controller_test.rb` | Lot A (Lot B écrit `exercise_sessions_pause_test.rb`) |
| `config/schemas/lnclass.course-tree.v2.json`, `import_course_tree.rb`, `content_node.rb` | Lot D |
| `app/infrastructure/queries/assessment/session_play_query.rb` | Lot D |
| `app/domain/use_cases/assessment/submit_exercise_copy.rb` | Lot C |
| `app/domain/entities/catalog/sheet_document.rb` | Lot E |

## Portes de sortie

- [ ] Tous les lots sont `Done`
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat (tests lancés, parcours refait dans l'application)
- [ ] Pureté du domaine, rubocop, tests, parcours système : au vert
- [ ] ADR et UDR à jour et indexés
- [ ] `journal.md` complété
- [ ] Revues `security-reviewer` et `silent-failure-hunter` sur les Lots 0, C et D (téléversement d'import, texte libre, use cases)
