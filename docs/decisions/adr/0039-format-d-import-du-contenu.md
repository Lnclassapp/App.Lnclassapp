# ADR-0039 : Imports JSON en masse — quatre formats versionnés, un job, une validation complète, un import partiel atomique par élément racine, un rapport persisté

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-17**, bloque la V1 |
| **Remplace** | [ADR-0012](./0012-deep-modules-et-strict-cqrs.md) §3.3 · [ADR-0020](./0020-optimisations-bulk-insert-donnees-catalogue.md), sauf §2.1 et §2.2 |
| **Remplacé par** | — |
| **Amendé par** | [ADR-0066](./0066-import-des-drena-et-slug-prefixe.md) |

---

> ⚠️ **Amendé par l'[ADR-0066](./0066-import-des-drena-et-slug-prefixe.md)** : les DRENA s'importent désormais (cinquième type `drenas`), et leur slug est préfixé `drena-`. Les exemples ci-dessous qui citent `abidjan-1` doivent se lire `drena-abidjan-1`.

## 1. Contexte et problématique

L'ancien importe quatre choses, chacune à sa façon (**C-18**) :

- les écoles d'une DRENA : `SchoolImportStrategy`, élément par élément, puis `GenerateDefaultClassrooms` hors transaction ;
- les cours en arbre : `bulk_import_courses`, une transaction pour tout le fichier, taxonomie créée à la volée ;
- les fiches d'un cours : dans la requête HTTP, erreurs silencieuses ;
- les exercices d'une fiche : un service « content engine » qui n'existe pas (AS-06).

Aucun ne produit de rapport. Le fichier transite par `tmp/imports/<uuid>_<nom du client>` (`securite.md` n° 28). Or l'équipe doit charger en V1 toutes les écoles du pays (environ 70 classes générées par école) et des programmes entiers.

## 2. Moteurs de décision

1. Un fichier de plusieurs milliers d'éléments s'importe sans bloquer une requête HTTP.
2. Un élément est importé entier ou pas du tout ; un élément fautif n'empêche pas les autres.
3. Rien de la taxonomie ni des DRENA ne naît d'une faute de frappe.
4. L'équipe voit, élément par élément, ce qui a été importé, ignoré ou refusé, et pourquoi.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Tout ou rien par fichier | Simple | Une faute bloque 3 000 écoles |
| B — Élément par élément, sans validation préalable | Tolérant | Lent ; aucun bilan avant écriture |
| C — **Validation complète, puis écriture partielle, atomique par élément racine** | Bilan exact ; performant ; tolérant | Deux passes sur le fichier |

Option C retenue par le porteur le 2026-09-25.

## 4. Décision

> **Nous importons quatre formats JSON versionnés par un job Solid Queue. Tout le fichier est validé avant la moindre écriture ; les éléments racines valides sont écrits par lots `insert_all`, chacun entier ou pas du tout ; les invalides et les doublons sont listés dans un rapport persisté.**

**Formats** (enveloppe `{ "format": …, "version": 1, … }`, schéma dans `config/schemas/<format>.v1.json`, gemme `json_schemer`) :

| Format | Cible | Élément racine | Contenu d'un élément |
|---|---|---|---|
| `lnclass.schools` | `drena` (slug) par défaut, ou `drena` sur chaque école | une école **et ses classes générées** (ADR-0030) | `name` \| `nom`, `sigle` \| `schoolsigle`, `status` \| `schoolstatus` \| `statut` (`draft`, `active`, `inactive` ; défaut `active`), `type` \| `schooltype` (`public`, `privée` ou `mixte` ; alias `private`, `privé`, `mixed`), stocké `public`, `private` ou `mixed`, `cycle` facultatif |
| `lnclass.course-tree` | — | un cours et toute sa descendance | l'arbre de l'ancien : `name`, `subtitle`, `content`, `level_name`, `material_name`, `series_name`, `essentials[]` → `exercises[]` → `questions[]` → `answers[]` |
| `lnclass.essentials` | `course` (slug) | une fiche et ses exercices | `name`, `subtitle`, `content`, `exercises[]` |
| `lnclass.exercises` | `essential` (slug) | un exercice, ses questions et leurs propositions | `title`, `description`, `exercise_type` (`fixation`, `evaluation`), `questions[]` → `answers[]` |

Les alias de clés de l'ancien sont acceptés en version 1 : ses fichiers s'importent une fois enveloppés. La clé `status` des contenus est ignorée : tout contenu importé naît `draft` (ADR-0035). `question_type` ∈ `true_false`, `single_choice`, `multiple_correct_2`, `multiple_correct_3`.

**Résolution, sans jamais rien créer** : DRENA, niveau, matière (ou son `shortname`) et série sont comparés, après `parameterize`, au `slug` des lignes créées par l'équipe (ADR-0034). « Physique Chimie » donne `physique-chimie`. Un nom inconnu, ou une série hors `level_series`, est une erreur de l'élément.

**Parcours** :

1. L'écran téléverse le fichier par Active Storage sur le bucket (ADR-0047) : JSON, **20 Mo au plus**. Le use case crée le rapport (`queued`) et met le job en file. La requête s'arrête là.
2. **Rejet en bloc** : JSON illisible, enveloppe ou version invalides, cible introuvable, ou nombre d'éléments racines au-delà de la limite (5 000 écoles, 500 cours, 2 000 fiches, 10 000 exercices). Rapport `rejected`, zéro écriture.
3. **Validation complète** de chaque élément racine : schéma, puis règles métier. Les règles : résolution de la taxonomie ; exactement 1 proposition correcte pour `true_false` et `single_choice`, 2 et 3 pour les deux autres ; `true_false` a exactement 2 propositions ; tout exercice a au moins une question. Chaque erreur est notée avec son chemin JSON (`schools[412].type`) et son motif.
4. **Doublons** : un élément déjà en base, ou déjà vu plus haut dans le fichier, est ignoré et compté. Clés : école `(drena, nom normalisé)` ; cours `(nom normalisé, niveau, matière, série)` ; fiche `(cours, nom normalisé)` ; exercice `(fiche, titre normalisé)`. Normaliser, c'est `squish`, minuscules, sans accents. Un import ne met jamais à jour l'existant.
5. **Écriture** des seuls éléments valides, par lots de 100 éléments racines. Chaque lot s'écrit par `insert_all` dans une transaction ; `public_id`, slugs et codes d'adhésion sont calculés avant l'insertion, uniques en base **et** dans le lot (ADR-0020 §2.2). Si un lot échoue en base, il est rejoué élément par élément, chacun dans sa transaction ; un élément qui échoue encore passe en erreur. Aucun élément n'est jamais écrit à moitié.

**Rapport** : table `import_reports` (contexte `catalog`, ADR-0027).

| Colonne | Contenu |
|---|---|
| `public_id`, `kind` | `kind` ∈ `schools`, `course_tree`, `essentials`, `exercises` |
| `status` | `queued`, `validating`, `importing`, `completed`, `rejected`, `failed` |
| fichier | pièce jointe Active Storage `source`, `checksum_sha256`, `format_version` |
| compteurs | `total_count`, `imported_count`, `skipped_count`, `error_count`, `processed_count` (progression) |
| `details` | `jsonb` : classes générées, niveaux et séries sautés (ADR-0030) |
| `errors` | `jsonb` : `[{ path:, code:, message: }]`, 1 000 entrées au plus ; au-delà, seul `error_count` avance |
| `imported_by_id` | FK `users` ; `started_at`, `finished_at` |

`total_count` = importés + ignorés + en erreur. Un seul import `queued`, `validating` ou `importing` à la fois par `kind` (index unique partiel) ; un second donne `:conflict`. Un job interrompu passe `failed` : on le relance, et ce qui était déjà écrit est compté en doublon. L'écran du rapport (`/teams/imports/:public_id`) se recharge toutes les 3 secondes tant que l'import tourne (Turbo Frame, contrôleur Stimulus), sans WebSocket. Journal : `import.run`.

**Exécution** : use cases `School::ImportSchools`, `Catalog::ImportCourseTree`, `Catalog::ImportEssentials`, `Assessment::ImportExercises` ; policies `School::ManageSchoolPolicy` et `Catalog::ManageContentPolicy` (ADR-0028) ; jobs `<Contexte>::Import…Job` sur Solid Queue (ADR-0052). L'insertion en masse vit dans les repositories (`insert_all`), jamais dans le domaine.

## 5. Conséquences

### 🟢 Positives

- C-18 est fermée : un seul modèle d'import pour les quatre formats, avec un bilan complet.
- Une faute de frappe dans une école sur 3 000 coûte cette école, pas les 2 999 autres.
- Rien d'importé n'est visible des élèves sans un geste de publication.
- Plus aucun fichier client dans `tmp/` ni nom de fichier client dans un chemin disque.

### 🔴 Coûts consentis

- Deux passes : la validation doit charger taxonomie, DRENA et clés de doublons en mémoire.
- `insert_all` contourne les validations d'ActiveRecord : le domaine valide avant, et les contraintes en base restent le dernier rempart.
- Un fichier partiellement importé se corrige en réimportant les seuls éléments en erreur ; les autres seraient ignorés en doublons.
- Une gemme de plus (`json_schemer`).

## 6. Notes d'implémentation

```json
{ "format": "lnclass.schools", "version": 1, "drena": "abidjan-1",
  "schools": [{ "name": "Lycée Classique d'Abidjan", "sigle": "LCA", "status": "active", "type": "public" },
              { "nom": "Collège Notre Dame du Plateau", "schoolsigle": "CNDP", "schooltype": "privée", "drena": "abidjan-2" }] }
```

Les fichiers de l'ancien (`.Business/content_pedagogics/DRENAS/`, `tle_d/`) servent de fixtures, enveloppés.

## 7. Comment vérifier que la décision est respectée

- Tests de use case, un fichier de fixture par cas : enveloppe invalide → `rejected` et zéro ligne ; une matière inconnue sur un cours parmi dix → neuf importés, une erreur avec son chemin ; un cours existant → ignoré ; un lot en échec en base → rejoué, aucun cours à moitié écrit.
- `test/performance/imports_test.rb`, hors suite par défaut, joué avant la recette de la V1 : 500 écoles (≈ 35 000 classes) ou 200 cours complets (8 fiches, 2 exercices par fiche, 10 questions, 4 propositions) en moins de 2 minutes en local.
- `grep -rn "find_or_create_by\|tmp/imports" app/` ne renvoie rien.

## 8. Remplace, complète, amende

- **Remplace** l'ADR-0012 §3.3 et l'ADR-0020 (C-18, C-16), mais **réhabilite** sa technique d'insertion : §2.1 (`insert_all` dans les repositories) et §2.2 (identifiants calculés avant l'insertion). Le §2.3 tombe avec les élèves démo.

## 9. Arbitrage du porteur (2026-09-25)

- Import en masse de tout le pays ou de tout un programme, dès la V1, pour les quatre formats.
- **Import partiel**, plus de tout ou rien : atomicité par élément racine, quatre compteurs, rejet en bloc réservé à l'enveloppe.
- Doublons ignorés et comptés, jamais mis à jour ; tout contenu importé naît brouillon.
- Le type d'établissement `mixte` est accepté ; les DRENA ne s'importent pas, elles se créent par le formulaire.
- Limites acceptées : 5 000 écoles, 500 cours, 2 000 fiches, 10 000 exercices par fichier ; 1 000 erreurs détaillées ; `import_reports` dans `catalog`.

## Amendement du 2026-09-25

