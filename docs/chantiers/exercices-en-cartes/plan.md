# Plan d'exécution — Les exercices en cartes

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — carte d'exercice et cartes de question (un seul lot, vertical : lecture → helper → vues)
```

Un seul lot : la carte, son helper et ses quatre branchements partagent le partial et la locale ; les découper en lots parallèles mettrait le même fichier dans deux lots. Pas de Lot 0 : aucun port, aucune table, aucune route.

---

## Lot A — Les exercices et les questions en cartes

- **Couche**       : infrastructure (lecture) + ui
- **Fichiers**     : `app/infrastructure/queries/classroom/student_home_query.rb` (ExerciseRow : `exercise_type`)
                     `app/infrastructure/queries/classroom/student_classroom_query.rb` (TreatedRow : `exercise_type`)
                     `app/infrastructure/queries/classroom/classroom_overview_query.rb` (AssignmentRow : `exercise_type`)
                     `app/infrastructure/queries/catalog/prepare_interros_query.rb` (Prepare : `material_slug`)
                     `app/helpers/assessment/exercise_cards_helper.rb` *(nouveau)*
                     `app/views/assessment/exercises/_card.html.erb` *(nouveau)*
                     `app/views/assessment/exercises/show.html.erb`
                     `app/views/assessment/exercises/sheet_kinds/_choice.html.erb`
                     `app/views/classroom/student_classrooms/_assigned_exercise.html.erb`, `_treated_exercise.html.erb`, `show.html.erb`
                     `app/views/classroom/classrooms/_assigned_exercises.html.erb`
                     `app/views/catalog/courses/_exercise_row.html.erb`, `_prepare_interros.html.erb` *(branchement seul)*
                     `config/locales/assessment/exercise_cards.fr.yml` *(nouveau)*
                     tests : `test/helpers/assessment/exercise_cards_helper_test.rb` *(nouveau)*, `test/system/assessment/exercise_cards_test.rb` *(nouveau)*, tests existants ajustés
- **Dépend de**    : —
- **Test associé** : `test/helpers/assessment/exercise_cards_helper_test.rb` (CA-1 à CA-7 par source) · `test/controllers/assessment/exercises_controller_test.rb` (CA-8) · `test/system/assessment/exercise_cards_test.rb` (CA-1, CA-3, CA-8 au navigateur)
- **Done quand**   : dans l'application, « Ma classe » de l'élève, la page d'une leçon et la classe de l'enseignant montrent des cartes d'exercice conformes à l'UDR §3.1, et l'écran d'un exercice montre une carte par question avec son format (UDR §3.3)

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/locales/assessment/exercise_cards.fr.yml` | Lot A |
| `catalog/courses/_prepare_interros.html.erb` | Lot A — branchement seul ; frontière avec la session parallèle « parcours matière → leçon → exercice » |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture) — sans objet
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle — sans objet
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert *(rubocop et tests du lot verts ; bin/ci-quiet et brakeman : vérificateur)*
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
