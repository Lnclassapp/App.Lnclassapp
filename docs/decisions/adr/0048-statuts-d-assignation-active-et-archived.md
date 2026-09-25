# ADR-0048 : Une assignation est `active` ou `archived`, son auteur est un utilisateur, et une réassignation crée une nouvelle ligne

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-26**, bloque la V1 (Lot D) |
| **Remplace** | [ADR-0016](./0016-conservation-historique-assignations.md) §2 (statuts, réactivation, `teacher_id` de session) · [ADR-0007](./0007-hierarchie-pedagogique-et-assignations-polymorphes.md) §5 (statuts et types assignables) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Les statuts d'assignation divergent (**C-10**) :

- l'ADR-0007 en prévoit trois, `added`, `active` et `validated` ;
- l'ADR-0016 ajoute `archived` et une réactivation en `added` ;
- la colonne a `active` pour défaut, le code écrit `added`, et `validated` n'est jamais écrit.

Réassigner après un retrait lève `RecordNotUnique`. `assigned_by_id`, clé étrangère vers `users`, reçoit un identifiant de profil enseignant. L'ADR-0007 liste `Course`, `Essential` et `ExamSubject` comme types assignables ; le code accepte aussi `Exercise` (**C-04**), et `ExamSubject` n'a pas de table. L'ADR-0016 §2 place un `teacher_id` sur `ExerciseSession`, que le schéma n'a pas (**C-25**).

## 2. Moteurs de décision

1. Deux états qui ont un sens pour l'enseignant : « en cours » et « retiré ».
2. Retirer puis réassigner fonctionne, et l'historique garde les deux.
3. On sait à quelle assignation une session répond.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Garder quatre statuts | Aucun changement | Deux statuts morts, C-10 |
| B — `active`/`archived`, réactivation de la même ligne | Une ligne par couple | Perd la date du premier retrait |
| C — **`active`/`archived`, nouvelle ligne à la réassignation** | Historique complet ; index partiel simple | Plusieurs lignes par couple |

## 4. Décision

> **Nous réduisons les statuts d'assignation à `active` et `archived`, nous faisons référencer l'auteur par `users.id`, nous créons une nouvelle ligne à chaque réassignation, et nous rattachons la session à l'assignation qui l'a motivée.**

**Table `classroom_assignments`** (contexte `classroom`) :

| Colonne | Contrainte |
|---|---|
| `public_id` | ADR-0029 |
| `classroom_id` | `NOT NULL`, FK |
| `assignable_type` | `CHECK IN ('Course','Essential','Exercise')` |
| `assignable_id` | `bigint NOT NULL` |
| `assigned_by_id` | `NOT NULL`, FK `users` : l'enseignant ou le membre `team` |
| `status` | `string NOT NULL DEFAULT 'active'`, `CHECK IN ('active','archived')` |
| `assigned_at` | `datetime NOT NULL` |
| `archived_at` | `datetime NULL` |
| `archived_by_id` | FK `users` `NULL` |

Contrainte : `CHECK ((status = 'archived') = (archived_at IS NOT NULL))`. Index unique partiel `(classroom_id, assignable_type, assignable_id) WHERE status = 'active'`.

**Transitions** :

- `Classroom::AssignResource` crée une ligne `active`. Policy : `Classroom::AssignPolicy`, soit l'enseignant de la classe ou `team`. Il faut une classe `active` (ADR-0041) et une ressource `published` (ADR-0035). Une assignation déjà active donne `:conflict`.
- `Classroom::ArchiveAssignment` passe de `active` à `archived`. C'est définitif.
- Réassigner crée une **nouvelle** ligne ; l'ancienne reste `archived`.

**Intégrité polymorphe** : aucune clé étrangère n'est possible sur `assignable_id`. L'intégrité tient par construction : seul un contenu `published` est assignable, et un contenu publié n'est jamais supprimé, seulement archivé (ADR-0036). Le repository vérifie l'existence à l'assignation.

**Types** : `ExamSubject` est retiré, avec la feature F-24. Ajouter un type demande d'amender cet ADR.

**Sessions** : `exercise_sessions.classroom_assignment_id` (FK `NULL`) est posé au démarrage quand l'élève ouvre l'exercice depuis une assignation active de sa classe principale (ADR-0054). L'enseignant et la classe se lisent par l'assignation. Le `teacher_id` de l'ADR-0016 §2 n'est pas créé.

## 5. Conséquences

### 🟢 Positives

- C-10, C-04 et C-25 sont fermées ; le `RecordNotUnique` de l'ancien ne peut plus se produire.
- Un tableau de bord enseignant compte l'activité par assignation, sans deviner.

### 🔴 Coûts consentis

- Pas de clé étrangère sur la ressource assignée : l'intégrité dépend de la règle d'archivage de l'ADR-0036.
- Une session ouverte depuis le catalogue, hors assignation, n'est rattachée à aucune classe.
- Plusieurs lignes par couple classe × ressource : les queries filtrent sur `status`.

## 6. Notes d'implémentation

```ruby
# db/migrate/…_create_classroom_assignments.rb
add_check_constraint :classroom_assignments, "assignable_type IN ('Course','Essential','Exercise')",
                     name: "classroom_assignments_type_values"
add_check_constraint :classroom_assignments, "status IN ('active','archived')", name: "classroom_assignments_status_values"
add_index :classroom_assignments, %i[classroom_id assignable_type assignable_id], unique: true,
          where: "status = 'active'", name: "index_classroom_assignments_one_active"
```

## 7. Comment vérifier que la décision est respectée

- Test de use case : assigner, archiver, réassigner donne deux lignes, et la seconde est `active`.
- Test de repository : deux lignes `active` pour le même couple lèvent `RecordNotUnique`.
- Test de schéma : `status = 'added'` et `assignable_type = 'ExamSubject'` sont refusés par la base.

## 8. Remplace, complète, amende

- **Remplace** l'ADR-0016 §2 (C-10, C-25) et l'ADR-0007 §5 (C-04).
- Le principe de l'ADR-0016 (archiver plutôt que détruire) et la table unique polymorphe de l'ADR-0007 sont conservés.

## 9. Points à confirmer par le porteur

- Une réassignation crée une nouvelle ligne, sans réactiver l'ancienne.
- `ExamSubject` est retiré des types assignables.
