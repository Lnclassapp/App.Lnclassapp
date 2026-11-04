# Plan d'exécution — Develop charge toutes les leçons v3 du dépôt, entières

> Un seul lot : le changement tient dans la règle de choix du mode et son câblage.

## Graphe

```
Lot A — règle de Develop + câblage + tests (séquentiel, seul)
```

## Lot A — Develop : tout fichier v3 en mode leçon entière

- **Couche**       : domaine (entité, use case) + tâche rake
- **Fichiers**     : `app/domain/entities/catalog/automatic_load_stage.rb`
                     `app/domain/entities/catalog/v3_programme_levels.rb` (commentaire)
                     `app/domain/use_cases/catalog/load_repository_lessons.rb`
                     `lib/tasks/contenus.rake`
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/catalog/automatic_load_stage_test.rb`
                     `test/domain/use_cases/catalog/load_repository_lessons_test.rb`
                     `test/integration/catalog/automatic_lesson_load_test.rb`
- **Done quand**   : CA-1 à CA-5 verts ; chargement réel des fichiers du dépôt en local sans échec

## Collisions

| Fichier | Lots |
|---|---|
| — | un seul lot |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture) — amendements d'ADR-0123 et ADR-0124, pas d'ADR nouveau
- [x] UDR écrite pour **chaque** vue créée ou modifiée — aucune vue
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle — sans objet (un lot)
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/` — aucun fichier créé
- [x] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur — chargement réel des 417 fichiers en mode Develop (nominal) ; chemins d'erreur par les tests d'intégration (référentiel absent, import refusé, verrou pris) ; pas d'agent challenger séparé
- [x] Pureté domaine · rubocop · tests · brakeman : au vert (`bin/ci-quiet` niveau pr, `e491fe5a`)
- [x] PR unique vers `Develop`, référençant chantier + ADR + UDR — #477
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)
