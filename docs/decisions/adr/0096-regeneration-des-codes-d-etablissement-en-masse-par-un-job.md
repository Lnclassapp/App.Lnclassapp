# ADR-0096 : Les codes d'établissement d'une sélection se régénèrent en masse par un job, suivi dans un rapport d'import sans fichier qui ne contient aucun code
<!-- index
titre: Les codes d'établissement d'une sélection se régénèrent en masse par un job, suivi dans un rapport sans fichier qui ne contient aucun code
statut: Proposé
problematique: Sélection = filtres de la liste « Établissements », rejouée par lots de 200 ; `import_reports.kind` `school_codes` ; `RegenerateSchoolCodesPolicy` (équipe `admin`) ; `ImportReportRepositoryPort#create(details:)`, trois méthodes de `SchoolRepositoryPort`, `AuditLogPort#record_many` ; confirmation tapée hors d'une DRENA. Amende 0057, 0039, 0056. Chantier `regeneration-codes-en-masse`.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/regeneration-codes-en-masse`](../../chantiers/regeneration-codes-en-masse/prd.md) — critères RM-01 à RM-14 |
| **Remplace** | — *(amende [ADR-0057](./0057-code-d-etablissement.md) : la régénération n'est plus seulement unitaire ; complète [ADR-0039](./0039-format-d-import-du-contenu.md) et [ADR-0056](./0056-generation-des-classes-manquantes.md) : un second `kind` de rapport sans fichier)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le code d'établissement (`schools.school_code`, ADR-0057) ouvre l'inscription d'une direction (ADR-0077) : jusqu'à trois comptes qui lisent les enseignants et le travail des élèves. Depuis l'ADR-0083, il ne sert plus aux enseignants, dont les liens `/i/<jeton>` sont stables et hors de ce chantier.

L'équipe ne peut le changer qu'un établissement à la fois (`School::RegenerateSchoolCode`, depuis la fiche). Le porteur veut un geste qui change d'un coup les codes de plusieurs établissements (une DRENA, ou plus). En production, il y a ~3 900 établissements et une quarantaine de DRENA :

- une requête HTTP qui change 3 900 codes et écrit 3 900 lignes d'audit dépasse le délai de Puma, et tiendrait une longue transaction sur `schools` ;
- `RegenerateSchoolCode` lit, autorise et écrit un établissement par appel : 3 900 appels feraient ~20 000 requêtes ;
- le domaine ne lit pas les queries (CQRS, ADR-0006) : la sélection de la liste (`Queries::School::SchoolsQuery#filtered`, privée) n'est pas joignable depuis un use case.

Ce chantier attend la réponse du porteur à sa question Q0 (le code est voué à disparaître dans `inscription-direction-sans-code`). Cet ADR vaut **si le chantier est gardé**.

## 2. Moteurs de décision

1. Aucune requête HTTP longue, aucune transaction géante.
2. Ce qui est confirmé est ce qui est régénéré : la même sélection que la liste à l'écran.
3. Relancer ou reprendre sans changer deux fois un même code.
4. Aucun code en clair hors de `schools` : ni dans un rapport, ni dans un journal.
5. Réutiliser le tirage, la contrainte d'unicité et l'audit de l'ADR-0057, et le suivi des imports de l'ADR-0056.

## 3. Options envisagées

**Exécution**

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Dans la requête, en appelant `RegenerateSchoolCode` par établissement | Aucun code nouveau côté domaine | ~20 000 requêtes SQL et un délai dépassé dès quelques centaines d'établissements (moteur 1) |
| B — Un job qui appelle `RegenerateSchoolCode` par établissement | Réutilise le use case tel quel | Une transaction et une ligne d'audit par établissement ; aucun compte rendu d'ensemble ; les compteurs et la reprise seraient à écrire quand même |
| C — **Un use case de masse par lots de 200, dans un job, avec un rapport `import_reports` de `kind` `school_codes`** | Le précédent de l'ADR-0056 : file, « une seule à la fois », libération après 10 minutes, écran de suivi | Retenue — une seconde implémentation du remplacement (par lot) à côté de l'unitaire |

**Sélection**

| Option | Pour | Contre |
|---|---|---|
| D — Cases à cocher dans la liste | Choix fin | Pagination de 50 lignes : « toute une DRENA » demanderait plusieurs pages ; un état de sélection à garder entre les pages |
| E — Copier les identifiants dans le rapport au lancement | Exactement ce qui a été compté | Jusqu'à 3 900 entiers dans `details` ; `finish` réécrit `details` à la fin |
| F — **Les filtres de la liste, enregistrés dans le rapport, rejoués lot par lot, bornés à `created_at <= lancement`** | Ce que l'équipe voit ; « toute une DRENA » en un filtre ; un rapport léger | Retenue — le statut d'un établissement peut changer entre la confirmation et le lot qui le lit ; le rapport compte ce qui a été fait |

## 4. Décision

> **Nous régénérons en masse les codes des établissements qui répondent aux filtres de la liste « Établissements », par un job Solid Queue qui écrit des lots de 200 établissements, chacun dans une transaction. Le compte rendu est un `import_report` de `kind` `school_codes`, sans fichier, qui garde les filtres et des compteurs, jamais un code. Seul un membre `admin` de l'équipe lance ce geste ; hors d'une seule DRENA, il tape le nombre d'établissements pour confirmer.**

### 4.1 Autorisation

`Policies::School::RegenerateSchoolCodesPolicy#call(actor:)` (**nouvelle**) : `actor.team? && actor.team_role == "admin"` → succès ; sinon `:forbidden`. `ManageSchoolStructurePolicy` (le geste unitaire) est **inchangée**.

`ImportKind::REPORT_POLICIES` associe `school_codes` à `ManageSchoolPolicy` : toute l'équipe **lit** le rapport, comme ceux des imports ; seul `admin` le **lance**.

### 4.2 Lancement — `UseCases::School::StartSchoolCodeRegeneration`

`call(actor:, dto:)`, `dto` : `Dtos::School::CodeRegenerationInput(selection:, typed_count:)`, où `selection` est un `Dtos::School::SchoolSelection(drena:, school_type:, cycle:, status:, search:)` normalisé comme les filtres de la liste (`#single_drena?` : `drena` présent).

1. Policy → `:forbidden`.
2. `fail_stale(kind: "school_codes", before: now - StartImport::STALE_AFTER, at: now)`.
3. `count = @schools.count_for_code_regeneration(selection:, created_before: now)` ; `0` → `:invalid`, `{ base: [:empty] }`.
4. Hors d'une seule DRENA : `typed_count != count` → `:invalid`, `{ typed_count: [:mismatch] }`, avec `count` dans le résultat pour le réafficher.
5. `@reports.create(kind: "school_codes", checksum_sha256: nil, imported_by_id:, at: now, details: { "selection" => selection.to_h, "expected_count" => count })` ; l'index « un seul en cours par `kind` » donne `:conflict`.
6. `@queue.enqueue(kind: "school_codes", report_id:)`.

→ `Result(ImportReport) | :forbidden | :invalid | :conflict`. Rien n'est écrit dans `schools` ici.

### 4.3 Exécution — `UseCases::School::RegenerateSchoolCodes` et `School::RegenerateSchoolCodesJob`

- Le job (`limits_concurrency to: 1`, `discard_on ActiveJob::DeserializationError`) câble le use case sur les repositories réels, comme `Classroom::GenerateMissingClassroomsJob`.
- Le use case `claim` le rapport, relit l'auteur et **revérifie la policy** : refus → rapport `failed`, rien d'écrit.
- `taken = @schools.taken_school_codes` (une fois). Puis, tant que le lot n'est pas vide :
  `batch = @schools.code_regeneration_batch(selection:, created_before: report.created_at, after_id:, limit: 200)` → `[CodeRegenerationCandidate(id, public_id, name, rotated_at)]`.
  - un candidat dont `school_code_rotated_at >= report.created_at` est compté `skipped` (« déjà changé »), sans écriture (reprise, régénération unitaire concurrente) ;
  - les autres reçoivent un code tiré par `Entities::School::SchoolCode.generate_unique(count:, taken:)` ;
  - `@transaction.attempt { @schools.replace_school_codes(rows:, at:) ; @audit_log.record_many(entries:) }` ;
  - lot refusé (`attempt` rend `:conflict` : code pris entre-temps) : rejoué établissement par établissement par `replace_school_code` (5 tirages, ADR-0057) avec sa ligne d'audit ; un échec restant compte `error`, avec le **nom** de l'établissement comme chemin (jamais le code) ;
  - `@reports.advance(id:, status: "importing", processed_count:)`.
- Fin : `finish(counts: { imported: changés, skipped: déjà changés, error: }, details: { "selection" =>, "expected_count" => }, errors:)` ; journal `import.run`, `kind: "school_codes"`.

### 4.4 Ports (gelés au Lot 0)

| Port | Méthode | Contrat |
|---|---|---|
| `Ports::School::SchoolRepositoryPort` | `count_for_code_regeneration(selection:, created_before:)` (**nouveau**) | `Integer` |
| | `code_regeneration_batch(selection:, created_before:, after_id:, limit:)` (**nouveau**) | `[Entities::School::CodeRegenerationCandidate]`, par `id` croissant, `id > after_id` |
| | `replace_school_codes(rows:, at:)` (**nouveau**) | `rows` : `[{ id:, school_code: }]` ; un seul `UPDATE … FROM (VALUES …)` qui pose aussi `school_code_rotated_at` ; `Integer` (lignes). Un code déjà pris lève l'erreur d'unicité de la base, que `TransactionPort#attempt` change en `:conflict` (`write_failed`) |
| | `replace_school_code`, `taken_school_codes` | **inchangés** |
| `Ports::Catalog::ImportReportRepositoryPort` | `create(kind:, checksum_sha256:, imported_by_id:, at:, files: [], details: {})` (**argument ajouté**, défaut vide : appelants actuels inchangés) | `Result(ImportReport)` |
| `Ports::Identity::AuditLogPort` | `record_many(entries:)` (**nouveau**) | `entries` : `[{ action:, actor_id:, at:, subject_type:, subject_id:, metadata: }]` ; un seul `insert_all` ; `Integer` |

`Entities::School::CodeRegenerationCandidate = Data.define(:id, :public_id, :name, :rotated_at)`. `Entities::Catalog::ImportKind::SCHOOL_CODE_REGENERATION = "school_codes"`, rapport sans fichier comme `CLASSROOM_GENERATION`, ajouté à `REPORT_POLICIES`. Ligne d'audit par établissement : `school.changed`, `{ change: "code_regenerated", public_id:, report_public_id: }` (même forme que l'unitaire, plus le rapport).

### 4.5 Une seule définition de la sélection

Les filtres de `Queries::School::SchoolsQuery#filtered` sont extraits dans un scope `Orm::School.list_filtered(drena:, school_type:, cycle:, status:, search:)`, utilisé par la query (liste, compte de la modale) **et** par le repository (lancement, lots). Une liste et une régénération qui divergent seraient le pire défaut de ce geste.

### 4.6 Base

Une migration : la contrainte `import_reports_kind_values` accepte `school_codes` (retrait puis ajout `NOT VALID`, puis `VALIDATE`). `import_reports_checksum_unless_generation` exempte aussi `school_codes`. Aucune colonne nouvelle : `schools.school_code_rotated_at` existe (ADR-0057).

## 5. Conséquences

### 🟢 Positives

- Une DRENA ou tout le pays change de codes en trois gestes, sans bloquer l'application.
- Relancer est sans risque : un établissement changé depuis le lancement est sauté, et un nouveau lancement ne prend que les établissements de la sélection.
- Aucun code en clair hors de `schools` : le rapport et le journal d'audit n'en portent pas, et l'écran des imports n'a pas besoin de `secret_response`.
- Suivi, historique et reprise sont ceux des imports : aucun écran nouveau.

### 🔴 Coûts consentis

- **Deux implémentations du remplacement** (unitaire et par lot) : elles partagent `SchoolCode`, l'index unique et la forme de l'audit, mais pas le code ; le test de contrat du port les met à l'épreuve ensemble.
- **Un second `kind` sans fichier** dans `import_reports` : les compteurs « importés / ignorés » changent encore de sens (« changés / déjà changés »), renommés par l'écran (UDR-0105).
- **Le nombre confirmé peut différer du nombre fait** : un établissement qui change de statut ou de DRENA entre la confirmation et son lot suit le filtre au moment du lot. Le rapport donne le nombre attendu et le nombre fait.
- **L'équipe ne voit pas les nouveaux codes d'ensemble** : pour en transmettre un, elle ouvre la fiche. Un export est un autre chantier, avec sa menace écrite.
- **Rien ne prévient** les directions ni l'équipe des codes changés ; la fiche affiche seulement la date du dernier changement (UDR-0106).
- Le geste vit tant que le code vit : `inscription-direction-sans-code` le retirera avec lui (use case, job, policy, `kind`), ce qui demandera une migration pour vider les rapports `school_codes` de la contrainte, ou les y laisser.

## 6. Notes d'implémentation

```ruby
# app/domain/policies/school/regenerate_school_codes_policy.rb
# 🧠 DOMAINE · Policies::School::RegenerateSchoolCodesPolicy
# Rôle : régénérer en masse les codes d'établissement : membre admin de l'équipe seulement
# ADR  : 0057, 0096
module Policies
  module School
    class RegenerateSchoolCodesPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team? && actor.team_role == "admin"

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
```

```ruby
# app/infrastructure/repositories/school/school_repository.rb (extrait prévu)
def replace_school_codes(rows:, at:)
  return 0 if rows.empty?

  values = rows.map { |row| Orm::School.sanitize_sql_array([ "(?::bigint, ?)", row.fetch(:id), row.fetch(:school_code) ]) }
  Orm::School.connection.exec_update(<<~SQL.squish)
    UPDATE schools SET school_code = v.code, school_code_rotated_at = #{Orm::School.connection.quote(at)}, updated_at = #{Orm::School.connection.quote(at)}
    FROM (VALUES #{values.join(', ')}) AS v(id, code) WHERE schools.id = v.id
  SQL
end
# Pas de rescue ici : l'appelant écrit dans TransactionPort#attempt, qui annule le lot et rend failure(:conflict).
```

```ruby
# config/initializers/imports.rb (ligne ajoutée)
"school_codes" => "School::RegenerateSchoolCodesJob"
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/policies/school/regenerate_school_codes_policy_test.rb` : `admin` oui ; `content`, `field`, direction, enseignant, visiteur non.
- `test/domain/use_cases/school/start_school_code_regeneration_test.rb` : sélection vide, nombre tapé faux hors DRENA, DRENA seule sans nombre, `:conflict`, `details` sans code.
- `test/domain/use_cases/school/regenerate_school_codes_test.rb` : lots, établissement « déjà changé », collision puis rejeu, droit retiré, compteurs, `record_many` appelé avec `report_public_id`.
- `test/infrastructure/repositories/school/school_repository_test.rb` : `list_filtered` identique pour la liste et les lots ; `created_before` ; `replace_school_codes` et l'index unique.
- `test/db/schema_constraints_test.rb` : `kind` `school_codes` accepté, checksum nul accepté pour lui.
- `test/system/teams/school_code_regeneration_test.rb` : RM-01, RM-06, RM-09, RM-13 dans un vrai navigateur.
- `test/performance/school/regenerate_school_codes_performance_test.rb` (`PERF=1`) : 3 900 établissements en moins de 60 s, nombre de requêtes par lot fixe.
- Garde : `test/infrastructure/import_reports_without_secrets_test.rb` : après un job, aucun `school_code` de la base n'apparaît dans `import_reports` ni dans `audit_logs.metadata`.
