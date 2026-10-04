# ADR-0075 : Le niveau et la série d'un cours ne changent pas s'ils sortiraient une assignation active de son niveau

| | |
|---|---|
| **Statut** | Proposé *(règle décidée par le porteur le 2026-10-03 : « aucun cours ne doit être assigné hors de son niveau » ; refus retenu)* |
| **Date** | 2026-10-03 |
| **Chantier** | [`docs/chantiers/reorganisation-equipe-enseignant`](../../chantiers/reorganisation-equipe-enseignant/prd.md) — grill G12 révisé, G13 ; critère RE-27 |
| **Remplace** | — *(complète [ADR-0072](./0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md) et l'amendement du 2026-10-01 de l'[ADR-0035](./0035-cycle-de-vie-et-propriete-du-contenu.md))* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Depuis le 2026-10-01, un exercice ne s'assigne qu'à une classe du niveau de son cours, et de sa série si le cours en a une (`UseCases::Classroom::AssignResource` → `:conflict`, `other_level`, avec `Entities::Catalog::LevelAudience`). La règle ne vaut qu'**au moment d'assigner**.

`UseCases::Catalog::UpdateCourse` laisse l'équipe changer le niveau et la série d'un cours à tout moment, quel que soit son statut. Si un exercice de ce cours est assigné, l'assignation reste active dans une classe qui n'est plus de son niveau : l'élève ne peut plus l'ouvrir (lecture par niveau, UDR-0013), l'enseignant ne le sait pas. Le porteur a fixé l'invariant : **aucun cours ne doit être assigné hors de son niveau** ; il affirme qu'**aucune assignation n'existe aujourd'hui**, il n'y a donc rien à reprendre en base.

## 2. Moteurs de décision

1. L'invariant tient **par construction** : aucun chemin d'écriture ne peut le casser.
2. Le travail d'un enseignant (une assignation, son échéance, les sessions de ses élèves) ne disparaît jamais sans geste de sa part.
3. La règle de niveau reste **une seule règle** (`LevelAudience`), lue à l'assignation et à la modification d'un cours.
4. Le domaine ne référence ni ActiveRecord ni le contexte `classroom` : il lit ce qu'il lui faut par un port du contexte `catalog`.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — **Refuser le changement** de niveau ou de série qui sortirait une assignation active de sa classe | L'invariant tient, rien n'est perdu ; l'équipe sait quoi faire (retirer les assignations) | Retenue — décision du porteur |
| B — Archiver d'office les assignations devenues hors niveau, dans la même transaction | L'équipe n'est jamais bloquée | Les enseignants perdent des assignations sans être prévenus (moteur 2) |
| C — Avertir dans le formulaire, puis archiver après confirmation | L'équipe décide en connaissance de cause | Un écran de confirmation de plus pour un cas que le porteur juge rare ; mêmes pertes côté enseignant que B |
| D — Refuser **tout** changement de niveau ou de série d'un cours assigné | Plus simple : un compte suffit | Refuserait aussi l'élargissement inoffensif (Tle D → Tle sans série), qui garde toutes les classes couvertes |
| E — Interdire la modification du niveau d'un cours publié | Aucune lecture de plus | Bloque la correction d'une erreur de saisie sur un cours publié jamais assigné |

## 4. Décision

> **`UseCases::Catalog::UpdateCourse` refuse (`:conflict`, `errors: { level_slug: [:assigned_elsewhere] }`) un nouveau couple (niveau, série) qui ne couvre pas toutes les classes où un exercice du cours est assigné (assignation active). La couverture est celle d'`Entities::Catalog::LevelAudience`. Le nom, le sous-titre, le contenu et la matière restent modifiables.**

