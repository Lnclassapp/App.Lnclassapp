# Memo — Les trois `belongs_to` scopés de `ClassroomAssignment` sont inutilisables

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré — fermé le 2026-09-24 |
| **Repris le** | 2026-09-24 |
| **Ouvert le** | 2026-09-18 |
| **Branche** | `fix/classroom-assignment-belongs-to-casses` |
| **Gravité** | 🟠 **Haute — 3 méthodes de repository lèvent dès qu'une assignation existe** |

---

## Le problème

`app/infrastructure/orm/classroom_assignment.rb:9-11` déclare trois raccourcis :

```ruby
belongs_to :course, -> { where(classroom_assignments: { resource_type: "Orm::Course" }) },
           class_name: "Orm::Course", foreign_key: :resource_id, optional: true
# idem :essential (l.10) et :exercise (l.11)
```

Le scope d'un `belongs_to` s'applique à la relation **cible** (`courses`), pas au propriétaire. La requête générée filtre donc sur une table absente du `FROM` :

```
SELECT "courses".* FROM "courses"
WHERE "courses"."id" = $1 AND "classroom_assignments"."resource_type" = ...
→ PG::UndefinedTable: missing FROM-clause entry for table "classroom_assignments"
```

**Conséquence** : `ClassroomRepository#find_linked_courses` (l.102), `#find_linked_essentials` (l.111) et `#find_linked_exercises` (l.118) lèvent dès qu'une assignation existe. **En base vide elles renvoient `[]`** — c'est exactement ce qui a masqué le bug.

## Pour qui

**Teacher** : toute vue qui liste les ressources rattachées à une classe. Le bug est aujourd'hui **latent** parce que `ClassroomAssignmentRepository` passe par `record.resource` et n'emploie pas ces raccourcis — mais n'importe quelle vue ou presenter appelant `assignment.course` plante.

## Pourquoi maintenant

Trois tests sont **déjà écrits** pour ces méthodes et attendent en `skip` avec la référence de ce bug. Ils passeront au vert dès la correction, sans une ligne à réécrire. Le coût de fermeture est minimal et la couverture est prête.

## Hors périmètre

Le remplacement des constantes `Orm::ClassroomExercise` / `Orm::ClassroomEssential` dans les queries → chantier [`queries-constantes-orm-disparues`](../queries-constantes-orm-disparues/memo.md).

## Symptôme

`assignment.essential` (idem `.course`, `.exercise`) lève
`PG::UndefinedTable: missing FROM-clause entry for table "classroom_assignments"` dès qu'une assignation existe.

## Reproduction

`bin/rails runner`, en dev, dans une transaction annulée (2026-09-24) :

1. `a = Orm::ClassroomAssignment.create!(classroom: Orm::Classroom.first, resource: Orm::Essential.first, status: "added")`
2. `a.reload.essential` → `PG::UndefinedTable`.
3. `classroom.classroom_essentials.includes(:essential).to_a` → idem (préchargement).

## Portée

| | |
|---|---|
| **Depuis quand** | `0991bd3` (2026-08-29), migration polymorphe ADR-0007 : les raccourcis sont nés cassés |
| **Acteurs touchés** | Teacher et Student : flux (`_activities`, `_habiletes`, `_exercises`), partials de classe, `assessment/classroom_exercises_controller.rb:24,47`, `ClassroomRepository#find_linked_*` |
| **Données corrompues** | Non (lecture seule) |

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Supprimer les raccourcis au profit de `resource` ? | **Non** : une dizaine de vues et 2 contrôleurs appellent `.essential` / `.exercise` / `.course` | On répare les associations, on ne les supprime pas |
| Ont-ils déjà fonctionné ? | Non, nés cassés avec l'ADR-0007 | Aucune régression à rechercher avant `0991bd3` |
| Que doit rendre `assignment.essential` sur une assignation de type Course ? | `nil`. C'était l'intention du scope d'origine : ne jamais renvoyer une ressource d'un autre type portant le même id | Test dédié au garde de type |
| Bloque-t-il un autre chantier ? | Oui : `queries-constantes-orm-disparues` en dépend | Livrer celui-ci d'abord |

## Cas limites identifiés

- Deux pistes de correctif : lambda vide avec le `where` porté sur la cible, **ou** suppression pure des trois `belongs_to` au profit de l'association polymorphe `resource`.
- La seconde piste est probablement la bonne : `Orm::Classroom` expose déjà `courses` / `essentials` / `exercises` via des `has_many through ... source_type` (lignes 32-34) qui **fonctionnent**.
- Avant suppression, tracer les appelants de `assignment.course` dans les vues et presenters.
- Le test de reproduction existe déjà : lever le `skip` dans `test/infrastructure/classroom_repository_test.rb` suffit à le voir rouge.

## Correctif retenu

`belongs_to` **sans scope** sur `resource_id` (le préchargement et la jointure fonctionnent), plus une surcharge du lecteur qui renvoie `nil` si `resource_type` ne correspond pas. Couche : infrastructure (`app/infrastructure/orm/classroom_assignment.rb`). Pas d'ADR : le schéma cible (ADR-0007) ne change pas.

## Contrat d'exécution — un seul lot, pas de `plan.md`

1. Lever les 3 `skip` de `test/infrastructure/classroom_repository_test.rb` et ajouter un test du garde de type dans `test/models/`.
2. Les voir **rouges** avec `PG::UndefinedTable`.
3. Corriger `classroom_assignment.rb:9-11`.
4. Vert · `bin/rails test test/infrastructure test/models test/domain` au vert.

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [x] Test au vert · suite du contexte borné au vert
- [x] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : réparées, ou dette explicitement notée au journal *(aucune)*
- [x] Challenger a rejoué les étapes de reproduction dans l'application
- [x] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés
