# Plan d'exécution — Import des DRENA par fichier

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Specs : [`prd.md`](prd.md) · Décisions : [ADR-0055](../../decisions/adr/0055-import-des-drena-et-slug-prefixe.md) · [UDR-0041](../../decisions/udr/0041-import-des-drena.md)

## Graphe

```
Lot 0 — SOCLE (séquentiel) : règle du slug, 5e type d'import, port, migration, schéma, locales, JSON des DRENA
  ↓
  ├─► Lot A « le slug préfixé partout »              ┐
  ├─► Lot B « importer les DRENA depuis l'écran »    ├─ en parallèle, fichiers disjoints
  └─► Lot C « fichier des établissements réécrit »   ┘
```

**Le Lot 0 gèle les contrats** : la règle `Entities::School::Drena.slug_for`, le type `drenas` du registre, et les deux méthodes ajoutées au port des DRENA. Un lot qui a besoin de changer l'un d'eux **s'arrête** et le Lot 0 rouvre. Aucun lot parallèle ne démarre avant que le Lot 0 soit mergé dans `feature/import-drenas`.

---

## Lot 0 — Socle

- **Couche**       : domaine (contrats) + infrastructure (migration, schéma, config) + fichiers partagés
- **Fichiers**     : `db/migrate/<horodatage>_add_drenas_to_import_report_kinds.rb` (contrainte `import_reports_kind_values` élargie à `drenas`, réversible)
                     `db/schema.rb`
                     `app/domain/entities/school/drena.rb` (`SLUG_PREFIX`, `self.slug_for(name)`, `key` qui s'en sert)
                     `app/domain/entities/catalog/import_kind.rb` (5e définition `drenas`, 500 lignes, `ManageSchoolPolicy`)
                     `app/domain/ports/school/drena_repository_port.rb` (contrats gelés : `insert_many(rows:, at:)` → `Integer`, `taken_names` → `Set` des noms en base ; commentaire d'en-tête « aucun import » retiré)
                     `config/schemas/lnclass.drenas.v1.json`
                     `config/initializers/imports.rb` (`"drenas" => "School::ImportDrenasJob"`)
                     `config/locales/shared/common.fr.yml` (`import_kinds.drenas`)
                     `config/locales/teams/imports.fr.yml` (`error_codes.taken`, `index.subtitle`)
                     `config/locales/teams/drenas.fr.yml` (`index.import`, `index.subtitle`, `index.empty_description`, `form.name_hint_new`, erreur « nom sans lettre latine »)
                     `config/locales/teams/import_drenas.fr.yml` (textes de l'aide `_drenas`, UDR-0041 §3 — ajouté après le lancement de la vague 2)
                     `db/seeds/data/imports/drenas-2026.json` (**déjà produit** : 41 DRENA, noms de `db/seeds/data/drenas.yml`)
                     `app/infrastructure/repositories/school/drena_repository.rb` (`taken_names`, `insert_many` — *remonté du Lot B, voir plus bas*)
                     `test/infrastructure/repositories/school/drena_repository_import_test.rb`
                     `test/domain/entities/school/drena_test.rb`
                     `test/domain/entities/catalog/import_kind_test.rb`
                     `test/db/schema_constraints_test.rb`
                     `test/domain/dtos/catalog/import_upload_input_test.rb` (prenait `drenas` pour exemple de type inconnu)
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/school/drena_test.rb` (`slug_for("Bouaké 1") == "drena-bouake-1"`, `slug_for("???")` nil) · `test/domain/entities/catalog/import_kind_test.rb` (cinq types) · `test/db/schema_constraints_test.rb` (`drenas` accepté par la contrainte)
- **Done quand**   : `bin/rails db:migrate` passe, un rapport de type `drenas` s'enregistre en base, `Entities::Catalog::ImportKind.fetch("drenas")` répond, et les contrats du port sont gelés

---

## Lot A — Le slug préfixé partout (formulaire, seeds, import des écoles)

- **Couche**       : infrastructure + domaine (DTO) + ui (aide des écoles) + données de développement
- **Fichiers**     : `app/infrastructure/orm/drena.rb` (`has_frozen_slug from: -> { Entities::School::Drena.slug_for(name) }`)
                     `app/domain/dtos/school/drena_input.rb` (nom sans lettre latine refusé)
                     `app/views/teams/imports/kinds/_schools.html.erb` (exemple `drena-abidjan-1`, `drena-abidjan-2`, rien d'autre — UDR-0041 §3)
                     `db/seeds/school.rb` (idempotence par `Entities::School::Drena.slug_for(name)`, `find_by!(slug: "drena-abidjan-2")`)
                     `test/domain/dtos/school/drena_input_test.rb`
                     `test/infrastructure/repositories/school/drena_repository_test.rb`
                     `test/infrastructure/orm/has_frozen_slug_test.rb`
                     `test/controllers/teams/drenas_controller_test.rb`
                     `test/controllers/teams/imports_controller_test.rb`
                     `test/domain/use_cases/school/create_drena_test.rb` · `update_drena_test.rb` · `delete_drena_test.rb` · `import_schools_test.rb` · `update_school_test.rb`
                     `test/domain/use_cases/catalog/run_import_test.rb`
                     `test/infrastructure/queries/school/drenas_query_test.rb` · `school_options_query_test.rb`
                     `test/jobs/school/import_schools_job_test.rb` · `test/jobs/shared/import_job_test.rb`
                     `test/performance/school/import_schools_performance_test.rb`
                     `test/fixtures/files/imports/schools_legacy_sample.json`
                     `test/db/seeds_test.rb`
                     `test/system/teams/drenas_test.rb` · `test/system/teams/import_flow_test.rb` · `test/system/school/import_schools_test.rb`
                     *et tout autre test existant qui casse parce qu'il cite un slug de DRENA non préfixé : l'agent le liste dans `journal.md` avant de le toucher, et vérifie qu'aucun autre lot ne le revendique.*
- **Dépend de**    : Lot 0
- **Test associé** : DR-01 → `test/infrastructure/repositories/school/drena_repository_test.rb` · DR-08 → `test/controllers/teams/drenas_controller_test.rb` + `test/domain/dtos/school/drena_input_test.rb` · DR-09 → `test/domain/use_cases/school/import_schools_test.rb`
- **Done quand**   : dans l'application, « Nouvelle DRENA » avec « Bouaké 1 » affiche le slug `drena-bouake-1` dans le tableau, « ??? » est refusé sous le champ, un import d'écoles qui cite `abidjan-1` note `unknown_drena` et un autre qui cite `drena-abidjan-1` passe, et `bin/rails db:seed` recrée les 41 DRENA préfixées sans doublon au second passage

---

## Lot B — Importer les DRENA depuis l'écran

- **Couche**       : domaine + infrastructure + delivery (job) + ui
- **Fichiers**     : `app/domain/use_cases/school/import_drenas.rb` (adaptateur `UseCases::Catalog::Importer`, `KIND = "drenas"`)
                     `app/jobs/school/import_drenas_job.rb`
                     `app/views/teams/imports/kinds/_drenas.html.erb`
                     `app/views/teams/drenas/index.html.erb` (bouton « Importer des DRENA » avant « Nouvelle DRENA »)
                     `test/domain/use_cases/school/import_drenas_test.rb`
                     `test/jobs/school/import_drenas_job_test.rb`
                     `test/controllers/teams/drena_imports_controller_test.rb`
                     `test/system/teams/drena_import_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : DR-02, DR-03, DR-04, DR-05, DR-06 → `test/domain/use_cases/school/import_drenas_test.rb` + `test/jobs/school/import_drenas_job_test.rb` (DR-02 lit `db/seeds/data/imports/drenas-2026.json`) · DR-07 → `test/controllers/teams/drena_imports_controller_test.rb` · DR-10 → `test/system/teams/drena_import_test.rb`
- **Done quand**   : sur l'écran des DRENA, « Importer des DRENA » (à côté de « Nouvelle DRENA ») ouvre la modale avec l'aide du format. Le téléversement de `drenas-2026.json` sur une base vide affiche un rapport « Terminé » avec 41 importées, et un second téléversement du même fichier affiche 41 ignorées

---

## Lot C — Fichier des établissements 2026 réécrit

- **Couche**       : données livrées + test de conformité
- **Fichiers**     : `db/seeds/data/imports/etablissements-2026.json` (le fichier téléversé par le porteur, 3 851 écoles, chaque `drena` remplacé par `drena-<slug>`, rien d'autre modifié)
                     `test/db/import_data_files_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : DR-11 → `test/db/import_data_files_test.rb` (les deux fichiers sont valides pour leur schéma, les 41 slugs de `drenas-2026.json` sont ceux de `Drena.slug_for`, et les 3 851 écoles citent un slug présent dans `drenas-2026.json`)
- **Done quand**   : sur une base vide, importer `drenas-2026.json` puis `etablissements-2026.json` à l'écran donne un rapport d'établissements sans aucune erreur `unknown_drena`

---

## Couverture des critères d'acceptation

| Critère | Lot | Test |
|---|---|---|
| DR-01 | A (formulaire) · B (import) | `drena_repository_test.rb` · `import_drenas_test.rb` |
| DR-02 | B | `import_drenas_test.rb`, `import_drenas_job_test.rb` |
| DR-03 · DR-04 · DR-05 · DR-06 | B | `import_drenas_test.rb` |
| DR-07 | B | `drena_imports_controller_test.rb` |
| DR-08 | A | `drenas_controller_test.rb`, `drena_input_test.rb` |
| DR-09 | A | `import_schools_test.rb` |
| DR-10 | B | `test/system/teams/drena_import_test.rb` |
| DR-11 | C | `test/db/import_data_files_test.rb` |

Aucun critère orphelin.

---

## Vérification de collision

> Faite avant de lancer les lots en parallèle. Deux lots ne listent jamais le même fichier.

| Fichier | Lot propriétaire |
|---|---|
| `config/locales/**/*.yml` (les trois fichiers touchés) | Lot 0 |
| `config/initializers/imports.rb` | Lot 0 |
| `db/migrate/…`, `db/schema.rb` | Lot 0 |
| `app/domain/entities/school/drena.rb` | Lot 0 |
| `app/domain/ports/school/drena_repository_port.rb` | Lot 0 |
| `db/seeds/data/imports/drenas-2026.json` | Lot 0 (lu par B et C, jamais modifié) |
| `app/infrastructure/orm/drena.rb` | Lot A |
| `app/infrastructure/repositories/school/drena_repository.rb` | Lot 0 — remonté du Lot B : `test/architecture/port_contracts_test.rb` exige que l'adaptateur implémente chaque méthode du port dès qu'elle est déclarée ; port et implémentation vont donc ensemble |
| `test/infrastructure/repositories/school/drena_repository_test.rb` | Lot A — les tests d'écriture en masse sont dans `drena_repository_import_test.rb` (Lot 0) |
| `test/controllers/teams/imports_controller_test.rb` | Lot A — B écrit DR-07 dans `drena_imports_controller_test.rb` |
| `test/system/teams/drenas_test.rb`, `import_flow_test.rb` | Lot A — B écrit DR-10 dans `drena_import_test.rb` |
| `app/views/teams/imports/kinds/_schools.html.erb` | Lot A |
| `app/views/teams/drenas/index.html.erb` | Lot B |
| `db/seeds/data/imports/etablissements-2026.json` | Lot C |

Contrôle mécanique (`awk … | uniq -d`) : aucune collision entre A, B et C. Aucune route n'est ajoutée : `config/routes.rb` n'est touché par aucun lot. Risque résiduel : la clause ouverte du Lot A (« tout autre test qui casse »). L'agent A ne touche jamais un fichier listé par B ou C.

## Dispatch

```
Vague 1 : Lot 0                    → 1 agent, séquentiel, sur feature/import-drenas
Vague 2 : Lot A ‖ Lot B ‖ Lot C    → 3 agents, worktrees isolés depuis feature/import-drenas
```

```bash
git worktree add ../lnclass-import-drenas-lot-a -b feature/import-drenas-lot-a feature/import-drenas
git worktree add ../lnclass-import-drenas-lot-b -b feature/import-drenas-lot-b feature/import-drenas
git worktree add ../lnclass-import-drenas-lot-c -b feature/import-drenas-lot-c feature/import-drenas
```

Ordre dans chaque lot : test rouge → `app/domain/` → `app/infrastructure/` → `app/controllers/` / jobs → vues (UDR-0041). En-tête HITL de 3 lignes sur chaque fichier créé dans `app/`. Chemins absolus, `git -C <worktree>`. Interdiction de toucher un fichier hors de son champ `Fichiers`.

Préalable d'environnement : le dépôt exige Ruby 3.4.9 (`.ruby-version`), alors que le conteneur actuel a Ruby 3.3.6 et ne peut pas lancer `bin/rails`. `bin/setup` (Ruby 3.4.9 et PostgreSQL) doit passer avant la vague 1, sinon aucun test rouge n'est possible.

---

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

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Pour ce chantier : sur une base vide, il importe `drenas-2026.json` à l'écran (41 importées), le réimporte (41 ignorées), importe `etablissements-2026.json` (aucune `unknown_drena`), puis tente un fichier qui contient « ??? » et un nom déjà pris, et vérifie les deux erreurs de ligne au rapport.
