# Plan d'exécution — Régénérer en une fois les codes d'établissement et les liens des classes

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
>
> **Amendé le 2026-10-16** après la réponse du porteur (Q0 : gardé, élargi aux liens des classes). ADR-0096 et UDR-0104 à 0106 acceptés ; les choix « à confirmer » (memo) sont appliqués. Exécuté en séquence dans une seule session (0 → A → B → C), un commit par lot.

## Graphe

```
Lot 0 — SOCLE (séquentiel) : migration, contrats, scope de sélection partagé, adaptateurs, routes, locales, docs amendées
  ↓
  ├─► Lot A « lancer depuis la liste et la fiche »          ┐
  ├─► Lot B « exécuter (moteur commun, deux jobs) et suivre » ├─ en parallèle, fichiers disjoints
  └─► Lot C « date du changement sur la fiche »             ┘
  ↓
Preuve : parcours complet RM-01 → RM-02, RM-15 → RM-18 dans l'application (A + B fusionnés)
```

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : `db/migrate/<horodatage>_add_code_regeneration_reports.rb` · `db/schema.rb`
                     `app/domain/entities/catalog/import_kind.rb` (`SCHOOL_CODE_REGENERATION`, `CLASSROOM_LINK_REGENERATION`, `REPORT_POLICIES`)
                     `app/domain/entities/catalog/import_report.rb` (`created_at`)
                     `app/domain/entities/school/regeneration_candidate.rb`
                     `app/domain/dtos/school/school_selection.rb` · `app/domain/dtos/school/code_regeneration_input.rb`
                     `app/domain/policies/school/regenerate_codes_in_bulk_policy.rb`
                     `app/domain/ports/school/school_repository_port.rb` (3 méthodes) · `app/domain/ports/classroom/classroom_repository_port.rb` (3 méthodes, `rotate_link_token` précisé)
                     `app/domain/ports/catalog/import_report_repository_port.rb` (`create(details:)`, `resume`)
                     `app/domain/ports/identity/audit_log_port.rb` (`record_many`)
                     `app/infrastructure/orm/school.rb` (scope `list_filtered`)
                     `app/infrastructure/queries/school/schools_query.rb` (scope partagé, `school_code_rotated_at`)
                     `app/infrastructure/queries/school/school_detail_query.rb` (`school_code_rotated_at`)
                     `app/infrastructure/repositories/school/school_repository.rb` · `app/infrastructure/repositories/classroom/classroom_repository.rb`
                     `app/infrastructure/repositories/catalog/import_report_repository.rb` · `app/infrastructure/repositories/identity/audit_log_repository.rb`
                     `config/routes/teams.rb` (`schools/code-regenerations`, avant `resources :schools`) · `config/initializers/imports.rb`
                     `config/locales/teams/code_regenerations.fr.yml` *(nouveau)* · `config/locales/shared/common.fr.yml`
                     memo, PRD, plan, journal ; ADR-0096 ; UDR-0104 à 0106
- **Dépend de**    : — (réponse du porteur à Q0 : reçue le 2026-10-16)
- **Test associé** : `test/domain/policies/school/regenerate_codes_in_bulk_policy_test.rb`
                     `test/domain/dtos/school/school_selection_test.rb` · `test/domain/dtos/school/code_regeneration_input_test.rb`
                     `test/infrastructure/repositories/school/school_repository_code_regeneration_test.rb` (sélection identique à la liste, `created_before`, garde, index unique)
                     `test/infrastructure/repositories/classroom/classroom_repository_link_regeneration_test.rb` (classes actives, année, garde, `rotate_link_token` date)
                     `test/infrastructure/repositories/catalog/import_report_repository_test.rb` (`details`, `resume`) · `test/infrastructure/repositories/identity/audit_log_repository_test.rb` (`record_many`)
                     `test/db/schema_constraints_test.rb` (deux `kind`, checksum nul, `link_token_rotated_at`)
                     `test/infrastructure/queries/school/schools_query_test.rb` (filtres inchangés après extraction du scope)
- **Done quand**   : les contrats de l'ADR-0096 §4.4 sont gelés et implémentés ; la liste « Établissements » filtre exactement comme avant ; `bin/rails runner` charge les constantes nouvelles

---

## Lot A — Lancer depuis la liste et la fiche

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/use_cases/school/start_code_regeneration.rb`
                     `app/infrastructure/queries/school/code_regeneration_preview_query.rb`
                     `app/controllers/teams/code_regenerations_controller.rb` (`new`, `create`) · `app/controllers/teams/schools_controller.rb` (helper)
                     `app/views/teams/code_regenerations/new.html.erb` · `app/views/teams/code_regenerations/_form.html.erb`
                     `app/views/teams/schools/index.html.erb` (menu « Codes ») · `app/views/teams/schools/_header.html.erb` (entrée ⋮, UDR-0104)
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/school/start_code_regeneration_test.rb` (deux cibles, vide, nombre tapé, DRENA seule, établissement seul, année, `:conflict`, `details` sans code)
                     `test/controllers/teams/code_regenerations_controller_test.rb` (403 `content`/`field`/direction/enseignant, 404 cible inconnue, 422, redirections)
                     `test/system/teams/code_regeneration_test.rb` (RM-01, RM-06, RM-07, RM-09, RM-15, RM-16 ; captures 390 px et ordinateur, menu ouvert)
