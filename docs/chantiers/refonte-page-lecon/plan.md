# Plan d'exécution — Refonte de la page de la leçon : fiche de révision, « Prépare interros » et exercices sur feuille

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

Décisions : [ADR-0113](../../decisions/adr/0113-exercice-de-lecon-avec-sujet-et-notion-sans-page.md) · [ADR-0112](../../decisions/adr/0112-copie-a-rendre.md) · [UDR-0139](../../decisions/udr/0139-page-de-la-lecon-fiche-de-revision-et-prepare-interros.md) · [UDR-0138](../../decisions/udr/0138-exercice-sur-feuille-et-copie-a-rendre.md)

## Graphe

```
Lot 0 — SOCLE : schéma, contrats, route nouvelle, textes, squelette de la page        (porteur, séquentiel)
  ↓
  ├─► Lot A — Fiche de révision et « Voir plus »                   (Touré)        ┐
  ├─► Lot B — « Prépare interros » : états élève, Assigner, classe (porteur)      │ en parallèle
  ├─► Lot C — Exercice sur feuille et copie à rendre               (porteur)      │
  └─► Lot D — Import v2 et contenu Thalès                          (Touré)        ┘
  ↓
Lot E — Entrées, redirections, lectures et retrait de l'ancien      (Touré, seul)
```

## Pilotes (équipe du 2026-10-28 : le porteur et Touré)

| Vague | Porteur | Touré |
|---|---|---|
| 1 | **Lot 0** — socle | prépare le contenu Thalès v2 (8 sujets, 8 exercices) pour le Lot D : il ne dépend pas du code |
| 2 | **Lot B** — Prépare interros · **Lot C** — copie à rendre | **Lot A** — fiche de révision · **Lot D** — import v2 et contenu Thalès |
| 3 | challenger des lots A et D | **Lot E** — entrées, redirections, retraits · challenger des lots B et C |

- Chaque pilote lance un agent `executant-lot` par lot et relit son résultat ; les deux lots d'une même personne tournent en parallèle, dans deux worktrees.
- Le challenger d'un lot n'en est jamais le pilote : chacun met à l'épreuve les lots de l'autre (parcours nominal et un chemin d'erreur, dans l'application).
- Charge : porteur = Lot 0, B, C ; Touré = A, D, E et le contenu.

Règle « une PR, un pilote » : tous les lots se fusionnent dans `feature/refonte-page-lecon` ; une seule PR vers `Develop`, assignée au porteur.

---

## Lot 0 — Socle · pilote : porteur

