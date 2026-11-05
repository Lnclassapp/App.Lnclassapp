# Plan d'exécution — Suivi de la classe sur une leçon : lacunes, réussite par exercice, remédiation

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> PRD : [`prd.md`](prd.md) · ADR-XXXX-lecture-de-la-classe-par-la-direction · UDR-XXXX-suivi-de-la-classe-sur-une-lecon

## Graphe

```
Lot 0 — SOCLE (séquentiel) : policy de lecture de la leçon en classe, contrôleurs ouverts à la direction,
        emplacements dans la fiche de révision, toutes les locales
  ↓
  ├─► Lot A  lacunes par notion (enseignant, équipe, direction)   ┐
  ├─► Lot B  réussite de la classe par exercice                    │
  ├─► Lot C  remédiation proposée à l'élève (3 endroits)           ├─ en parallèle
  ├─► Lot D  « Fiches à revoir » et jours de séance (pages classe) │
  ├─► Lot E  l'équipe assigne depuis une feuille vue en classe     │
  └─► Lot F  dette : code sans appelant, route d'images de question┘
```

Vague 1 : Lot 0 → 1 agent, séquentiel.
Vague 2 : Lots A ‖ B ‖ C ‖ D ‖ E ‖ F → 6 agents, worktrees isolés (`feature/suivi-classe-lecon-lot-<x>` depuis `feature/suivi-classe-lecon`, Lot 0 mergé).

**Le Lot 0 gèle les contrats** (`ReadClassroomLessonPolicy::Access`, locaux `class_gaps:` et `proposals:` de `catalog/revision_sheets/_sheet`, local `success:` et `can_assign:` de `_teacher_bar`). Un lot qui doit les changer s'arrête : le Lot 0 rouvre.

---

## Lot 0 — Socle

