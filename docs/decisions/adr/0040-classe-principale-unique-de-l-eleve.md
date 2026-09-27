# ADR-0040 : Une classe principale unique par élève, garantie par index partiel ; sélecteur reporté à la V3

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-18**, bloque la V3 (le schéma est posé en V1) |
| **Amende** | [ADR-0003](./0003-multi-appartenance-et-denormalisation-eleves.md) §2 (appartenance illimitée) et §4 (rejoindre une classe supplémentaire) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0003 permet à un élève d'appartenir à un nombre illimité de classes, dont une principale. L'interface n'en montre qu'une, sans sélecteur (**C-12**). L'ADR-0003 §4 promet qu'un élève « rejoint n'importe quel cours du soir » avec un code, mais `/c/:code` crée toujours un **nouveau compte** : aucun chemin n'existe pour un élève déjà connecté (**C-28**). L'unicité de la classe principale n'est garantie nulle part en base.

## 2. Moteurs de décision

1. Le fil de l'élève a une seule classe de référence, sans ambiguïté.
2. L'invariant « une principale » tient en base.
3. La V3 ajoute le multi-classes sans migration de schéma.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Colonne `students.classroom_id` | Minimal | Perd l'historique et la V3 |
| B — **`classroom_students` + index partiel sur `primary`** | Garde la table de l'ADR-0003 | Une V1 plus stricte que la table ne l'exige |

## 4. Décision

> **Nous gardons `classroom_students`, nous garantissons en base une seule classe principale active par élève, et nous limitons l'élève à cette seule classe active jusqu'à la V3.**

**Table `classroom_students`** (contexte `classroom`) :

| Colonne | Contrainte |
|---|---|
| `classroom_id` | `NOT NULL`, FK `classrooms` |
| `student_id` | `NOT NULL`, FK `users` |
| `primary` | `boolean NOT NULL DEFAULT false` |
| `joined_at` | `datetime NOT NULL` |
| `left_at` | `datetime NULL` |

**Index** :

- unique `(classroom_id, student_id)` ;
- unique partiel `(student_id) WHERE "primary" AND left_at IS NULL`, qui garantit une classe principale active au plus.

**Règles de la V1** :

- `/c/:code` (`Classroom::JoinWithCode`, policy `Classroom::JoinPolicy`, acteur anonyme accepté, ADR-0028) crée le compte élève **et** son adhésion `primary = true`, dans une transaction (ADR-0050 pour le PIN).
- Un élève **connecté** qui ouvre `/c/:code` :
  - s'il a une classe principale active, reçoit `:conflict` et le message « Tu es déjà inscrit dans une classe » ;
  - si sa classe est archivée (ADR-0041), il la rejoint comme nouvelle principale (`Classroom::JoinAsStudent`), sans créer de compte.
- Quitter une classe pose `left_at`. La ligne n'est jamais supprimée : les résultats restent rattachés à l'historique (ADR-0036).
- Le fil de l'élève lit la classe principale active, et elle seule.

**V3, si la demande est confirmée** : le sélecteur de classe ajoute des adhésions `primary = false`. L'index partiel reste valide tel quel.

## 5. Conséquences

### 🟢 Positives

- C-12 est fermée : l'interface et le modèle disent la même chose.
- C-28 est fermée pour la V1 : un élève connecté n'a plus de compte fantôme créé par un code.
- La V3 n'exige aucune migration.

### 🔴 Coûts consentis

- Pas de cours du soir ni de classe de soutien en V1 : la promesse de l'ADR-0003 §4 est suspendue.
- Un élève qui change de classe en cours d'année passe par l'enseignant ou l'équipe. Ce use case est livré avec l'archivage de la V3.

## 6. Notes d'implémentation

```ruby
# db/migrate/…_create_classroom_students.rb
create_table :classroom_students do |t|
  t.references :classroom, null: false, foreign_key: true
  t.references :student, null: false, foreign_key: { to_table: :users }
  t.boolean :primary, null: false, default: false
  t.datetime :joined_at, null: false
  t.datetime :left_at
end
add_index :classroom_students, %i[classroom_id student_id], unique: true
add_index :classroom_students, :student_id, unique: true,
          where: '"primary" AND left_at IS NULL', name: "index_classroom_students_one_active_primary"
```

## 7. Comment vérifier que la décision est respectée

- Test de repository : une seconde adhésion principale active lève `RecordNotUnique`.
- Test système : un élève connecté qui ouvre `/c/:code` n'obtient pas de second compte.
- Test de use case : rejoindre depuis une classe archivée crée l'adhésion principale ; depuis une classe active, `:conflict`.

## 8. Remplace, complète, amende

- **Amende** l'ADR-0003 §2 (C-12) et §4 (C-28). Le principe de l'ADR-0003 (table de jointure plutôt que clé sur l'élève) est conservé.

## 9. Points à confirmer par le porteur

- Pas de seconde classe (cours du soir) avant la V3.