- **Port** : `Ports::Catalog::CourseRepositoryPort#assigned_classroom_levels(id:)` → `Array<[level_id, series_id]>`, **une entrée par classe** ayant au moins une assignation **active** d'un exercice d'une fiche du cours (`series_id` de la classe, `nil` si elle n'en a pas). Implémenté par `Repositories::Catalog::CourseRepository` en une requête (`classroom_assignments` actives de type `Exercise` → `exercises` → `essentials` du cours → `classrooms`, `DISTINCT` par classe).
- **Règle** (dans le use case, après la résolution de la taxonomie) : si `level_id` ou `series_id` change, chaque couple de `assigned_classroom_levels` doit être couvert par le nouveau couple du cours ; sinon refus, **rien n'est écrit**.
  - Couvert : même niveau, et série du cours `nil` ou égale à celle de la classe (la règle de lecture de l'élève et d'`AssignResource`).
  - Élargir (Tle D → Tle sans série) passe ; restreindre (Tle sans série → Tle D) passe seulement si aucune classe hors D n'a d'assignation ; changer de niveau passe seulement si aucune assignation n'est active.
- **Message** (formulaire du cours, sous le champ « Niveau ») : « Ce cours est assigné à des classes d'un autre niveau ou d'une autre série. Retirez ces assignations avant de le changer. »
- **Données existantes** : aucune migration. Le porteur affirme qu'aucune assignation n'existe (2026-10-03) ; la règle d'assignation du 2026-10-01 empêche d'en créer une hors niveau depuis.
- **Hors règle** : la matière d'un cours change librement (la règle de niveau ne la regarde pas) ; l'archivage d'un cours n'est pas concerné (ADR-0035).

## 5. Conséquences

### 🟢 Positives

- L'invariant « aucune assignation hors niveau » tient sur les deux seuls chemins qui peuvent le casser : assigner (2026-10-01) et modifier un cours (ici).
- Aucun travail d'enseignant n'est perdu en silence.
- La page de la classe n'a besoin d'aucun signal « hors niveau » : le cas ne peut plus se produire.

### 🔴 Coûts consentis

- **Une lecture de plus** à chaque changement de niveau ou de série d'un cours (aucune pour un simple renommage), servie par l'index existant `classroom_assignments (assignable_type, assignable_id)` : aucune migration.
- **Le port du catalogue lit des tables du contexte `classroom`** (assignations, classes) : comme `DeleteLevel` lit déjà les classes qui portent un niveau, c'est une lecture d'intégrité, pas une écriture croisée.
- **Course rare** : une assignation créée entre la lecture et l'écriture du cours passe. Ni verrou ni contrainte en base : le porteur juge le cas improbable (l'équipe modifie, l'enseignant assigne, au même instant) ; il resterait visible et réparable par un retrait.
- L'équipe doit demander aux enseignants de retirer leurs assignations avant de corriger le niveau d'un cours assigné.

## 6. Notes d'implémentation

```ruby
# app/domain/use_cases/catalog/update_course.rb (extrait)
if moved?(current, taxonomy.value) && !covers_all?(current.id, taxonomy.value)
  return Shared::Result.failure(:conflict, errors: { level_slug: [ :assigned_elsewhere ] })
end

def covers_all?(course_id, taxonomy)
  @courses.assigned_classroom_levels(id: course_id).all? do |pair|
    Entities::Catalog::LevelAudience.new(pairs: [ pair ]).covers?(level_id: taxonomy[:level_id], series_id: taxonomy[:series_id])
  end
end
```

La clé d'erreur `assigned_elsewhere` est traduite à côté de `taken` (`config/locales/teams/courses.fr.yml`) ; le contrôleur la rend dans le formulaire en 422 par le chemin existant de `render_result … form: :edit`.

## 7. Comment vérifier que la décision est respectée

- `test/domain/use_cases/catalog/update_course_test.rb` : changement de niveau avec une classe assignée → `:conflict` et rien d'écrit ; élargissement Tle D → Tle sans série → succès ; restriction Tle → Tle D avec une classe Tle C assignée → refus, sans classe Tle C → succès ; nom seul changé d'un cours assigné → succès.
- `test/infrastructure/repositories/catalog/course_repository_test.rb` : `assigned_classroom_levels` ne compte que les assignations actives, une entrée par classe, ignore les autres cours.
- `test/controllers/teams/courses_controller_test.rb` : 422, le message sous « Niveau », le cours inchangé en base.
