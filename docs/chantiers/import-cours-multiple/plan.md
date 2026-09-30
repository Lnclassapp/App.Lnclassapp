# Plan d'exécution — Importer plusieurs fichiers de cours en une fois

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot 0 — SOCLE (séquentiel) : migration, registre, erreur, ports, stockage N fichiers, locales
  ↓
  ├─► Lot A « importer N fichiers en un rapport »       ┐
  ├─► Lot B « écrire un arbre de contenu plus vite »   ├─ en parallèle, fichiers disjoints
  └─► Lot C « suivi rafraîchi chaque seconde »          ┘
```

Lot B ne touche aucun fichier du Lot 0. Il pourrait partir avant lui, mais il en part après pour garder une seule base de branche.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : `db/migrate/20260930090000_add_files_to_import_reports.rb` (colonne `files` jsonb + renommage des pièces jointes `source` → `sources`)
                     `db/schema.rb`
                     `app/infrastructure/orm/import_report.rb` (`has_many_attached :sources`)
                     `app/domain/entities/catalog/import_kind.rb` (`max_files`, `max_total_bytes`, `multiple_files?`, garde « pas de cible »)
                     `app/domain/entities/catalog/import_error.rb` (`file`, motif `duplicate_in_files`)
                     `app/domain/entities/catalog/import_file.rb` (nouveau : `name`, `content`)
                     `app/domain/entities/catalog/import_report.rb` (`files`)
                     `app/domain/ports/catalog/import_file_store_port.rb` (`attach(report_id:, files:)`, `read(report_id:)` → `[ImportFile]`)
                     `app/domain/ports/catalog/import_report_repository_port.rb` (`finish(…, files:)`)
                     `app/infrastructure/repositories/catalog/import_file_store.rb`
                     `app/infrastructure/repositories/catalog/import_report_repository.rb`
                     `config/locales/catalog/imports.fr.yml` · `config/locales/teams/imports.fr.yml` *(fichiers partagés : tous les libellés du chantier)*
                     tests existants de ces fichiers, mis au nouveau contrat
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/catalog/import_kind_test.rb` · `test/domain/entities/catalog/import_error_test.rb` · `test/infrastructure/repositories/catalog/import_file_store_test.rb` · `test/infrastructure/repositories/catalog/import_report_repository_test.rb`
- **Done quand**   : les ports sont gelés, le rapport garde N fichiers et leur bilan, et **toute la suite passe** avec un import d'un seul fichier inchangé pour l'utilisateur

---

## Lot A — Importer N fichiers de cours en un seul rapport

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/dtos/catalog/import_upload_input.rb` (liste de fichiers, limites par type)
                     `app/domain/use_cases/catalog/start_import.rb`
                     `app/domain/use_cases/catalog/run_import.rb` (refus par fichier, plafond global, `duplicate_in_files`, bilan par fichier)
                     `app/controllers/teams/imports_controller.rb` (`import[files][]`)
                     `app/helpers/teams/imports_helper.rb` (`import_files_label`, motif `duplicate_in_files`)
                     `app/infrastructure/queries/catalog/import_report_query.rb` · `app/infrastructure/queries/catalog/import_reports_query.rb`
                     `app/views/teams/imports/new.html.erb` · `_status.html.erb` · `_import_errors.html.erb` · `_import_row.html.erb` · `show.html.erb` · `kinds/_course_tree.html.erb`
                     `app/javascript/controllers/teams/import_files_controller.js` (nouveau) · `app/javascript/controllers/index.js`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/catalog/run_import_test.rb` (IM-02 à IM-06, IM-08) · `test/domain/use_cases/catalog/start_import_test.rb` · `test/domain/dtos/catalog/import_upload_input_test.rb` (IM-07, IM-09) · `test/controllers/teams/imports_controller_test.rb` (IM-07, IM-09, IM-10) · `test/integration/imports_end_to_end_test.rb` (IM-01) · `test/infrastructure/queries/catalog/import_reports_query_test.rb` · `test/system/teams/import_flow_test.rb` (IM-11, IM-12)
- **Done quand**   : dans l'application, l'équipe choisit les 4 leçons de Tle D, lit « 4 fichiers · … », importe, et le suivi affiche « Terminé », 4 importés, puis une ligne par fichier. L'historique nomme l'import « … et 3 autres fichiers »