*Chantier `docs/chantiers/boucle-pedagogique`. Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **Erratum — `errors` devient `import_errors`.** La colonne du rapport nommée `errors` au §4 s'appelle **`import_errors`** (`jsonb`, défaut `[]`, même contenu) : `ActiveModel` réserve `errors` sur tout modèle.
- **Quatre types d'import**, et pas de DRENA : `kind` ∈ `schools`, `course_tree`, `essentials`, `exercises`, garanti par la contrainte `import_reports_kind_values`.
- **Table `import_reports`**, telle que la migration `20260925100030_create_import_reports` l'implémente :
  - statuts : `queued` (défaut), `validating`, `importing`, `completed`, `rejected`, `failed`, garantis par la contrainte `import_reports_status_values` ;
  - compteurs : `total_count`, `processed_count` (progression), `imported_count`, `skipped_count`, `error_count`, tous entiers non nuls, défaut 0 ;
  - fichier : `filename`, `byte_size`, `checksum_sha256`, `format_version` (connu après lecture de l'enveloppe), et la pièce jointe Active Storage `source` ;
  - `scope` (`jsonb`) : la cible de l'import (`drena`, `course` ou `essential`) ; `details` et `import_errors` en `jsonb`.
- **Un seul import actif par type** : un index unique partiel sur `kind`, pour les statuts `queued`, `validating` et `importing` (`index_import_reports_one_running_per_kind`). Un second import du même type donne `:conflict`. Aucun index unique sur le checksum : réimporter un fichier est permis, et ses éléments déjà écrits sont comptés en doublons.
- **Jobs** : les jobs `<Contexte>::Import…Job` héritent de `Shared::ImportJob`. `config.x.import_jobs` associe chaque `kind` à son job, résolu à l'appel.
- **Test de performance par type** : `test/performance/<contexte>/import_<kind>_performance_test.rb`, un par lot d'import, au lieu du fichier unique `test/performance/imports_test.rb` du §7. Volumes et seuil inchangés. Ces tests sont hors suite par défaut et se jouent avec `PERF=1`.

## Amendement du 2026-09-27 — un import bloqué est libéré après 10 minutes

*Décision du porteur. Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **Un import qui ne progresse plus passe `failed` après 10 minutes**, au lieu de 30, et quel que soit son statut actif :
  - `validating` ou `importing` commencé depuis plus de 10 minutes (job tué, par exemple par un déploiement) ;
  - `queued` créé depuis plus de 10 minutes : le job n'a jamais été pris (worker arrêté). Avant cet amendement, un tel rapport restait en file pour toujours et bloquait tous les imports de son type.
- Le contrôle se fait au dépôt de l'import suivant du même type (`Catalog::StartImport`, `STALE_AFTER = 10 * 60`, `ImportReportRepository#fail_stale`). Un import normal dure moins de 2 minutes (§7), donc 10 minutes laissent une large marge.
- Preuves : `test/infrastructure/repositories/catalog/import_report_repository_test.rb` (les deux cas) et `test/system/error_paths_test.rb` (import interrompu, import jamais pris, par les vrais boutons).

## Amendement du 2026-09-28 — un rapport sans fichier : la génération des classes manquantes

*Chantier [`docs/chantiers/generer-classes`](../../chantiers/generer-classes/prd.md), [ADR-0056](./0056-generation-des-classes-manquantes.md). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- `import_reports.kind` accepte aussi **`classrooms`** : le rapport de la génération des classes manquantes. Ce n'est pas un type d'import (aucun format, aucun téléversement) : il n'est pas dans `ImportKind::ALL`, mais dans `ImportKind::REPORT_KINDS`.
- Ce rapport n'a ni pièce jointe ni checksum : `checksum_sha256` devient nul, et la contrainte `import_reports_checksum_unless_generation` l'exige pour tout autre type.
- Même cycle de vie que les imports : un seul en cours (index unique partiel), libéré après 10 minutes, suivi par `/teams/imports/:public_id`, journal `import.run`.
