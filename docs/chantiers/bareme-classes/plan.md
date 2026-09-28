# Plan d'exécution — Barème des classes modifiable par l'équipe

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — le barème en base, son écran, et l'import et la génération qui le lisent
        (séquentiel, un seul lot : la table, le port et l'entité de plan sont partagés par les trois cas d'usage,
         et la reprise de données doit tomber dans le même déploiement que le code qui la lit)
```

Pourquoi un seul lot : lire le barème (écran), le modifier (modale) et l'appliquer (import, génération) consomment la même entité, le même port et la même table ; les découper en lots parallèles ferait remonter presque tout au Lot 0. Surtout, l'ancienne constante disparaît : le code qui la lisait et la reprise de données doivent partir ensemble, sinon la production génère avec un barème vide.

---

## Lot A — L'équipe voit et modifie le barème ; l'import et la génération le lisent

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `db/migrate/20260928140000_create_classroom_plan_entries.rb` · `db/migrate/20260928140100_fill_classroom_plan_entries.rb` · `db/schema.rb`
                     `db/seeds/{catalog,school}.rb`
                     `app/domain/entities/classroom/{classroom_plan,default_classroom_plan}.rb` · `app/domain/entities/identity/audit_action.rb`
                     `app/domain/ports/classroom/classroom_plan_repository_port.rb`
                     `app/domain/policies/classroom/manage_classroom_plan_policy.rb` · `app/domain/dtos/classroom/classroom_plan_line_input.rb`
                     `app/domain/use_cases/classroom/{show_classroom_plan,update_classroom_plan_line,generate_missing_classrooms}.rb`
                     `app/domain/use_cases/school/import_schools.rb`
                     `app/infrastructure/orm/classroom_plan_entry.rb` · `app/infrastructure/repositories/classroom/classroom_plan_repository.rb`
                     `app/infrastructure/queries/catalog/{levels_query,team_home_query}.rb` · `app/infrastructure/repositories/catalog/taxonomy_repository.rb`
                     `app/jobs/school/import_schools_job.rb` · `app/jobs/classroom/generate_missing_classrooms_job.rb`
                     `app/controllers/teams/classroom_plans_controller.rb` · `config/routes/teams.rb`
                     `app/views/teams/classroom_plans/{show,edit,_line_row,_totals,_undefined}.html.erb`, `update.turbo_stream.erb`
                     `app/views/teams/schools/index.html.erb` (menu « Classes »)
                     `app/views/teams/homes/_referential.html.erb` · `app/views/teams/levels/{index,edit,_form,_level_row}.html.erb`
                     `config/locales/teams/{classroom_plans,homes,levels,import_schools,schools}.fr.yml`
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/classroom/{classroom_plan,default_classroom_plan}_test.rb` · `test/support/domain/taxonomy_fixture.rb`
                     `test/domain/use_cases/classroom/{show_classroom_plan,update_classroom_plan_line,generate_missing_classrooms}_test.rb`
                     `test/domain/policies/classroom/manage_classroom_plan_policy_test.rb` · `test/domain/dtos/classroom/classroom_plan_line_input_test.rb`
                     `test/infrastructure/repositories/classroom/classroom_plan_repository_test.rb` · `test/db/classroom_plan_data_migration_test.rb`
                     `test/infrastructure/queries/catalog/levels_query_test.rb` · `test/controllers/teams/{classroom_plans,levels,homes}_controller_test.rb`
                     `test/domain/use_cases/school/import_schools_test.rb` · `test/support/factories/catalog.rb`
                     `test/system/teams/classroom_plan_test.rb` · `test/performance/classroom/generate_missing_classrooms_performance_test.rb`
                     `test/controllers/teams/classroom_generations_controller_test.rb` · `test/system/school/generate_classrooms_test.rb`
                     `test/db/{schema_constraints,seeds}_test.rb` · `test/infrastructure/orm/models_test.rb` · `test/jobs/classroom/generate_missing_classrooms_job_test.rb`
- **Done quand**   : l'équipe modifie un nombre du barème à l'écran, puis la génération donne ce nombre à un établissement sans classe ; la reprise redonne exactement l'ancien barème ; le menu « Classes » des établissements mène à la génération et au barème (BC-01 à BC-11)

---

## Vérification de collision

Un seul lot : pas de collision interne. Collisions possibles avec les chantiers parallèles, à surveiller au merge :

| Fichier | Chantier parallèle | Nature |
|---|---|---|
| `app/domain/use_cases/school/import_schools.rb`, `app/jobs/school/import_schools_job.rb` | `code-etablissement` (code d'établissement à l'import) | diff limité ici à une dépendance `classroom_plan:` et à l'appel du plan |
| `config/locales/teams/import_schools.fr.yml` | `code-etablissement` | deux libellés de « sautés » et la phrase des classes |
| `db/schema.rb` (version) | les deux | ligne `version` et bloc de la table, rien d'autre |
| `app/views/teams/schools/index.html.erb`, `config/locales/teams/schools.fr.yml` | `finitions-generation-menu` (toast et libellés de la génération) | en-tête réécrit : bouton de génération → menu « Classes » (demande du porteur) ; à fusionner à la main si les libellés de la génération changent là-bas |
| `docs/decisions/{adr,udr}/README.md` | les deux | numéros ADR-0058 et UDR-0045 pris à « plus haut + 2 » pour éviter la collision |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR-0058 écrit et indexé ; amendements ADR-0030 et ADR-0056
- [x] UDR-0045 écrite et indexée ; amendements UDR-0032, UDR-0018, UDR-0036, UDR-0043
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur *(à faire par le challenger, sur la PR)*
- [x] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop` *(ouverte par le coordinateur)*
- [x] `journal.md` complété
