# Memo — Requêtes de lecture appelant des modèles ORM disparus (ADR-0007 non propagé)

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré — fermé le 2026-09-24 |
| **Ouvert le** | 2026-09-18 · repris le 2026-09-24 |
| **Branche** | `fix/queries-constantes-orm-disparues` |
| **Gravité** | 🔴 Bloquant — flux enseignant (et flux élève) inaccessibles |
| **Dépend de** | [`classroom-assignment-belongs-to-casses`](../classroom-assignment-belongs-to-casses/memo.md) — **doit être livré avant** |

---

## Symptôme

Un enseignant qui a au moins une classe ouvre `http://localhost:3000/teachers`. Il obtient une page d'erreur Rails au lieu de son flux :

```
NameError in Teachers::FeedController#index
uninitialized constant Orm::ClassroomEssential
app/infrastructure/queries/teachers_feed_query.rb:49
```

## Reproduction

| | |
|---|---|
| **Acteur** | Teacher avec au moins une ligne `teacher_classrooms` |
| **Données** | dev : `teacher_id: 1`, `classroom_id: 79` |
| **Environnement** | development, `bin/dev` |

1. Se connecter comme enseignant rattaché à au moins une classe.
2. Aller sur `/teachers`.
3. → `NameError: uninitialized constant Orm::ClassroomEssential`.

Reproduit par l'utilisateur dans le navigateur (capture du 2026-09-24 17:10) et à nouveau par `bin/rails runner` le 2026-09-24 :
`Queries::TeachersFeedQuery.new(teacher_id: 1).get_recent_essentials_in_classrooms([79])` → `NameError`.

## Portée

| | |
|---|---|
| **Depuis quand** | commit `0991bd3` (2026-08-29) : suppression des modèles `Orm::ClassroomCourse/Essential/Exercise` au profit de `Orm::ClassroomAssignment` (ADR-0007), sans mettre à jour la couche lecture |
| **Acteurs touchés** | **tous les enseignants ayant une classe** (flux) · **tous les élèves ayant une classe** (flux, même cause) · enseignant sur la page de résultats d'un exercice |
| **Données corrompues** | **Non.** Chemins en lecture seule, rien n'est écrit. Aucune réparation. |

## Périmètre — les 4 appels hérités d'avant l'ADR-0007

| Fichier | Ligne | Appel mort | Remplacement attendu |
|---|---|---|---|
| `app/infrastructure/queries/teachers_feed_query.rb` | 49, 53 | `Orm::ClassroomEssential`, `order("classroom_essentials.created_at")` | `Orm::ClassroomAssignment.active.where(resource_type: "Orm::Essential")` |
| `app/infrastructure/queries/student_feed_query.rb` | 23-24 | `joins(courses: :classroom_courses)` — association absente de `Orm::Course` | jointure via `classroom_assignments` |
| `app/infrastructure/queries/student_feed_query.rb` | 30 | `Orm::ClassroomExercise` | `Orm::ClassroomAssignment.active.where(resource_type: "Orm::Exercise")` |
| `app/controllers/teachers/classroom_exercises_controller.rb` | 76 | `Orm::ClassroomExercise.find_by(...)` | idem, ou suppression si aucune vue ne lit `@classroom_exercise` |

Plus : l'en-tête HITL de `classroom_assignment_repository.rb:9` cite les modèles disparus.

**Ajouté le 2026-09-24 à la demande de l'utilisateur** : `app/controllers/classroom/teachers/classrooms_controller.rb:52` (`index_by(&:essential_id)`) et `:60-62` (`where(exercise_id:)`), même cause.

