# Plan d'exécution — Générer les classes manquantes des établissements

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — générer les classes manquantes (séquentiel, un seul lot : un seul cas d'usage, qui touche la migration,
        les ports, routes et locales partagés)
```

---

## Lot A — L'équipe génère les classes des établissements qui n'en ont pas

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `db/migrate/20260928100000_allow_classroom_generation_reports.rb` · `db/schema.rb`
                     `app/domain/entities/catalog/import_kind.rb`
                     `app/domain/ports/school/school_repository_port.rb` · `app/domain/ports/catalog/import_report_repository_port.rb`
                     `app/domain/use_cases/classroom/start_classroom_generation.rb` · `app/domain/use_cases/classroom/generate_missing_classrooms.rb`
                     `app/infrastructure/repositories/school/school_repository.rb`
                     `app/jobs/classroom/generate_missing_classrooms_job.rb` · `config/initializers/imports.rb`
                     `app/controllers/teams/classroom_generations_controller.rb` · `app/controllers/teams/imports_controller.rb`
                     `config/routes/teams.rb`
                     `app/views/teams/schools/index.html.erb`
                     `app/views/teams/imports/{index,show,_import_row,_status}.html.erb`
                     `config/locales/teams/{schools,imports,classroom_generations}.fr.yml` · `config/locales/shared/common.fr.yml`
- **Dépend de**    : —
- **Test associé** : `test/domain/use_cases/classroom/{start_classroom_generation,generate_missing_classrooms}_test.rb`
                     `test/domain/entities/catalog/import_kind_test.rb` · `test/domain/ports/*`
                     `test/infrastructure/repositories/school/school_repository_test.rb`
                     `test/jobs/classroom/generate_missing_classrooms_job_test.rb`
                     `test/controllers/teams/{classroom_generations,imports}_controller_test.rb`
                     `test/system/school/generate_classrooms_test.rb` · `test/db/schema_constraints_test.rb`
                     `test/performance/classroom/generate_missing_classrooms_performance_test.rb`
- **Done quand**   : depuis « Établissements », l'équipe confirme la génération, suit son rapport, et les établissements sans classe de l'année ont leurs classes, les autres inchangés (GC-01 à GC-09)

---

## Vérification de collision

Un seul lot : pas de collision possible.

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/teams.rb`, `config/locales/**`, `db/schema.rb` | Lot A |
| ports `school` et `catalog` | Lot A |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR-0056 écrit et indexé ; amendements ADR-0030 et ADR-0039
- [x] UDR-0043 écrite et indexée ; amendement UDR-0036
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur *(à faire par le challenger, sur la PR)*
- [x] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop` *(ouverte par le coordinateur)*
- [x] `journal.md` complété
