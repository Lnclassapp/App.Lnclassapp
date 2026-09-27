# Memo — Catalogue : entités de lecture et d'écriture incompatibles

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | cadrage |
| **Ouvert le** | 2026-09-18 |
| **Branche** | `fix/catalog-lecture-ecriture-incompatibles` |
| **Gravité** | 🔴 **Critique — édition et suppression de cours cassées** |

---

## Le problème

Deux familles d'entités coexistent pour le même concept :

| Famille | Attributs | Usage |
|---|---|---|
| `Entities::Course` (racine) | `status`, `level_id`, `series_id`, `material_id`, `published_at` | écriture |
| `Entities::Catalog::Course` (namespacée) | `id, name, slug, subtitle, content, level, material, series, essentials` | lecture |

`CourseRepository#find_course_by_slug` retourne la **lecture**, `#save_course` attend l'**écriture**. `UseCases::Catalog::ManageResource#execute_update` enchaîne les deux — donc casse.

Reproduit dans une transaction annulée, via l'appel exact de `CoursesController:119` :

```
UPDATE CRASH: NoMethodError: undefined method 'status'
              for an instance of Entities::Catalog::Course
```

**Même défaut sur les habiletés** : `find_essential_by_slug` retourne `(id, name, slug)` alors que `save_essential` lit `.subtitle`, `.course_id`, `.content` → `EssentialsController#update` (ligne 121) est cassé de la même façon.

## Les défauts rattachés à la même cause

| # | Emplacement | Symptôme |
|---|---|---|
| 1 | `catalog/course_repository.rb:39-57` | `save_course` ↔ `find_course_by_slug` incompatibles |
| 2 | `use_cases/catalog/create_course.rb:28` | appelle `@course_repository.save`, l'adaptateur n'expose que `save_course` → `NotImplementedError` |
| 3 | `repositories/catalog_repository.rb:70` | `find_courses` délègue à une méthode inexistante (la vraie est `find_all`) |
| 4 | `repositories/catalog_repository.rb:86` | `create_course_with_essentials_and_exercises` délègue à une méthode inexistante (la vraie est `bulk_import_courses`) |
| 5 | `catalog/course_repository.rb:234-237` | `map_exercise` a un corps réduit à deux commentaires → `find_exercises_for_essential` renvoie `[nil]` |
| 6 | `catalog/essentials_controller.rb:101` | lit `result.course`, `ManageResource` retourne `result.resource` → `nil` sur le chemin de succès |
| 7 | `catalog/course_repository.rb:50-51` | `map_course` ne restitue ni `status`, ni `published_at`, ni `essentials_count` ; `persisted?` vaut **toujours `false`** même après un `save` réussi |

## Pour qui

**Team** (administrateurs et créateurs de contenu) : l'édition et la suppression d'un cours ou d'une habileté plantent. C'est le cœur du travail de production de contenu pédagogique.

## Pourquoi maintenant

Un test existant, `test/domain/use_cases/catalog/create_course_test.rb`, est **vert** — parce que son mock définit `save`, méthode que l'adaptateur réel n'expose pas. C'est un test qui valide un contrat que la production ne remplit pas : il donne un faux signal de sécurité sur une zone cassée.

## Hors périmètre

- La question de fond « faut-il un objet `Result` dédié plutôt qu'`OpenStruct` » → écart connu, `docs/guide/conventions.md` §8, mérite son propre ADR.
- La migration générale des namespaces dupliqués.

## Ce que le grill a révélé

> À remplir en phase 1. La question centrale : **les deux familles d'entités sont-elles un choix assumé (CQRS) ou un accident de migration ?**

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| | | |

## Cas limites identifiés

- Si la séparation lecture/écriture est **voulue** (ADR-0022), alors `ManageResource` ne doit pas enchaîner `find_*` puis `save_*` sur deux familles différentes : il lui faut un `find_for_update` retournant l'entité d'écriture.
- Si elle est **accidentelle**, la fusion des deux familles est un refactoring large qui touche tous les contrôleurs catalogue.
- `persisted?` hérité d'`ActiveModel` vaut toujours `false` sur `Entities::Catalog::Course` : tout appelant qui le teste obtient une fausse réponse **silencieuse**. `Entities::Course` et `Entities::Student` le définissent comme `id.present?`.

## Questions encore ouvertes

- L'ADR-0022 documente-t-il explicitement la séparation des deux familles, ou est-elle implicite ?
- `find_exercises_for_essential` de `CourseRepository` doit-il être réparé ou supprimé, la façade déléguant déjà au bon `Repositories::Assessment::ExerciseRepository` ?