- **Couche**       : infrastructure + domaine (contrats) + delivery (squelette) + textes
- **Fichiers**     : `db/migrate/XXXX_attach_exercises_to_courses.rb`
                     `db/migrate/XXXX_archive_exercises_before_lesson_redesign.rb`
                     `db/migrate/XXXX_add_unanswered_to_question_attempts.rb`
                     `db/schema.rb`
                     `app/domain/entities/assessment/exercise.rb` (`course_id`, `essential_id` facultatif, `statement`, `lesson_wide?`)
                     `app/domain/ports/assessment/exercise_repository_port.rb` (`for_course(course_id:)`)
                     `app/domain/ports/assessment/exercise_session_repository_port.rb` (`record_copy(session_id:, attempts:, at:)`, signature seule)
                     `app/infrastructure/orm/exercise.rb` · `app/infrastructure/orm/question_attempt.rb`
                     `app/infrastructure/repositories/assessment/exercise_repository.rb` (mapping `course_id` / `statement`, `for_course`, refus d'une notion d'une autre leçon)
                     `test/support/factories/assessment.rb` (exercices avec `course_id`, exercice de toute la leçon)
                     `app/infrastructure/queries/catalog/revision_sheet_query.rb` *(squelette : contrat `Revision = Data.define(:kind, :sheet, :texts, :cut)`, rend `kind: :empty` ; complété par le Lot A)*
                     `app/infrastructure/queries/catalog/prepare_interros_query.rb` *(squelette : contrat `Prepare = Data.define(:groups, :lesson_wide, :targets)`, rend des listes vides ; complété par le Lot B)*
                     `app/controllers/catalog/courses_controller.rb` (`show` lit les deux queries)
                     `app/views/catalog/courses/show.html.erb` (structure UDR §3.1, sans le bouton « Fiche de cours », sans `#course_essentials`)
                     `app/views/catalog/courses/_revision_sheet.html.erb` *(squelette : état vide ; complété par le Lot A)*
                     `app/views/catalog/courses/_prepare_interros.html.erb` *(squelette : état vide ; complété par le Lot B)*
                     `config/routes/assessment.rb` (ajout de `POST /sessions/:public_id/copy` → `exercise_copies#create`)
                     `config/locales/catalog/courses.fr.yml` · `config/locales/catalog/course_sheets.fr.yml` · `config/locales/classroom/classroom_courses.fr.yml` · `config/locales/classroom/student_classrooms.fr.yml` · `config/locales/assessment/exercises.fr.yml` · `config/locales/assessment/exercise_sessions.fr.yml` · `config/locales/assessment/session_results.fr.yml` (toutes les valeurs des deux UDR ; aucune clé supprimée)
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/assessment/exercise_test.rb` · `test/infrastructure/repositories/assessment/exercise_repository_test.rb` · `test/db/archive_exercises_migration_test.rb` (CA-30)
- **Done quand**   : `bin/rails db:migrate` passe sur une base semée ; tous les exercices existants sont archivés ; la page d'une leçon montre « Fiche de révision » et « Prépare interros » à l'état vide ; les ports sont gelés et la suite existante est verte (l'ancien écran de réponse marche encore)

> **Le Lot 0 gèle les contrats.** Les lots verticaux implémentent les ports et complètent les squelettes ; ils ne redéfinissent ni un port, ni une signature de query, ni une clé de texte. Un lot qui en a besoin **s'arrête** : le Lot 0 rouvre.
> **Aucun lot parallèle ne démarre avant que le Lot 0 soit fusionné** dans `feature/refonte-page-lecon`.

---

## Lot A — Fiche de révision dans la page de la leçon, 150 mots puis « Voir plus » · pilote : Touré

- **Couche**       : domaine + infrastructure + ui
- **Fichiers**     : `app/domain/entities/catalog/revision_preview.rb`
                     `app/infrastructure/queries/catalog/revision_sheet_query.rb` (fiche cahier, ou texte de la leçon puis des notions publiées ; coupe)
                     `app/views/catalog/courses/_revision_sheet.html.erb`
                     `app/views/catalog/course_sheets/_sheet.html.erb` (extrait de `show`)
                     `app/views/catalog/course_sheets/show.html.erb` (rend `_sheet`)
                     `app/views/catalog/course_sheets/_page.html.erb` · `app/views/catalog/course_sheets/_block.html.erb` (cible `rest` après la coupe)
                     `app/javascript/controllers/catalog/revision_more_controller.js`
                     `app/assets/stylesheets/course_sheet.css` · `app/assets/stylesheets/application.tailwind.css` (`.revision-fade`)
                     `test/design/design_tokens_test.rb` (exception d'UDR-0137 étendue aux deux partials)
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/entities/catalog/revision_preview_test.rb` (150 mots, fin de bloc, formule = 1 mot, figure = 0) · `test/infrastructure/queries/catalog/revision_sheet_query_test.rb` · `test/integration/catalog/revision_sheet_test.rb` (CA-01, CA-02, CA-03, CA-04, CA-05, CA-09) · `test/system/catalog/revision_sheet_test.rb` (Voir plus / Voir moins, figure interactive dépliée)
- **Done quand**   : sur la leçon Thalès, élève à 390 px et sur ordinateur, la fiche s'arrête après le premier bloc qui passe 150 mots, « Voir plus » la déplie entière sans requête et « Voir moins » la replie ; sans JavaScript, toute la fiche se lit ; une leçon sans fiche cahier montre ses notions en intertitres ; captures envoyées au porteur
- **Reprise de la revue du Lot 0** (#332) :
  - réactiver les deux tests mis en `skip` par le Lot 0 : la sanitisation du texte de la leçon au rendu (`test/controllers/catalog/courses_controller_test.rb`, son nom cite le CA-04 d'un ancien PRD, à renommer) et la pièce jointe Action Text affichée par son nom sans adresse (`test/integration/identity/rich_text_attachment_test.rb:8`, ADR-0060) ;
  - remettre dans `test/system/catalog/course_catalog_test.rb` le rendu des formules (KaTeX) et le rendu après morphing, retirés par le Lot 0 qui ne vérifie plus que la base.

---

## Lot B — « Prépare interros » : liste, états de l'élève, « Assigner », page de la leçon dans la classe · pilote : porteur

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/catalog/prepare_interros_query.rb` (exercices publiés de la leçon dans l'ordre, groupés par notion puis « Toute la leçon » ; état élève : lacune, assignation, meilleure note ; statut pour l'équipe ; cibles d'assignation)
                     `app/infrastructure/queries/classroom/catalog_assignment_targets_query.rb` (cibles par leçon)
                     `app/views/catalog/courses/_prepare_interros.html.erb` · `app/views/catalog/courses/_exercise_row.html.erb`
                     `app/controllers/classroom/classroom_courses_controller.rb` · `app/infrastructure/queries/classroom/classroom_course_query.rb` · `app/views/classroom/classroom_courses/show.html.erb` (les deux sections, bascules de cette classe)
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/catalog/prepare_interros_query_test.rb` (ordre, états, priorité des états) · `test/integration/catalog/prepare_interros_test.rb` (CA-06, CA-10, CA-11) · `test/integration/classroom/assign_from_lesson_test.rb` (CA-07, CA-08) · `test/controllers/classroom/classroom_courses_controller_test.rb` · `test/integration/classroom/assignment_follow_up_copies_test.rb` (CA-24) · `test/system/catalog/prepare_interros_test.rb` (l'enseignant assigne sans recharger)
- **Done quand**   : un enseignant de 3ème ouvre la leçon Thalès, voit 8 exercices (4 de notion, 4 de toute la leçon), clique « Assigner » pour la 3ème 1 et la ligne passe à « Assignée » sans rechargement ; un élève y voit « À rendre jeudi », « 14/20 » ou « À revoir » ; la page de la leçon dans la classe montre les mêmes sections ; captures envoyées au porteur
- **Reprise de la revue du Lot 0** (#332) :
  - un exercice de toute la leçon (`essential_id` nul) est exclu des jointures internes sur `essential` : passer par `exercises.course_id` avec `left_joins(:essential)` dans `app/infrastructure/queries/catalog/course_level_query.rb:12-14`, `app/infrastructure/queries/assessment/exercise_detail_query.rb:29`, `app/infrastructure/queries/assessment/daily_exercise_query.rb:63`, `app/infrastructure/queries/classroom/student_home_query.rb:164`, `app/infrastructure/queries/catalog/team_home_query.rb:34` et `app/infrastructure/repositories/classroom/assignment_repository.rb:62` (`record.essential.course` lève une erreur), avec un test « exercice sans notion » par requête ; test de refus : un élève d'un autre niveau reçoit 404 sur `GET /exercises/:public_id` et `GET /sessions/:public_id` d'un exercice de toute la leçon, un élève du bon niveau 200 ;
  - `for_course` (`app/infrastructure/repositories/assessment/exercise_repository.rb:19-22`) rend les exercices de tout statut : la requête de l'élève filtre `published`, `archived_at IS NULL` et parents publiés (ADR-0028) ; tests : l'élève ne voit dans « Prépare interros » ni brouillon, ni archivé, ni exercice d'une autre leçon, et `targets` reste vide hors enseignant ;
  - tester `parents_published` pour un exercice de toute la leçon d'un cours en brouillon, et `next_positions` avec deux notions sœurs dans le même appel.

---

## Lot C — Exercice sur feuille, copie à rendre, résultat · pilote : porteur

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/dtos/assessment/copy_input.rb`
                     `app/domain/use_cases/assessment/submit_exercise_copy.rb`
                     `app/domain/use_cases/assessment/close_exercise_session.rb` (pas de lacune sans notion)
                     `app/infrastructure/repositories/assessment/exercise_session_repository.rb` (`record_copy`)
                     `app/infrastructure/queries/assessment/exercise_detail_query.rb` (sujet, questions, mélange de graine exercice)
                     `app/infrastructure/queries/assessment/session_play_query.rb` (toute la copie)
                     `app/infrastructure/queries/assessment/session_result_query.rb` (« Sans réponse »)
                     `app/controllers/assessment/exercise_copies_controller.rb` · `app/controllers/assessment/exercise_sessions_controller.rb` · `app/controllers/assessment/exercises_controller.rb`
                     `app/views/assessment/exercises/show.html.erb` · `app/views/assessment/exercises/sheet_kinds/_choice.html.erb` · `app/views/assessment/exercises/sheet_kinds/_fill_blank.html.erb` · `app/views/assessment/exercises/sheet_kinds/_numeric.html.erb` · `app/views/assessment/exercises/sheet_kinds/_ordering.html.erb` · `app/views/assessment/exercises/sheet_kinds/_matching.html.erb`
                     `app/views/assessment/exercise_sessions/show.html.erb` · `app/views/assessment/exercise_sessions/kinds/_choice.html.erb` · `app/views/assessment/exercise_sessions/kinds/_fill_blank.html.erb` · `app/views/assessment/exercise_sessions/kinds/_numeric.html.erb` · `app/views/assessment/exercise_sessions/kinds/_ordering.html.erb` · `app/views/assessment/exercise_sessions/kinds/_matching.html.erb` (`f` préfixé, ids préfixés)
                     `app/views/assessment/session_results/show.html.erb` · `app/views/assessment/session_results/_question_review.html.erb` · `app/views/assessment/session_results/_gap_outcome.html.erb` (lien vers `#notion-<slug>`)
                     `app/javascript/controllers/assessment/copy_controller.js` · `app/javascript/controllers/assessment/numeric_controller.js` · `app/javascript/controllers/assessment/ordering_controller.js` · `app/javascript/controllers/assessment/matching_controller.js` (une instance par question)
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/assessment/submit_exercise_copy_test.rb` (CA-15, CA-16, CA-17, CA-18, CA-19) · `test/domain/use_cases/assessment/close_exercise_session_test.rb` (CA-21, CA-22) · `test/infrastructure/repositories/assessment/exercise_session_repository_test.rb` (`record_copy`, contrainte `unanswered`) · `test/controllers/assessment/exercises_controller_test.rb` (CA-13 : aucune bonne réponse dans le HTML) · `test/controllers/assessment/exercise_sessions_controller_test.rb` (CA-14) · `test/controllers/assessment/exercise_copies_controller_test.rb` (303, 422, 403, archivé) · `test/system/assessment/exercise_copy_test.rb` (CA-20 : remplir, recharger, rendre ; confirmation des questions vides) · `test/system/assessment/remediation_test.rb` (CA-23, 2e partie : la remédiation ouvre une copie)
- **Done quand**   : un élève, à 390 px, ouvre un exercice de Thalès, lit le sujet et ses questions numérotées, « Faire l'exercice », répond à 4 questions sur 5, recharge et retrouve ses réponses, « Rendre ma copie », confirme, et lit sa note sur 20 avec la question vide marquée « Sans réponse » ; l'exercice de notion raté ouvre « Notion à revoir », celui de toute la leçon non ; captures envoyées au porteur
- **Reprise de la revue du Lot 0** (#332) : la contrainte `unanswered` (une ligne vide acceptée avec `unanswered = true`, refusée avec `false`) a son test dans ce lot.

---

## Lot D — Import `lnclass.course-tree` v2 et contenu Thalès · pilote : Touré

- **Couche**       : domaine + infrastructure + ui (aide de l'import) + contenu
- **Fichiers**     : `config/schemas/lnclass.course-tree.v2.json`
                     `app/domain/entities/catalog/import_kind.rb` (v2 lue, v1 tolérée, type `exercises` retiré)
                     `app/domain/use_cases/catalog/import_course_tree.rb` (`statement`, `exercises[]` de la leçon, règle « 1 par notion + 4 », avertissement v1)
                     `config/initializers/imports.rb` (retrait de `exercises`)
                     `app/domain/use_cases/assessment/import_exercises.rb` · `app/jobs/assessment/import_exercises_job.rb` · `app/views/teams/imports/kinds/_exercises.html.erb` *(supprimés)*
                     `app/views/teams/imports/kinds/_course_tree.html.erb` (aide v2, un exemple de sujet)
                     `docs/contenus/lecons-traitees/3eme/mathematiques/proprietes-de-thales-dans-un-triangle.json` (v2 : 4 exercices de notion, 4 de toute la leçon, chacun avec son sujet ; Fixation ou Évaluation selon le concept, Q11)
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/catalog/import_course_tree_test.rb` (CA-26, CA-27, CA-28) · `test/system/catalog/import_course_tree_test.rb` (rapport d'un refus) · *supprimés* : `test/domain/use_cases/assessment/import_exercises_test.rb`, `test/system/assessment/import_exercises_test.rb`
- **Done quand**   : l'équipe importe le fichier Thalès v2 et le rapport annonce 1 leçon, 4 notions, 8 exercices ; un fichier avec une notion sans exercice est refusé entier, la notion nommée ; un fichier v1 importe la leçon et avertit « exercices ignorés : format v1 » ; Touré a relu les 8 sujets (trace dans `journal.md`)
- **Reprise de la revue du Lot 0** (#332) :
  - `content_tree_writer` recalcule les positions par leçon (`course_positions`) et ignore `node.position`, que `import_exercises.rb:50-51` calcule pour rien : l'import v2 fait respecter l'ordre du fichier (`node.position`) ou retire le calcul, avec un test d'import dans une leçon qui a déjà des exercices sur deux notions ;
  - l'import v2 crée les premiers exercices de toute la leçon : il suppose les jointures du Lot B corrigées ;
  - `EssentialOutsideCourse` (`exercise_repository.rb:101`) n'est rattrapé nulle part : le lot qui laisse un appelant fournir à la fois la leçon et la notion le traduit en erreur `:invalid`, avec son test.

---

## Lot E — Entrées, redirections, lectures et retrait de l'ancien · pilote : Touré

- **Couche**       : delivery + ui + infrastructure (queries) + nettoyage
- **Fichiers**     : `app/controllers/catalog/essentials_controller.rb` (`show` → 301 `#notion-<slug>`) · `app/controllers/catalog/course_sheets_controller.rb` (301 `#fiche-de-revision`) · `app/controllers/classroom/classroom_essentials_controller.rb` (301)
                     `app/controllers/catalog/courses_controller.rb` (lecture des notions par l'élève, ADR §4.3 ; reprise du Lot 0, en vague seule)
                     `app/views/catalog/courses/_course_card.html.erb` · `app/views/classroom/student_classrooms/_pending_gaps.html.erb` · `app/views/classroom/student_homes/next_step/_review.html.erb` · `app/views/classroom/classrooms/_gaps.html.erb` (liens vers `#notion-<slug>`)
                     `app/infrastructure/queries/assessment/classroom_gaps_query.rb` · `app/infrastructure/queries/classroom/student_home_query.rb` (slugs de la leçon et de la notion)
                     `app/views/catalog/courses/_role_actions.html.erb` (plus de « Nouvelle notion » ni de « Nouvel exercice »)
                     `app/controllers/teams/essentials_controller.rb` · `app/controllers/teams/exercises_controller.rb` (retrait de `new`, `create`, `edit`, `update` ; `transition` reste)
                     `config/routes/teams.rb` · `config/routes/assessment.rb` (retrait des routes d'édition et de `exercise_session_attempts` ; reprise du Lot 0, en vague seule)
                     *Supprimés* : `app/views/catalog/essentials/show.html.erb` · `app/views/catalog/courses/_essential_row.html.erb` · `app/views/classroom/classroom_essentials/show.html.erb` · `app/views/teams/essentials/_form.html.erb` · `app/views/teams/essentials/new.html.erb` · `app/views/teams/essentials/edit.html.erb` · `app/views/teams/exercises/_form.html.erb` · `app/views/teams/exercises/new.html.erb` · `app/views/teams/exercises/edit.html.erb` · `app/views/teams/exercises/_question_fields.html.erb` · `app/views/teams/exercises/_answer_fields.html.erb` · `app/views/teams/exercises/_question_image_fields.html.erb` · `app/controllers/assessment/question_attempts_controller.rb` · `app/domain/use_cases/assessment/submit_question_attempt.rb` · `app/views/assessment/exercise_sessions/_question_card.html.erb` · `app/views/assessment/exercise_sessions/_feedback_card.html.erb` · `app/views/assessment/exercise_sessions/_progress_bar.html.erb` · `app/views/assessment/exercise_sessions/_quit_dialog.html.erb` · `app/views/assessment/exercise_sessions/_quit_resume.html.erb` · `app/views/assessment/exercises/_questions_preview.html.erb` · `app/javascript/controllers/assessment/answer_controller.js` · `app/javascript/controllers/assessment/next_question_controller.js` · `app/javascript/controllers/assessment/verdict_controller.js`
                     `config/locales/catalog/essentials.fr.yml` · `config/locales/classroom/classroom_essentials.fr.yml` (supprimés) et clés mortes des autres fichiers de textes (reprise du Lot 0, en vague seule)
- **Dépend de**    : Lot A, Lot B, Lot C, Lot D
- **Test associé** : `test/controllers/catalog/essentials_controller_test.rb` (CA-12, 301) · `test/controllers/catalog/course_sheets_controller_test.rb` (CA-12) · `test/controllers/classroom/classroom_essentials_controller_test.rb` (CA-12) · `test/integration/catalog/course_read_test.rb` (lecture des notions à l'ouverture) · `test/integration/classroom/gaps_link_test.rb` (CA-25) · `test/controllers/teams/essentials_controller_test.rb` · `test/controllers/teams/exercises_controller_test.rb` (CA-29) · `test/integration/assessment/attempts_route_removed_test.rb` (CA-23, 1re partie) · *supprimés* : `test/controllers/assessment/question_attempts_controller_test.rb`, `test/domain/use_cases/assessment/submit_question_attempt_test.rb`, `test/system/catalog/essential_page_test.rb`, `test/system/assessment/exercise_session_test.rb`
- **Done quand**   : aucun lien de l'application ne mène plus à une page de notion (`grep -rn "course_essential_path\|classroom_essential_path\|course_sheet_path" app/views` ne rend rien) ; une ancienne adresse de notion ouvre la leçon sur `#notion-<slug>` ; « Notion à revoir » de l'accueil élève et des lacunes de la classe mène à l'exercice ; `i18n-tasks unused` et `bin/ci-quiet` sont verts

---

## Dispatch

```
Vague 1 : Lot 0                                → 1 agent, séquentiel, fusionné dans feature/refonte-page-lecon
Vague 2 : Lot A ‖ Lot B ‖ Lot C ‖ Lot D        → 4 agents, worktrees isolés
Vague 3 : Lot E                                → 1 agent, après la fusion de A, B, C et D
```

```bash
git switch -c feature/refonte-page-lecon Develop
git worktree add ../lnclass-refonte-page-lecon-lot-a -b feature/refonte-page-lecon-lot-a feature/refonte-page-lecon
```

Un worktree par lot de la vague 2, de même forme (`-lot-b`, `-lot-c`, `-lot-d`). Agents : `executant-lot` (Sonnet) par lot ; `verificateur-ci` (Haiku) pour la preuve.

## Rattachement des critères d'acceptation

| Critère | Lot |
|---|---|
| CA-01 à CA-05, CA-09 | A |
| CA-06, CA-07, CA-08, CA-10, CA-11, CA-24 | B |
| CA-13 à CA-22, CA-23 (copie ouverte par l'exercice du jour et la remédiation) | C |
| CA-26, CA-27, CA-28 | D |
| CA-12, CA-23 (route retirée), CA-25, CA-29 | E |
| CA-30 | 0 |

Aucun critère orphelin.

---

## Vérification de collision

> Deux lots **d'une même vague** ne listent jamais le même fichier.

Partages acceptés, tous **séquentiels** (le second lot démarre après la fusion du premier) :

| Fichier | Lots, dans l'ordre | Pourquoi |
|---|---|---|
| `app/infrastructure/queries/catalog/revision_sheet_query.rb` | Lot 0 (squelette, contrat) → Lot A | le contrôleur et la page du Lot 0 en dépendent |
| `app/infrastructure/queries/catalog/prepare_interros_query.rb` | Lot 0 (squelette, contrat) → Lot B | idem |
| `app/views/catalog/courses/_revision_sheet.html.erb` | Lot 0 (état vide) → Lot A | `show` du Lot 0 le rend |
| `app/views/catalog/courses/_prepare_interros.html.erb` | Lot 0 (état vide) → Lot B | idem |
| `app/controllers/catalog/courses_controller.rb` | Lot 0 → Lot E | la lecture des notions passe ici quand la page de notion disparaît |
| `config/routes/assessment.rb` | Lot 0 (ajout) → Lot E (retrait) | l'ancien écran reste utilisable jusqu'à la fusion du Lot C |
| `config/locales/**` | Lot 0 (ajouts, valeurs) → Lot E (clés mortes) | `i18n-tasks unused` ne passe qu'une fois les vues retirées |

Fichiers partagés, propriétaire unique :

| Fichier | Lot propriétaire |
|---|---|
| `db/schema.rb`, `db/migrate/*` | Lot 0 |
| `app/domain/entities/assessment/exercise.rb` | Lot 0 |
| `app/domain/ports/assessment/*` | Lot 0 |
| `app/infrastructure/repositories/assessment/exercise_repository.rb` | Lot 0 |
| `app/infrastructure/repositories/assessment/exercise_session_repository.rb` | Lot C |
| `test/support/factories/assessment.rb` | Lot 0 |
| `app/views/catalog/courses/show.html.erb` | Lot 0 |
| `config/routes/teams.rb` | Lot E |
| `app/views/layouts/*`, navigation, `test/fixtures/*` | personne (non touchés) |

Contrôle mécanique, **vague 2 seulement** (doit rendre une sortie vide) :

```bash
awk '/^## Lot A/,/^## Lot E/' docs/chantiers/refonte-page-lecon/plan.md \
  | grep -oE '(app|test|config|db|lib|docs/contenus)/[A-Za-z0-9_/.-]+\.(rb|erb|yml|js|json|css)' | sort | uniq -d
```

Résultat au 2026-10-28 : sortie vide.

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

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Pour ce chantier : parcours nominal = un enseignant assigne un exercice de Thalès depuis la page de la leçon, un élève le fait sur téléphone (390 px) et rend sa copie ; chemin d'erreur = rendre avec deux questions vides, puis renvoyer la même copie (une seule note), puis rendre une copie dont le nombre vaut « douze » (422). Il remplit aussi la colonne « Après » des mesures du PRD §7.