---

## Lot B — Écrire un arbre de contenu deux fois plus vite, à l'identique

- **Couche**       : infrastructure (+ banc)
- **Fichiers**     : `app/infrastructure/repositories/catalog/content_tree_writer.rb` (questions et propositions par `COPY`, contenus riches sans conversion)
                     `app/infrastructure/repositories/catalog/rich_text_sanitizer.rb` (une seule analyse)
                     `app/infrastructure/orm/rich_text_row.rb` (nouveau : écriture de `action_text_rich_texts` sans type Action Text)
                     `script/bench/import_course_tree.rb` (nouveau)
                     `test/fixtures/files/content_tree_snapshot.json` (nouveau, instantané pris **avant** l'optimisation)
- **Dépend de**    : Lot 0 (base de branche seulement)
- **Test associé** : `test/infrastructure/repositories/catalog/content_tree_writer_characterization_test.rb` (IM-13 ; écrit et vert **avant** toute optimisation) · `test/infrastructure/repositories/catalog/content_tree_writer_test.rb` (échappement `COPY`, cours entier ou absent) · `test/infrastructure/repositories/catalog/rich_text_sanitizer_test.rb`
- **Done quand**   : chiffré. Le banc donne au plus 5 s d'écriture et au plus 8 s de traitement pour 200 cours (16,5 s avant), soit au plus 20 s pour 500 cours (IM-14), et le test de caractérisation passe **inchangé**

---

## Lot C — Suivi rafraîchi chaque seconde

- **Couche**       : ui
- **Fichiers**     : `app/javascript/controllers/teams/import_status_controller.js` (`INTERVAL = 1000`)
- **Dépend de**    : Lot 0 (base de branche seulement)
- **Test associé** : `test/system/teams/import_status_refresh_test.rb` (IM-12 : le bilan d'un import terminé en arrière-plan apparaît en moins de 2 s, sans rechargement)
- **Done quand**   : chiffré. Le bilan d'un import de 10 cours s'affiche moins de 3 s après le clic sur « Importer », Solid Queue démarré (IM-14)

---

## Vagues de dispatch

```
Vague 1 : Lot 0                      → 1 exécutant, séquentiel, sur feature/import-cours-multiple
Vague 2 : Lot A ‖ Lot B ‖ Lot C      → B dans un worktree isolé (feature/import-cours-multiple-lot-b) ;
                                       A et C, qui ne partagent aucun fichier, par l'exécutant du Lot 0
Vague 3 : challenger                 → un rôle distinct, qui exécute (voir plus bas)
```

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/locales/catalog/imports.fr.yml` | Lot 0 |
| `config/locales/teams/imports.fr.yml` | Lot 0 |
| `db/schema.rb` | Lot 0 |
| `app/infrastructure/orm/import_report.rb` | Lot 0 |
| `app/domain/entities/catalog/import_error.rb` | Lot 0 (le libellé de `duplicate_in_files` est dans ses locales) |
| `app/javascript/controllers/index.js` | Lot A (seul lot qui crée un contrôleur Stimulus) |
| `app/views/teams/imports/_status.html.erb` | Lot A (Lot C ne touche que le contrôleur JS) |
| `app/infrastructure/repositories/catalog/content_tree_writer.rb` | Lot B |
| `test/fixtures/files/` | Lot B (instantané) ; Lot A crée ses fichiers de test dans `test/fixtures/files/imports/` |

Vérification mécanique (`awk … | uniq -d`) : aucun doublon entre A, B et C.

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md`
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

Critères du PRD rattachés : IM-01 → A · IM-02 → A · IM-03 → A · IM-04 → A · IM-05 → A · IM-06 → A · IM-07 → A · IM-08 → A · IM-09 → A · IM-10 → A · IM-11 → A · IM-12 → A et C · IM-13 → B · IM-14 → B et C. Aucun critère orphelin.

## Phase 5 — challenger

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Ici, il **relance lui-même le banc** (`script/bench/import_course_tree.rb`) et doit obtenir 500 cours en 20 s au plus. Il importe les 4 leçons de Tle D **en un envoi** dans l'application, puis un envoi qui mêle un fichier illisible et deux fichiers portant le même cours.
