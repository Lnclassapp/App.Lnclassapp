# Plan — Organisation des écrans élève : accueil, « Ma classe » et rythme d'une session

> Graphe de lots au [format gelé](../../guide/conventions.md#6-format-dun-lot). Trois lots verticaux, sur fichiers disjoints, après un Lot 0 court. Exécutés ici l'un après l'autre par la même session (chantier condensé, décision du porteur du 2026-10-05).

```
Lot 0 — SOCLE (ordre des sections, locales partagées, pastille ambre)
  ├─► Lot A « accueil : classe, matières, annonces, à faire, activité »
  ├─► Lot B « Ma classe : cours en carrousel, exercices assignés, exercices traités »
  └─► Lot C « session : la question suivante arrive avec le verdict »
```

### Lot 0 — Socle

- **Couche**      : ui (fichiers partagés)
- **Fichiers**    : app/helpers/navigation_helper.rb
                    app/helpers/components_helper.rb
                    config/locales/shared/navigation.fr.yml
                    test/helpers/navigation_helper_test.rb
- **Dépend de**   : —
- **Test associé**: test/helpers/navigation_helper_test.rb
- **Done quand**  : `home_sections_for(:student)` vaut `classroom, subjects, announcements, todo` ; `ui_subject_bubble signal: :warning` rend une pastille `bg-warning`

### Lot A — Accueil élève

- **Couche**      : infrastructure + ui
- **Fichiers**    : app/infrastructure/queries/classroom/student_home_query.rb
                    app/views/classroom/student_homes/show.html.erb
                    app/views/classroom/student_homes/_subjects.html.erb
                    config/locales/classroom/student_homes.fr.yml
                    test/infrastructure/queries/classroom/student_home_query_test.rb
                    test/controllers/classroom/student_homes_controller_test.rb
- **Dépend de**   : Lot 0
- **Test associé**: test/controllers/classroom/student_homes_controller_test.rb (CA-1, CA-2, CA-3, CA-8), test/infrastructure/queries/classroom/student_home_query_test.rb
- **Done quand**  : l'accueil se lit classe, matières, annonces, à faire, activité ; les bulles mènent au catalogue filtré ; la pastille ambre suit le retard

### Lot B — « Ma classe »

- **Couche**      : infrastructure + ui
- **Fichiers**    : app/infrastructure/queries/classroom/student_classroom_query.rb
                    app/views/classroom/student_classrooms/show.html.erb
                    app/views/classroom/student_classrooms/_course_card.html.erb
                    app/views/classroom/student_classrooms/_assigned_exercise.html.erb
                    app/views/classroom/student_classrooms/_treated_exercise.html.erb
                    config/locales/classroom/student_classrooms.fr.yml
                    test/infrastructure/queries/classroom/student_classroom_query_test.rb
                    test/controllers/classroom/student_classrooms_controller_test.rb
                    test/system/classroom/student_classroom_test.rb
- **Dépend de**   : Lot 0 (et la méthode publique `StudentHomeQuery#assigned_exercises` du Lot A)
- **Test associé**: test/controllers/classroom/student_classrooms_controller_test.rb (CA-4, CA-5, CA-6, CA-8), test/infrastructure/queries/classroom/student_classroom_query_test.rb
- **Done quand**  : la bande des cours, puis 3 exercices assignés et 3 traités avec « Voir plus », en un nombre fixe de requêtes

### Lot C — Session

- **Couche**      : ui (+ front)
- **Fichiers**    : app/views/assessment/question_attempts/create.turbo_stream.erb
                    app/views/assessment/exercise_sessions/_feedback_card.html.erb
                    app/javascript/controllers/assessment/next_question_controller.js
                    test/controllers/assessment/question_attempts_controller_test.rb
                    test/system/assessment/exercise_session_test.rb
- **Dépend de**   : Lot 0
- **Test associé**: test/controllers/assessment/question_attempts_controller_test.rb (CA-7, CA-8), test/system/assessment/exercise_session_test.rb (aucune requête au clic sur « Question suivante »)
- **Done quand**  : une question coûte un aller-retour ; sans JavaScript le lien marche ; aucune proposition correcte dans le stream

## Vérification de collision

| Fichier | Lot 0 | A | B | C |
|---|:-:|:-:|:-:|:-:|
| app/helpers/navigation_helper.rb | ✔ | | | |
| app/helpers/components_helper.rb | ✔ | | | |
| config/locales/shared/navigation.fr.yml | ✔ | | | |
| app/infrastructure/queries/classroom/student_home_query.rb | | ✔ | (lu) | |
| app/infrastructure/queries/classroom/student_classroom_query.rb | | | ✔ | |
| app/views/classroom/student_homes/* | | ✔ | | |
| app/views/classroom/student_classrooms/* | | | ✔ | |
| app/views/assessment/* | | | | ✔ |
| app/javascript/controllers/assessment/next_question_controller.js | | | | ✔ |

Le Lot B lit `StudentHomeQuery#assigned_exercises` sans la modifier : la méthode est rendue publique par le Lot A, qui part donc avant B.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît — sans objet (PRD §6)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md` (UDR-0076)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [x] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [x] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)