- **Couche**      : domaine + delivery + ui (emplacements) + locales
- **Fichiers**    : app/domain/policies/classroom/read_classroom_lesson_policy.rb
                    app/controllers/classroom/classroom_courses_controller.rb
                    app/controllers/classroom/classroom_prepare_sheets_controller.rb
                    app/views/classroom/classroom_courses/show.html.erb
                    app/views/classroom/classroom_prepare_sheets/show.html.erb
                    app/views/catalog/revision_sheets/_sheet.html.erb
                    app/views/catalog/courses/_revision_sheet.html.erb
                    app/views/catalog/courses/sheets/_teacher_bar.html.erb
                    config/locales/classroom/classroom_courses.fr.yml
                    config/locales/classroom/classrooms.fr.yml
                    config/locales/classroom/student_classrooms.fr.yml
                    config/locales/catalog/courses.fr.yml
                    config/locales/catalog/revision_sheets.fr.yml
                    config/locales/assessment/session_results.fr.yml
                    config/locales/school_admin/*.fr.yml (le fichier de `school_admin/classrooms`, s'il porte des clés)
                    test/domain/policies/classroom/read_classroom_lesson_policy_test.rb
                    test/controllers/classroom/classroom_courses_controller_test.rb
- **Dépend de**   : —
- **Test associé**: test/domain/policies/classroom/read_classroom_lesson_policy_test.rb · test/controllers/classroom/classroom_courses_controller_test.rb (CA-13, CA-14)
- **Done quand**  : une direction du même établissement ouvre la leçon et une feuille dans une classe (200, aucune barre « Assigner ») ; une direction d'un autre établissement reçoit 404 ; enseignant et équipe inchangés. `_sheet` rend `classroom/classroom_courses/_notion_gaps` quand `class_gaps[slug]` existe et `catalog/revision_sheets/_todo` quand `proposals[slug]` existe (partiels livrés par A et C ; tant qu'ils n'existent pas, les locaux valent `nil` partout) ; `_teacher_bar` ne rend « Choisir » et les bascules que si `can_assign`, et rend `catalog/courses/sheets/_success` quand `success` est fourni. Toutes les clés de l'UDR sont dans les locales.

## Lot A — L'enseignant voit qui est à revoir et qui a levé sa lacune, sous chaque notion

- **Couche**      : infrastructure + delivery + ui
- **Fichiers**    : app/infrastructure/queries/assessment/classroom_gaps_query.rb (`details_for_course` : toutes les notions de la leçon, une requête)
                    app/views/classroom/classroom_courses/_notion_gaps.html.erb
                    test/infrastructure/queries/assessment/classroom_gaps_query_test.rb
                    test/integration/classroom/notion_gaps_in_lesson_test.rb
- **Dépend de**   : Lot 0
- **Test associé**: test/infrastructure/queries/assessment/classroom_gaps_query_test.rb (CA-2, CA-3) · test/integration/classroom/notion_gaps_in_lesson_test.rb (CA-1, CA-4, CA-12 côté encadré)
- **Done quand**  : sur la leçon vue depuis la classe, la notion « Thalès » montre « À revoir (1) » avec Awa et « Lacune levée (1) » avec Koffi ; une notion sans lacune n'a pas d'encadré ; la direction du même établissement voit l'encadré.
- **Note**        : le chargement de `@class_gaps` dans `ClassroomCoursesController` est posé au Lot 0 (`nil` en attendant) ; ce lot ne touche pas le contrôleur : la query est appelée par la ligne laissée par le Lot 0 (`Queries::Assessment::ClassroomGapsQuery.new.details_for_course(...)`, signature gelée au Lot 0, méthode écrite ici).

## Lot B — La réussite de la classe sous chaque exercice d'une feuille

- **Couche**      : domaine + infrastructure + ui
- **Fichiers**    : app/domain/entities/assessment/class_success.rb
                    app/infrastructure/queries/assessment/class_exercise_success_query.rb
                    app/views/catalog/courses/sheets/_success.html.erb
                    app/assets/stylesheets/prepare_sheet.css
                    test/domain/entities/assessment/class_success_test.rb
                    test/infrastructure/queries/assessment/class_exercise_success_query_test.rb
                    test/controllers/classroom/classroom_prepare_sheets_controller_test.rb
- **Dépend de**   : Lot 0
- **Test associé**: test/domain/entities/assessment/class_success_test.rb · test/infrastructure/queries/assessment/class_exercise_success_query_test.rb (CA-5, CA-6) · test/controllers/classroom/classroom_prepare_sheets_controller_test.rb
- **Done quand**  : sous un exercice d'une feuille vue depuis la classe, l'enseignant lit « 1 / 3 élèves ont réussi » (meilleure copie par élève, seuil de réussite actuel) ; sans copie, « Pas encore fait par la classe » ; une requête pour toute la feuille.
- **Note**        : comme pour A, l'appel de la query dans `ClassroomPrepareSheetsController` est posé au Lot 0 (signature gelée : `call(classroom_public_id:, exercise_ids:)` → Hash `exercise_id → ClassSuccess`).

## Lot C — L'élève se voit proposer un exercice pour lever sa lacune, à trois endroits

- **Couche**      : infrastructure + delivery + ui
- **Fichiers**    : app/infrastructure/queries/assessment/remediation_proposals_query.rb (lacunes en attente de l'élève → exercice proposé par `Entities::Assessment::RemediationPick`, une requête)
                    app/controllers/catalog/courses_controller.rb
                    app/controllers/classroom/student_classrooms_controller.rb
                    app/controllers/assessment/session_results_controller.rb
                    app/views/catalog/revision_sheets/_todo.html.erb
                    app/views/classroom/student_classrooms/_pending_gaps.html.erb
                    app/views/assessment/session_results/_gap_outcome.html.erb
                    app/assets/stylesheets/course_sheet.css
                    test/infrastructure/queries/assessment/remediation_proposals_query_test.rb
                    test/integration/assessment/remediation_proposal_test.rb
- **Dépend de**   : Lot 0
- **Test associé**: test/infrastructure/queries/assessment/remediation_proposals_query_test.rb (CA-7, CA-9, CA-10) · test/integration/assessment/remediation_proposal_test.rb (CA-8, CA-11)
- **Done quand**  : Awa, qui a raté E1, voit le même exercice E3 proposé sur sa page de résultat, sous la notion de la leçon et dans « Fiches à revoir » ; la réussite de E3 lève la lacune et les trois propositions disparaissent.

## Lot D — « Fiches à revoir » chez la direction, et « Jours de séance » de retour sur la page de la classe

- **Couche**      : delivery + ui
- **Fichiers**    : app/controllers/school_admin/classrooms_controller.rb
                    app/views/school_admin/classrooms/show.html.erb
                    app/controllers/classroom/classrooms_controller.rb
                    app/views/classroom/classrooms/show.html.erb
                    test/controllers/school_admin/classrooms_controller_test.rb
                    test/controllers/classroom/classrooms_controller_test.rb
- **Dépend de**   : Lot 0
- **Test associé**: test/controllers/school_admin/classrooms_controller_test.rb (CA-12, entrée) · test/controllers/classroom/classrooms_controller_test.rb (CA-15)
- **Done quand**  : la direction voit « Fiches à revoir » sur sa page d'une classe et la ligne ouvre la leçon dans la classe ; l'enseignant lit « Vos jours de séance : lundi, jeudi » et « Modifier les jours » ouvre la fenêtre des jours.

## Lot E — L'équipe assigne depuis une feuille vue dans une classe

- **Couche**      : infrastructure + ui
- **Fichiers**    : app/infrastructure/queries/catalog/prepare_sheets_query.rb (cible de la classe courante pour l'équipe)
                    test/infrastructure/queries/catalog/prepare_sheets_query_test.rb
                    test/integration/classroom/team_assigns_from_sheet_test.rb
- **Dépend de**   : Lot 0
- **Test associé**: test/integration/classroom/team_assigns_from_sheet_test.rb (CA-16)
- **Done quand**  : un membre de l'équipe ouvre une feuille depuis « 3e 2 », voit « Assigner à 3e 2 » sous chaque exercice, et l'assignation crée le devoir ; hors classe, toujours pas de barre.

## Lot F — Retirer la dette de la refonte (comportement identique)

- **Couche**      : domaine + delivery (suppressions)
- **Fichiers**    : app/domain/use_cases/assessment/create_exercise.rb (supprimé)
                    app/domain/use_cases/assessment/update_exercise.rb (supprimé)
                    app/domain/dtos/assessment/exercise_input.rb (supprimé)
                    app/infrastructure/queries/classroom/classroom_overview_query.rb (`shown_course?` retiré)
                    app/controllers/teams/question_images_controller.rb (supprimé)
                    config/routes/teams.rb (route `question-images` retirée)
                    test/domain/use_cases/assessment/create_exercise_test.rb (supprimé)
                    test/domain/use_cases/assessment/update_exercise_test.rb (supprimé)
                    test/domain/dtos/assessment/exercise_input_test.rb (supprimé)
                    test/controllers/teams/question_images_controller_test.rb (supprimé)
                    test/integration/teams/question_images_gone_test.rb
- **Dépend de**   : Lot 0
- **Test associé**: test/integration/teams/question_images_gone_test.rb (CA-17)
- **Done quand**  : `POST /team/question-images` répond 404 ; aucune référence aux éléments retirés (`grep` vide) ; les tests des fichiers touchés passent. Les éléments encore utilisés ne sont pas retirés (`with_essentials`, `ClassroomGapsQuery#detail` réutilisée par A, `Assessment::QuestionImagesController` de l'élève).

---

## Décisions ouvertes

- [x] Où la direction voit-elle le détail ? → leçon en classe en lecture seule, entrée par « Fiches à revoir » de sa page de classe (memo, réversible).
- [x] Emplacement de la réussite par exercice → sous chaque exercice de la feuille vue en classe (UDR §3.2, réversible).
- Aucune autre décision ouverte : le grill a tranché acteurs, règle de réussite, emplacements et périmètre de la dette.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `app/controllers/classroom/classroom_courses_controller.rb` | Lot 0 |
| `app/controllers/classroom/classroom_prepare_sheets_controller.rb` | Lot 0 |
| `app/views/catalog/revision_sheets/_sheet.html.erb` | Lot 0 |
| `app/views/catalog/courses/sheets/_teacher_bar.html.erb` | Lot 0 |
| `app/views/classroom/classroom_prepare_sheets/show.html.erb` | Lot 0 |
| `config/locales/**` (toutes les clés du chantier) | Lot 0 |
| `test/controllers/classroom/classroom_courses_controller_test.rb` | Lot 0 |
| `test/controllers/classroom/classroom_prepare_sheets_controller_test.rb` | Lot B |
| `app/infrastructure/queries/assessment/classroom_gaps_query.rb` | Lot A |
| `app/assets/stylesheets/prepare_sheet.css` | Lot B |
| `app/assets/stylesheets/course_sheet.css` | Lot C |
| `app/infrastructure/queries/catalog/prepare_sheets_query.rb` | Lot E |
| `config/routes/teams.rb` | Lot F |

Contrôle mécanique : aucun doublon entre lots parallèles (A à F) ; les fichiers en double l'étaient avec le Lot 0 et y sont restés.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Pour ce chantier : il joue le parcours enseignant (CA-1, CA-5), le parcours élève (CA-8 : les trois endroits proposent le même exercice), et le chemin d'erreur direction d'un autre établissement (CA-13, 404). Captures à 390 px et sur ordinateur, envoyées au porteur, jamais commitées.

Revue obligatoire : `security-reviewer` (policy et deux contrôleurs ouverts à la direction), `silent-failure-hunter` (queries), `pr-test-analyzer` (17 critères).
