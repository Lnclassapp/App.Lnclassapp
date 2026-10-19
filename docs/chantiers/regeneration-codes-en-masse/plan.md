# Plan d'exécution — Régénérer en une fois le code de plusieurs établissements

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
>
> **Ce plan n'est exécuté qu'après la réponse du porteur à Q0** ([memo](memo.md#ce-que-le-grill-a-révélé)) et l'acceptation de l'ADR-0096 et des UDR-0104 à 0106. Il suit les recommandations Q1 à Q7 ; une réponse différente le modifie avant le Lot 0.

## Graphe

```
Lot 0 — SOCLE (séquentiel) : migration, contrats, scope de sélection partagé, adaptateurs, routes, locales
  ↓
  ├─► Lot A « lancer depuis la liste »          ┐
  ├─► Lot B « exécuter et suivre le rapport »   ├─ en parallèle, fichiers disjoints
  └─► Lot C « date du changement sur la fiche » ┘
  ↓
Preuve : parcours complet RM-01 → RM-02 par un challenger (A + B fusionnés)
```

4 lots. Les adaptateurs (repositories) sont au Lot 0 : A et B lisent le même `SchoolRepository` et le même `ImportReportRepository`, qui remonteraient de toute façon au socle.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : `db/migrate/<horodatage>_add_school_codes_to_import_report_kinds.rb` · `db/schema.rb`
                     `app/domain/entities/catalog/import_kind.rb` (`SCHOOL_CODE_REGENERATION`, `REPORT_POLICIES`)
                     `app/domain/entities/school/code_regeneration_candidate.rb`
                     `app/domain/dtos/school/school_selection.rb` · `app/domain/dtos/school/code_regeneration_input.rb`
                     `app/domain/policies/school/regenerate_school_codes_policy.rb`
                     `app/domain/ports/school/school_repository_port.rb` (3 méthodes)
                     `app/domain/ports/catalog/import_report_repository_port.rb` (`create(details:)`)
                     `app/domain/ports/identity/audit_log_port.rb` (`record_many`)
                     `app/infrastructure/orm/school.rb` (scope `list_filtered`)
                     `app/infrastructure/queries/school/schools_query.rb` (scope partagé, `school_code_rotated_at`)
                     `app/infrastructure/queries/school/school_detail_query.rb` (`school_code_rotated_at`)
                     `app/infrastructure/repositories/school/school_repository.rb` (`count_for_code_regeneration`, `code_regeneration_batch`, `replace_school_codes`)
                     `app/infrastructure/repositories/catalog/import_report_repository.rb` (`details:`)
                     `app/infrastructure/repositories/identity/audit_log_repository.rb` (`record_many`)
                     `config/routes/teams.rb` (`schools/code-regenerations`, avant `resources :schools`) · `config/initializers/imports.rb`
                     `config/locales/teams/schools.fr.yml` · `config/locales/teams/imports.fr.yml` · `config/locales/shared/common.fr.yml`
                     `config/locales/teams/school_code_regenerations.fr.yml` *(nouveau)*
- **Dépend de**    : — *(et de la réponse à Q0)*
- **Test associé** : `test/domain/policies/school/regenerate_school_codes_policy_test.rb`
                     `test/domain/dtos/school/school_selection_test.rb`
                     `test/infrastructure/repositories/school/school_repository_test.rb` (sélection identique à la liste, `created_before`, `replace_school_codes` et index unique)
                     `test/infrastructure/repositories/catalog/import_report_repository_test.rb` · `test/infrastructure/repositories/identity/audit_log_repository_test.rb`
                     `test/db/schema_constraints_test.rb` (`kind` `school_codes`, checksum nul)
                     `test/infrastructure/queries/school/schools_query_test.rb` (filtres inchangés après extraction du scope)
- **Done quand**   : les contrats de l'ADR-0096 §4.4 sont gelés et implémentés ; la liste « Établissements » filtre exactement comme avant (tests de la query verts sans modification d'attente) ; `bin/rails runner "puts Policies::School::RegenerateSchoolCodesPolicy.name, Dtos::School::SchoolSelection.name, Entities::School::CodeRegenerationCandidate.name"` passe

---

## Lot A — Lancer la régénération depuis la liste

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/use_cases/school/start_school_code_regeneration.rb`
                     `app/controllers/teams/school_code_regenerations_controller.rb` (`new`, `create`)
                     `app/views/teams/school_code_regenerations/new.html.erb` · `app/views/teams/school_code_regenerations/_form.html.erb`
                     `app/views/teams/schools/index.html.erb` (menu « Codes », UDR-0104)
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/school/start_school_code_regeneration_test.rb` (vide, nombre tapé, DRENA seule, `:conflict`, `details` sans code)
                     `test/controllers/teams/school_code_regenerations_controller_test.rb` (403 `content`/`field`/direction, 422, redirections)
                     `test/system/teams/school_code_regeneration_test.rb` (RM-01, RM-06, RM-07, RM-09 ; captures 390 px et ordinateur, menu ouvert)
- **Done quand**   : un `admin` filtre une DRENA, ouvre « Codes » → « Régénérer les codes », voit le bon nombre, confirme, et arrive sur un rapport `school_codes` en file ; sans filtre, un nombre faux est refusé avec le nombre à jour ; `content` et `field` ne voient pas le menu

---

## Lot B — Exécuter et suivre le rapport

- **Couche**       : domaine + infrastructure + ui
- **Fichiers**     : `app/domain/use_cases/school/regenerate_school_codes.rb`
                     `app/jobs/school/regenerate_school_codes_job.rb`
                     `app/views/teams/imports/show.html.erb` (ligne « Sélection », UDR-0105)
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/school/regenerate_school_codes_test.rb` (lots, déjà changés, collision et rejeu, droit retiré, compteurs, audit avec `report_public_id`)
                     `test/jobs/school/regenerate_school_codes_job_test.rb` (RM-02, RM-03, RM-04, RM-05, RM-14 sur une vraie base)
                     `test/infrastructure/import_reports_without_secrets_test.rb` (RM-12)
                     `test/controllers/teams/imports_controller_test.rb` (rapport `school_codes` : titre, compteurs renommés, aucun code)
                     `test/performance/school/regenerate_school_codes_performance_test.rb` (`PERF=1`, 3 900 établissements < 60 s)
- **Done quand**   : un rapport `school_codes` créé à la main (fabrique) est exécuté par le job ; les codes de la sélection changent, les autres non ; l'écran du rapport affiche « Codes changés / Déjà changés / En erreur » et la sélection, sans aucun code

---

## Lot C — Date du dernier changement sur la fiche

- **Couche**       : ui
- **Fichiers**     : `app/views/teams/schools/_header.html.erb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/teams/school_code_test.rb` (RM-13 : date après « Régénérer le code », absente sur un code jamais changé ; captures 390 px et ordinateur)
- **Done quand**   : la fiche d'un établissement dont le code a changé affiche « Changé le … » sous le code, y compris juste après une régénération unitaire (stream)

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/teams.rb` | Lot 0 |
| `config/initializers/imports.rb` | Lot 0 |
| `config/locales/teams/schools.fr.yml` · `teams/imports.fr.yml` · `shared/common.fr.yml` · `teams/school_code_regenerations.fr.yml` | Lot 0 |
| `db/schema.rb` | Lot 0 |
| `app/infrastructure/repositories/school/school_repository.rb` | Lot 0 |
| `app/infrastructure/repositories/catalog/import_report_repository.rb` | Lot 0 |
| `app/infrastructure/queries/school/schools_query.rb` · `school_detail_query.rb` | Lot 0 |
| `app/views/teams/schools/index.html.erb` | Lot A |
| `app/views/teams/imports/show.html.erb` | Lot B |
| `app/views/teams/schools/_header.html.erb` | Lot C |
| `test/system/teams/school_code_test.rb` | Lot C |
| `test/system/teams/school_code_regeneration_test.rb` | Lot A |

Aucun fichier n'est listé par deux lots parallèles.

## Portes de sortie

- [ ] Q0 à Q6 tranchées par le porteur ; ADR-0096 et UDR-0104 à 0106 acceptés
- [ ] Tous les lots sont `Done`
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat : parcours RM-01 → RM-02 → RM-03 → RM-13 refait dans l'application, avec des données réelles de DRENA
- [ ] Captures 390 px et ordinateur : liste avec menu « Codes » ouvert, modale (DRENA seule, et nombre à taper), rapport en cours et terminé, fiche avec la date
- [ ] Pureté du domaine, rubocop, tests, parcours système, brakeman : `bin/ci-quiet` au vert, écrit dans la PR
- [ ] Sous-agents de revue (`security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`) : une fois, sur le diff final (policy, route, use case touchés)
- [ ] Bench `PERF=1` chiffré dans `journal.md`
- [ ] ADR et UDR indexés par `script/docs/build_index` au commit de clôture ; ligne de `docs/chantiers/README.md` mise à jour à la clôture
- [ ] `journal.md` complété
