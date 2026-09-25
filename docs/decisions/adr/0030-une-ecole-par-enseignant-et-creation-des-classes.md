# ADR-0030 : Une école visible par enseignant en V1, `teacher_schools` avec drapeau « principale », classes créées par l'équipe puis par la direction

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-06**, bloque la V1 (Lot D) |
| **Remplace** | [ADR-0004](./0004-autorisation-multi-etablissements-enseignants.md) §3.1 (plusieurs écoles) et §2 (création de classe par l'enseignant) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0004 autorise un enseignant dans plusieurs établissements, alors que le [plan V1](../../chantiers/refonte-application/plan.md) le limite à une école, « tranché par ADR », sans que l'ADR existe (**C-01**). L'ADR-0004 §2 laisse l'enseignant créer des classes ; le code réserve ce droit à `team` et à `school_admin` ; le plan V1 dit que « les écoles et les classes sont créées par l'équipe » (**C-27**). Le Lot D prévoit qu'un enseignant « s'inscrit, déclare les classes qu'il enseigne ». Dans l'ancien code, l'onboarding était déduit de `classrooms.empty?` et bouclait.

## 2. Moteurs de décision

1. La V1 n'a qu'une école par enseignant, mais la V3 doit pouvoir en ajouter une sans migration.
2. Un enseignant ne voit que les classes de son école.
3. Une seule source de création de classes par vague.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Colonne `teachers.school_id` | La plus simple en V1 | Migration de données en V3 |
| B — **`teacher_schools` + drapeau `primary`** | Aucune migration en V3 | Une table pour une seule ligne en V1 |

## 4. Décision

> **Nous gardons `teacher_schools` avec un drapeau `primary`, nous limitons l'enseignant à une seule ligne en V1, et nous réservons la création des classes à l'équipe en V1 et à la direction à partir de la V2.**

**Table `teacher_schools`** (contexte `school`) :

| Colonne | Type | Contrainte |
|---|---|---|
| `teacher_id` | `bigint` | `NOT NULL`, FK `users` |
| `school_id` | `bigint` | `NOT NULL`, FK `schools` |
| `primary` | `boolean` | `NOT NULL DEFAULT false` |
| `created_at` | `datetime` | `NOT NULL` |

**Index** :

- unique `(teacher_id, school_id)` ;
- unique partiel `(teacher_id) WHERE primary`, qui garantit une seule école principale.

**En V1** :

- l'enseignant choisit son école pendant l'onboarding, et la ligne est créée avec `primary = true` ;
- `School::AttachTeacher` refuse une seconde ligne par `:conflict`. Seule l'équipe change l'école d'un enseignant.

L'école visible est toujours l'école principale ; elle alimente `actor.school_id` (ADR-0028).

**Enseignement** : `teacher_classrooms` (contexte `classroom`) porte `teacher_id` (FK `users`), `classroom_id`, `created_at` et un index unique `(teacher_id, classroom_id)`. En V1, l'enseignant **déclare** lui-même les classes qu'il enseigne (`Classroom::DeclareTeaching`). La policy `Classroom::DeclareTeachingPolicy` exige :

- le rôle `teacher` ;
- `classroom.school_id == actor.school_id` ;
- une classe `active`.

Il retire sa déclaration par `Classroom::WithdrawTeaching`, qui supprime la ligne : c'est une liaison, pas une production d'élève.

**Onboarding** : état persisté `teacher_profiles.onboarding_completed_at` (`datetime NULL`), posé à la fin du parcours et jamais recalculé à partir des classes.

**Création des classes** : `Classroom::CreateClassroom` est autorisé par `Classroom::ManageClassroomPolicy` :

- en V1, `team` seul ;
- à partir de la V2, aussi le `school_admin` rattaché à l'école de la classe (ADR-0044).

L'enseignant ne crée jamais de classe.

## 5. Conséquences

### 🟢 Positives

- C-01 et C-27 sont fermées, et le Lot D a un modèle sans ambiguïté.
- La V3 ajoute le sélecteur d'école en levant la règle « une ligne » dans le use case, sans toucher au schéma.
- La boucle d'onboarding de l'ancien ne peut plus se produire.

### 🔴 Coûts consentis

- Un enseignant peut se déclarer dans n'importe quelle classe de son école, et accède ainsi à la liste nominative. On accepte ce risque en V1 : les classes sont créées par l'équipe et la liste n'expose pas les contacts (ADR-0028). En V2, la direction peut retirer une déclaration.
- Un enseignant qui change d'établissement en cours d'année passe par l'équipe.

## 6. Notes d'implémentation

```ruby
# db/migrate/…_create_teacher_schools.rb
create_table :teacher_schools do |t|
  t.references :teacher, null: false, foreign_key: { to_table: :users }
  t.references :school, null: false, foreign_key: true
  t.boolean :primary, null: false, default: false
  t.datetime :created_at, null: false
end
add_index :teacher_schools, %i[teacher_id school_id], unique: true
add_index :teacher_schools, :teacher_id, unique: true, where: '"primary"', name: "index_teacher_schools_one_primary"
```

## 7. Comment vérifier que la décision est respectée

- Test de repository : une seconde ligne `primary` lève `ActiveRecord::RecordNotUnique`.
- Tests de policy : `DeclareTeachingPolicy` refuse une classe d'une autre école et une classe archivée ; `ManageClassroomPolicy` refuse `teacher` en toute vague, et `school_admin` en V1.
- Test système : un enseignant dont on retire toutes les classes n'est pas renvoyé vers l'onboarding.

## 8. Remplace, complète, amende

- **Remplace** l'ADR-0004 §3.1 (C-01) et §2 (C-27).
- La forme de la policy de l'ADR-0004 §3.3 est traitée par l'ADR-0028.

## 9. Points à confirmer par le porteur

- En V1, l'enseignant se déclare lui-même dans les classes de son école, sans validation, comme le prévoit le Lot D.
- La direction crée des classes à partir de la V2.
