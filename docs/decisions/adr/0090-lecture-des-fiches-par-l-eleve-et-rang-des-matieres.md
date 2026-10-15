# ADR-0090 : Une ligne par fiche ouverte par l'élève (`essential_reads`), et un rang pour chaque matière (`materials.position`)
<!-- index
titre: Lecture des fiches par l'élève et rang des matières
statut: Accepté
problematique: Savoir, par élève et par cours, s'il a commencé, tout lu, et quelle fiche il a ouverte en dernier ; ranger les matières dans l'ordre du programme au même endroit pour tous les écrans
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-15 |
| **Chantier** | [`docs/chantiers/cours-eleve`](../../chantiers/cours-eleve/memo.md) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

La page « Cours » de l'élève est redessinée (memo `cours-eleve`, 2026-10-15). Deux décisions du porteur demandent des données qui n'existent pas.

1. **Le bouton de la carte dit où en est l'élève** :
   - « Commencer le cours » s'il n'a ouvert aucune fiche ;
   - « Reprendre le cours » s'il en a ouvert au moins une, et ce bouton rouvre la dernière fiche ouverte ;
   - « Revoir le cours » s'il les a toutes ouvertes.

   Aujourd'hui, rien n'enregistre qu'un élève a ouvert une fiche. Le schéma n'a ni `essential_reads`, ni « dernière fiche », ni progression de cours. Seules les sessions d'exercice sont suivies.
2. **Les matières suivent l'ordre du programme** (Mathématiques, Physique-Chimie, SVT, Français, Histoire-Géographie, EDHC, Philosophie), le même que « Mes matières » sur l'accueil.
   - Cet ordre vit aujourd'hui dans une constante de slugs, `SUBJECT_ORDER`, propre à `StudentHomeQuery`. ADR-0089 la réutilise pour le tour de l'exercice du jour.
   - Le catalogue trie par `materials.name`.
   - La table `materials` n'a pas de rang.

## 2. Moteurs de décision

- Une seule source pour l'ordre des matières, lisible en SQL (tri, pagination).
- Une écriture par ouverture de fiche, idempotente, sans ralentir la page de la fiche.
- Données d'apprentissage d'un mineur : elles sont effacées avec les autres à l'anonymisation (ADR-0036).
- Ne rien enregistrer pour l'enseignant, la direction ou l'équipe.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Table `course_progresses` (élève, cours, dernière fiche, `completed_at`) | Une ligne par cours, lecture directe | « Tout lu » devient faux dès qu'une fiche est publiée ou dépubliée ; il faudrait recalculer à chaque publication |
| B — Table `essential_reads` (élève, fiche, première et dernière ouverture) | « Commencé », « tout lu » et « dernière fiche » se déduisent à la lecture et restent justes quand le cours change | Retenue |
| C — Déduire la lecture des sessions d'exercice de la fiche | Aucune table | Un élève peut lire une fiche sans faire d'exercice ; « Reprendre » mentirait |
| D — Garder `SUBJECT_ORDER` et l'appliquer au catalogue par un `CASE` SQL | Pas de migration | Deux copies de l'ordre à tenir à jour ; une matière ajoutée par l'import ne peut pas être rangée sans déploiement |
| E — Colonne `materials.position` | Une source, triable, en base (un écran pourra la régler sans déploiement) | Retenue |

## 4. Décision

> **Nous enregistrons chaque fiche ouverte par un élève dans `essential_reads` (une ligne par élève et par fiche), et nous rangeons les matières par `materials.position`, qui remplace `SUBJECT_ORDER`.**

### 4.1 `essential_reads`

| Colonne | Type | Règle |
|---|---|---|
| `student_id` | bigint, FK `users`, `on_delete: restrict` | non nul |
| `essential_id` | bigint, FK `essentials`, `on_delete: cascade` | non nul |
| `first_read_at` | datetime | non nul, posé à la première ouverture |
| `last_read_at` | datetime | non nul, mis à jour à chaque ouverture |

- **Index** :
  - unique sur (`student_id`, `essential_id`) ;
  - sur (`student_id`, `last_read_at`) pour « dernière fiche ».
- **Écriture** :
  - **use case** : `UseCases::Assessment::RecordEssentialRead`, contexte `assessment` comme les autres données d'apprentissage ;
  - **port** : `Ports::Assessment::EssentialReadRepositoryPort#record(student_id:, essential_id:, at:)` ;
  - **upsert** : `INSERT … ON CONFLICT (student_id, essential_id) DO UPDATE SET last_read_at = excluded.last_read_at` ;
  - **appelants** : `Catalog::EssentialsController#show` et `Classroom::ClassroomEssentialsController#show`, après la policy de lecture, seulement si `current_actor.student?`. L'échec d'écriture est journalisé, il n'empêche pas d'afficher la fiche.
- **Lecture**, dans `CourseCatalogQuery`, pour l'élève, sur les fiches **publiées** du cours :
  - `:new` quand aucune lecture n'existe ;
  - `:done` quand toutes les fiches publiées sont lues ;
  - `:started` sinon.
  - `resume_essential_slug` est la fiche publiée lue en dernier, à défaut la première fiche publiée non lue.
- **Effacement** : `Repositories::Assessment::LearningDataEraser#erase_for` supprime `essential_reads` de l'élève.

### 4.2 `materials.position`

- **Colonne** : `position` integer, nullable, sans unicité. Les matières à égalité, ou sans rang, se départagent par `name`.
- **Remplissage** par slug, d'après la table partagée `Repositories::Catalog::ProgramOrder` (lue par la migration et par la création d'une matière) :
  1. `mathematiques`, `maths` ;
  2. `physique-chimie`, `pc` ;
  3. `svt` ;
  4. `francais` ;
  5. `histoire-geographie`, `histoire-geo`, `hg` ;
  6. `edhc` ;
  7. `philosophie`, `philo`.
- **Les autres matières** restent à `NULL` et viennent après (`NULLS LAST`).
- **Matière créée plus tard** : `TaxonomyRepository#create_material` pose le rang d'après la même table (slug tiré du nom) ; une matière inconnue reste à `NULL`.
- **Pas d'écran aujourd'hui** : le rang ne se modifie pas à l'écran ; un écran de l'équipe viendra plus tard (dette notée dans le journal du chantier `cours-eleve`).
- **Lecteurs** :
  - `StudentHomeQuery#subjects` ;
  - `DailyExerciseQuery` (ADR-0089) ;
  - `CourseCatalogQuery#ordered` pour l'élève : `materials.position NULLS LAST, materials.name, courses.name, courses.id`.

  `SUBJECT_ORDER` est supprimé.
- **Ordre des autres rôles** : leur catalogue garde l'ordre actuel (memo, hors périmètre).

## 5. Conséquences

### 🟢 Positives

- « Commencer / Reprendre / Revoir » reste juste quand un cours gagne ou perd une fiche.
- Un seul ordre des matières pour l'accueil, l'exercice du jour et « Cours ».
- La base pour un futur suivi de lecture côté enseignant existe, sans être montrée.

### 🔴 Coûts consentis

- **Écriture à chaque ouverture** : une écriture par fiche ouverte, sur une requête GET. C'est un upsert d'une ligne par index unique.
- **Croissance** : la table grandit en élèves × fiches. À 10 000 élèves et 300 fiches lues chacun, cela fait 3 millions de lignes étroites.
- **Ouvrir n'est pas lire** : on ne sait pas si l'élève a vraiment lu la fiche. Pour le bouton, c'est accepté.
- **Deux migrations** dans la PR du chantier.
- **ADR-0089** (§4.1, « ordonnée par `SUBJECT_ORDER` ») lit désormais `materials.position`. L'ordre est le même ; seule la source change.

## 6. Notes d'implémentation

```ruby
# db/migrate/…_create_essential_reads.rb
create_table :essential_reads do |t|
  t.references :student, null: false, foreign_key: { to_table: :users, on_delete: :restrict }, index: false
  t.references :essential, null: false, foreign_key: { on_delete: :cascade }
  t.datetime :first_read_at, null: false
  t.datetime :last_read_at, null: false
  t.timestamps
end
add_index :essential_reads, %i[student_id essential_id], unique: true
add_index :essential_reads, %i[student_id last_read_at]
```

```ruby
# app/infrastructure/repositories/assessment/essential_read_repository.rb
def record(student_id:, essential_id:, at:)
  Orm::EssentialRead.upsert({ student_id:, essential_id:, first_read_at: at, last_read_at: at, created_at: at, updated_at: at },
                            unique_by: %i[student_id essential_id],
                            update_only: %i[last_read_at updated_at])
end
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/use_cases/assessment/record_essential_read_test.rb` : l'élève écrit, l'enseignant n'écrit pas (CA-11).
- `test/infrastructure/repositories/assessment/essential_read_repository_test.rb` : trois ouvertures donnent une ligne, avec `first_read_at` inchangé (CA-12).
- `test/infrastructure/repositories/assessment/learning_data_eraser_test.rb` : les lectures sont effacées (CA-16).
- `test/infrastructure/queries/catalog/course_catalog_query_test.rb` : `:new`, `:started`, `:done`, fiche dépubliée (CA-6 à CA-10) ; ordre par `materials.position` (CA-1, CA-17).
- `grep -rn SUBJECT_ORDER app/` ne renvoie rien.