- **Done quand**   : un `admin` filtre une DRENA, ouvre « Codes », voit le bon nombre pour chaque cible, confirme, et arrive sur un rapport en file ; depuis une fiche, idem pour les liens sans nombre à taper ; `content` et `field` ne voient ni le menu ni l'entrée

---

## Lot B — Exécuter et suivre les rapports

- **Couche**       : domaine + infrastructure + ui
- **Fichiers**     : `app/domain/use_cases/school/regenerate_in_bulk.rb` (moteur) · `app/domain/use_cases/school/regenerate_school_codes.rb`
                     `app/domain/use_cases/classroom/regenerate_classroom_links.rb`
                     `app/jobs/school/regenerate_school_codes_job.rb` · `app/jobs/classroom/regenerate_classroom_links_job.rb`
                     `app/views/teams/imports/show.html.erb` (ligne « Sélection ») · `app/views/teams/imports/_status.html.erb` (détails sans la sélection, infobulle)
                     `app/helpers/teams/code_regeneration_helper.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/school/regenerate_school_codes_test.rb` · `test/domain/use_cases/classroom/regenerate_classroom_links_test.rb` (lots, déjà changés, garde à l'écriture, collision et rejeu, droit retiré, reprise, second passage, audit)
                     `test/jobs/school/regenerate_school_codes_job_test.rb` · `test/jobs/classroom/regenerate_classroom_links_job_test.rb` (RM-02 à RM-05, RM-14, RM-17 à RM-21, RM-23, RM-24 sur une vraie base)
                     `test/controllers/teams/imports_controller_test.rb` (rapports : titre, compteurs renommés, sélection, aucun code)
                     `test/performance/school/regenerate_codes_in_bulk_performance_test.rb` (`PERF=1`)
- **Done quand**   : un rapport créé à la main (fabrique) est exécuté par chaque job ; les codes ou liens de la sélection changent, les autres non ; l'écran du rapport affiche ses compteurs et sa sélection, sans aucun code

---

## Lot C — Date du dernier changement sur la fiche

- **Couche**       : ui
- **Fichiers**     : `app/views/teams/schools/_header.html.erb` *(propriétaire : Lot A ; exécution séquentielle après A)*
- **Dépend de**    : Lot 0, Lot A
- **Test associé** : `test/system/teams/school_code_test.rb` (RM-13 : date après « Régénérer le code », absente sur un code jamais changé)
- **Done quand**   : la fiche d'un établissement dont le code a changé affiche « Changé le … » sous le code, y compris juste après une régénération unitaire (stream)

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/teams.rb` · `config/initializers/imports.rb` | Lot 0 |
| `config/locales/teams/code_regenerations.fr.yml` · `shared/common.fr.yml` | Lot 0 |
| `db/schema.rb` | Lot 0 |
| repositories (école, classe, rapports, audit) · queries de la liste et de la fiche | Lot 0 |
| `app/views/teams/schools/index.html.erb` | Lot A |
| `app/views/teams/schools/_header.html.erb` | Lot A, puis Lot C (dépendance explicite : C après A) |
| `app/views/teams/imports/show.html.erb` · `_status.html.erb` | Lot B |
| `test/system/teams/code_regeneration_test.rb` | Lot A |
| `test/system/teams/school_code_test.rb` | Lot C |

`_header.html.erb` est touché par A (entrée ⋮) et C (date) : C dépend donc de A, ils ne sont pas parallèles.

## Portes de sortie

- [x] Q0 tranchée par le porteur (2026-10-16) ; ADR-0096 et UDR-0104 à 0106 acceptés ; Q1 à Q7 appliquées, à confirmer
- [ ] Tous les lots sont `Done`
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat : parcours RM-01 → RM-02, RM-15 → RM-18 refait dans l'application
- [ ] Captures 390 px et ordinateur : liste avec menu « Codes » ouvert, modales (DRENA seule, nombre à taper, fiche), rapports
- [ ] Pureté du domaine, rubocop, tests, parcours système, brakeman : `bin/ci-quiet` au vert, écrit dans la PR
- [ ] Bench `PERF=1` chiffré dans `journal.md`
- [ ] ADR et UDR indexés par `script/docs/build_index` au commit de clôture ; ligne de `docs/chantiers/README.md` mise à jour à la clôture
- [ ] `journal.md` complété