**Ajouté le 2026-09-24 après le challenger** : `app/controllers/classroom/classroom_essentials_controller.rb:25` (`where(exercise_id:)`), même cause, manqué par le premier balayage.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quelle source dit le comportement attendu ? | ADR-0007 (table polymorphe unique), ADR-0016 (soft delete `archived`), ADR-0006 (feed en CQRS) | Pas une feature : bugfix confirmé |
| Depuis quand ? | `0991bd3`, 2026-08-29 | Pas de donnée écrite entre-temps |
| Multi-appartenance ? | La query reçoit une **liste** de `classroom_ids` | Le test couvre un enseignant avec 2 classes dans 2 écoles |
| Autres acteurs sur le même chemin ? | Student (même cause, `StudentFeedQuery`). `schoolstaff/feed/content/_activities.html.erb` lit `@essentials_in_classrooms` mais son contrôleur ne l'affecte pas → vue morte, hors périmètre | Student inclus ; SchoolStaff → journal |
| Données à réparer ? | Non | Pas de Lot A |
| Chemins vivants ou morts ? | **Vivants** : `/teachers` (constaté), `/students`, résultats d'exercice enseignant | On corrige, on ne supprime pas |
| Les vues tiennent-elles après le correctif ? | **Non tant que belongs-to-casses n'est pas livré** : `_activities.html.erb:112` appelle `ce.essential`, qui lève `PG::UndefinedTable` dès qu'une assignation existe | Dépendance dure : belongs-to-casses d'abord (choix utilisateur du 2026-09-24) |

## Cas limites identifiés

- Le domaine manipule le type **nu** (`"Exercise"`), SQL stocke le type **préfixé** (`"Orm::Exercise"`). Dans une query, on écrit `"Orm::…"`.
- `Orm::Classroom` expose déjà `classroom_courses`, `classroom_essentials` et `classroom_exercises` (`classroom.rb:36-38`) : on les réutilise.
- ADR-0016 : toute lecture exclut `status: "archived"` → scope `.active`.
- `teachers/classroom_exercises_controller.rb:75` dit « on garde l'objet optionnel pour compatibilité vues » : vérifier ce que la vue lit avant de supprimer.
- En base vide, tout ce qui est préchargé renvoie `[]` : le test **doit** créer au moins une assignation, sinon il passe au vert à tort.

## Hors périmètre → chantiers de suivi (voir `journal.md`)

- Boucle de redirection infinie élève sans classe (`/` ↔ `/students`).
- Boucle de redirection infinie enseignant sans école (`/` ↔ `/teachers/classrooms`).
- `@teacher_classrooms` n'est affecté nulle part → bouton d'assignation mort (`catalog/courses/show.html.erb:68`).
- Vue morte `schoolstaff/feed/content/_activities.html.erb`.
- Les `belongs_to` scopés → chantier `classroom-assignment-belongs-to-casses` (prérequis).

## Contrat d'exécution — un seul lot

Pas de `plan.md` : un lot, aucun fichier partagé, aucune migration.

1. **Tests de reproduction d'abord**, au niveau infrastructure :
   - `test/infrastructure/queries/teachers_feed_query_test.rb` : enseignant avec 2 classes dans 2 écoles, une fiche assignée active et une archivée → la query renvoie la fiche active uniquement.
   - `test/infrastructure/queries/student_feed_query_test.rb` : `get_classroom_materials` et `get_classroom_exercises` avec au moins une assignation.
   - `classroom_exercises_controller.rb:76` : test contrôleur (`test/controllers/teachers/`), la page de résultats d'un exercice répond 200.
2. **Les lancer, les voir rouges pour la bonne raison** : `NameError … Orm::ClassroomEssential` / `ClassroomExercise`, et `ConfigurationError … classroom_courses`.
3. Corriger dans `app/infrastructure/queries/` et le contrôleur, **pas dans les vues**.
4. Relancer : vert.
5. Relancer `bin/rails test test/infrastructure test/controllers test/domain` : rien d'autre n'a bougé.

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Prérequis `classroom-assignment-belongs-to-casses` livré
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [x] Test au vert · suite du contexte borné au vert
- [x] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : réparées, ou dette explicitement notée au journal *(aucune donnée corrompue)*
- [x] Challenger a rejoué les étapes de reproduction dans l'application
- [x] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés
