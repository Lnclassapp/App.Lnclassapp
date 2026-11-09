# Plan d'exécution — Bronze pour tout exercice traité

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot). Aucune migration, aucun port nouveau, aucune locale : le Lot 0 ne touche que le domaine.

## Graphe

```
Lot 0 — Règle de clôture et de classe (séquentiel, domaine)
  ↓
  ├─► Lot A  Résultat de session (Bronze sans fête, Pas encore)  ┐
  ├─► Lot B  Lectures enseignant d'un exercice (compréhension)   ├─ en parallèle
  └─► Lot C  Lectures de classe (liste, fiche élève, accueil)    ┘
```

Vague 1 : Lot 0 (1 agent). Vague 2 : Lots A, B, C (3 agents, worktrees isolés). Une seule PR vers `Develop`, dans la journée.

---

## Lot 0 — Règle de clôture et de classe

- **Couche**       : domaine
- **Fichiers**     : `app/domain/entities/assessment/grading.rb`
                     `app/domain/entities/assessment/question_attempt.rb`
                     `app/infrastructure/repositories/assessment/exercise_session_repository.rb`
                     `app/domain/use_cases/assessment/close_exercise_session.rb`
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/assessment/grading_test.rb`
                     `test/domain/use_cases/assessment/close_exercise_session_test.rb`
                     `test/infrastructure/repositories/assessment/exercise_session_repository_test.rb`
- **Done quand**   : l'entité de la tentative porte `unanswered` (défaut faux) et le repository le remonte ; une copie à 20 % avec au moins une réponse enregistre Bronze ; une copie sans réponse n'enregistre rien ; la médaille de classe d'un élève ayant une médaille vaut au moins Bronze ; les paliers au-dessus de Bronze sont inchangés

## Lot A — Résultat de session

- **Couche**       : infrastructure + ui
- **Fichiers**     : `app/infrastructure/queries/assessment/session_result_query.rb`
                     `app/views/assessment/session_results/_badge.html.erb`
                     `app/views/assessment/session_results/show.html.erb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/assessment/session_result_query_test.rb`
                     `test/controllers/assessment/session_results_controller_test.rb`
- **Done quand**   : à 20 % avec réponses, le résultat montre Bronze sans « Nouvelle médaille ! » ; à 50 %, avec ; copie vide, « Pas encore »

## Lot B — Lectures enseignant d'un exercice

- **Couche**       : infrastructure
- **Fichiers**     : `app/infrastructure/queries/assessment/comprehension_detail_query.rb`
                     `app/infrastructure/queries/assessment/comprehension_summary_query.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/assessment/comprehension_detail_query_test.rb`
                     `test/infrastructure/queries/assessment/comprehension_summary_query_test.rb`
- **Done quand**   : le rapport d'un exercice range un élève à 20 % avec médaille Bronze dans la case Bronze, jamais « Pas encore »

## Lot C — Lectures de classe

- **Couche**       : infrastructure
- **Fichiers**     : `app/infrastructure/queries/classroom/classroom_overview_query.rb`
                     `app/infrastructure/queries/classroom/teacher_home_query.rb`
                     `app/infrastructure/queries/classroom/student_file_query.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/classroom/classroom_overview_query_test.rb`
                     `test/infrastructure/queries/classroom/teacher_home_query_test.rb`
                     `test/infrastructure/queries/classroom/student_file_query_test.rb`
- **Done quand**   : l'élève à 30 % de moyenne avec une médaille Bronze est Bronze dans la liste, la fiche et l'accueil

---

## Décisions ouvertes

Aucune : toutes tranchées au grill (voir `memo.md`). Réversible, appliqué : les sessions anciennes sous 48 % se lisent « Pas encore ».

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `app/domain/entities/assessment/grading.rb` | Lot 0 |
| `app/domain/entities/assessment/question_attempt.rb` | Lot 0 |
| `app/infrastructure/repositories/assessment/exercise_session_repository.rb` | Lot 0 |
| `app/domain/use_cases/assessment/close_exercise_session.rb` | Lot 0 |
| `app/infrastructure/queries/assessment/session_result_query.rb` | Lot A |
| `app/views/assessment/session_results/_badge.html.erb` | Lot A |
| `app/views/assessment/session_results/show.html.erb` | Lot A |
| `app/infrastructure/queries/assessment/comprehension_detail_query.rb` | Lot B |
| `app/infrastructure/queries/assessment/comprehension_summary_query.rb` | Lot B |
| `app/infrastructure/queries/classroom/classroom_overview_query.rb` | Lot C |
| `app/infrastructure/queries/classroom/teacher_home_query.rb` | Lot C |
| `app/infrastructure/queries/classroom/student_file_query.rb` | Lot C |

`config/routes.rb`, locales, layouts, fixtures : non touchés.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : 5 lignes dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit (`XXXX-medailles-lues-a-la-cloture`, changement de source de lecture)
- [x] UDR écrite pour la vue modifiée (`XXXX-bronze-sans-fete-sous-48`)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR

**Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Ici : une copie à 20 % avec réponses (Bronze sans fête) et une copie vide (« Pas encore »).

## Critères d'acceptation → lots

Bronze sous 48 % : Lot 0 · copie vide : Lot 0 et A · pas de fête / fête à 48 % : Lot A · paliers inchangés : Lot 0 · lecture de la médaille enregistrée : Lots B et C · pas de rattrapage : Lot 0 (aucune migration) · médaille de classe : Lots 0 et C.
