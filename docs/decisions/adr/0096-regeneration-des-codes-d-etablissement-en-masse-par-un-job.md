# ADR-0096 : Les codes d'établissement et les liens des classes d'une sélection se régénèrent en masse par un job, suivi dans un rapport sans fichier qui ne contient aucun code
<!-- index
titre: Les codes d'établissement et les liens des classes d'une sélection se régénèrent en masse par un job, suivi dans un rapport sans fichier qui ne contient aucun code
statut: Accepté
problematique: Sélection = filtres de la liste « Établissements » (ou un établissement depuis sa fiche pour les classes), rejouée par lots de 200 ; deux `kind` sans fichier `school_codes` et `classroom_links`, deux jobs fins sur un moteur commun ; `RegenerateCodesInBulkPolicy` (équipe `admin`) ; garde SQL « inchangé depuis le lancement » contre la course avec le geste un par un ; `classrooms.link_token_rotated_at` ; `ImportReportRepositoryPort#create(details:)` et `#resume`, ports des écoles et des classes, `AuditLogPort#record_many`. Amende 0057, 0085, 0039, 0056. Chantier `regeneration-codes-en-masse`.
-->

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-16 : « garde la régénération des codes d'établissement et de la classe » ; les choix marqués « à confirmer » au §4.7 sont des recommandations de l'agent appliquées sans attendre)* |
| **Date** | 2026-10-16 (amendé le même jour : élargi aux liens des classes) |
| **Chantier** | [`docs/chantiers/regeneration-codes-en-masse`](../../chantiers/regeneration-codes-en-masse/prd.md) — critères RM-01 à RM-24 |
| **Remplace** | — *(amende [ADR-0057](./0057-code-d-etablissement.md) et [ADR-0085](./0085-inscription-eleve-sans-code-de-classe.md) §4.1 : le code et le lien ne se remplacent plus seulement un par un ; complète [ADR-0039](./0039-format-d-import-du-contenu.md) et [ADR-0056](./0056-generation-des-classes-manquantes.md) : deux `kind` de rapport sans fichier de plus)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Deux secrets d'accès vivent sur les établissements et les classes :

- le **code d'établissement** (`schools.school_code`, 6 symboles `^[a-hj-np-z2-9]{6}$`, ADR-0057) ouvre l'inscription d'une direction (ADR-0077) ; il est tiré par le domaine (`Entities::School::SchoolCode`) et se remplace un par un depuis la fiche (`School::RegenerateSchoolCode`, toute l'équipe, audit `school.changed`) ;
- le **jeton du lien de classe** (`classrooms.link_token`, 12 caractères hexadécimaux, ADR-0085 §4.1) fait entrer un élève dans une classe par `/c/<jeton>`, et lève même un retrait ; il est tiré par la base et se remplace un par un par « Changer le lien » (`Classroom::ChangeClassroomLink`, enseignant de la classe, direction, équipe ; sans audit). C'est le seul « code » d'une classe depuis la suppression de `join_code`.

Le porteur veut changer d'un coup ceux d'un ensemble (une DRENA, ou plus) : « garde la régénération des codes d'établissement et de la classe » (2026-10-16). En production, il y a ~3 900 établissements et de l'ordre de 60 000 classes :

- une requête HTTP qui change des milliers de lignes et écrit autant de lignes d'audit dépasse le délai de Puma, et tiendrait une longue transaction ;
- les use cases unitaires lisent, autorisent et écrivent un objet par appel : des dizaines de milliers d'appels ;
- le domaine ne lit pas les queries (CQRS, ADR-0006) : la sélection de la liste (`Queries::School::SchoolsQuery#filtered`, privée) n'est pas joignable depuis un use case ;
- le geste unitaire continue d'exister pendant qu'un job tourne : les deux peuvent viser le même établissement ou la même classe.

Le chantier `inscription-direction-sans-code`, prévu, supprimera le code d'établissement. Le porteur garde ce geste en connaissance de cause (memo, 2026-10-16) ; le §5 dit ce qu'il faudra retirer.

## 2. Moteurs de décision

1. Aucune requête HTTP longue, aucune transaction géante.
2. Ce qui est confirmé est ce qui est régénéré : la même sélection que la liste à l'écran.
3. Relancer ou reprendre sans changer deux fois un même code, et ne jamais écraser un remplacement un par un fait pendant le job.
4. Aucun code ni jeton en clair hors de `schools` et `classrooms` : ni dans un rapport, ni dans un journal.
5. Réutiliser le tirage, les contraintes d'unicité et l'audit existants, et le suivi des imports de l'ADR-0056.

## 3. Options envisagées

**Exécution**

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Dans la requête, en appelant les use cases unitaires | Aucun code nouveau côté domaine | Des dizaines de milliers de requêtes SQL ; délai dépassé dès quelques centaines d'objets (moteur 1) |
| B — Un job qui appelle les use cases unitaires | Les réutilise tels quels | Une transaction et une ligne d'audit par objet ; pas de compte rendu ; « Changer le lien » n'a pas d'audit ; compteurs et reprise à écrire quand même |
| C — **Un moteur de masse par lots de 200, dans un job, avec un rapport `import_reports` sans fichier** | Le précédent de l'ADR-0056 : file, « une seule à la fois », libération après 10 minutes, écran de suivi | Retenue — une seconde implémentation du remplacement (par lot) à côté de l'unitaire |

**Un job commun ou deux jobs**

| Option | Pour | Contre |
|---|---|---|
| D — Un seul `kind` et un seul job qui changent codes et liens ensemble | Un geste, un rapport | Les compteurs mélangent établissements et classes ; impossible de lancer l'un sans l'autre ; une collision de l'un bloque l'autre |
| E — **Deux `kind` (`school_codes`, `classroom_links`), deux jobs fins, un moteur commun** | Chaque rapport compte un seul genre d'objet ; « une seule à la fois » par genre ; le moteur (lots, reprise, compteurs, audit) est écrit une fois | Retenue — deux entrées de plus dans les registres (`ImportKind`, `config.x.import_jobs`, la contrainte de la base) |

**Sélection**

| Option | Pour | Contre |
|---|---|---|
| F — Cases à cocher dans la liste | Choix fin | Pagination de 50 lignes ; un état de sélection à garder entre les pages |
| G — Copier les identifiants dans le rapport au lancement | Exactement ce qui a été compté | Jusqu'à 60 000 entiers dans `details` |
| H — **Les filtres de la liste (ou un établissement), enregistrés dans le rapport, rejoués lot par lot, bornés à `created_at <= lancement`** | Ce que l'équipe voit ; un rapport léger | Retenue — le statut d'un établissement peut changer entre la confirmation et le lot qui le lit ; le rapport compte ce qui a été fait |

**Course avec le geste un par un**

| Option | Pour | Contre |
|---|---|---|
| I — Verrouiller chaque lot (`FOR UPDATE`) puis relire | Classique | Une seconde lecture par lot ; ne protège pas la reprise après une panne |
| J — **Garde dans l'`UPDATE` lui-même : `WHERE rotated_at IS NULL OR rotated_at < lancement`, `RETURNING id`** | Atomique (le verrou de ligne de l'`UPDATE` ordonne les deux gestes) ; la même garde sert la reprise | Retenue — demande une date de changement sur les classes (`classrooms.link_token_rotated_at`), que le geste unitaire pose aussi |

## 4. Décision

> **Nous régénérons en masse les codes des établissements, ou les liens des classes actives de ces établissements, qui répondent aux filtres de la liste « Établissements » — ou les liens des classes d'un seul établissement depuis sa fiche —, par un job Solid Queue qui écrit des lots de 200, chacun dans une transaction. Chaque genre a son `kind` de rapport sans fichier (`school_codes`, `classroom_links`) et son job ; un moteur commun les fait tourner. Le rapport garde la sélection et des compteurs, jamais un code. Seul un membre `admin` de l'équipe lance ces gestes ; hors d'une seule DRENA ou d'un seul établissement, il tape le nombre d'objets pour confirmer. Le job ne touche jamais un objet changé depuis le lancement.**

### 4.1 Autorisation

`Policies::School::RegenerateCodesInBulkPolicy#call(actor:)` (**nouvelle**, les deux gestes) : `actor.team? && actor.team_role == "admin"` → succès ; sinon `:forbidden`. `ManageSchoolStructurePolicy` (code un par un) et `ManageClassroomMembersPolicy` (lien un par un) sont **inchangées**.

`ImportKind::REPORT_POLICIES` associe `school_codes` et `classroom_links` à `ManageSchoolPolicy` : toute l'équipe **lit** les rapports, comme ceux des imports ; seul `admin` **lance**.

### 4.2 Lancement — `UseCases::School::StartCodeRegeneration`

`call(actor:, dto:)`, `dto` : `Dtos::School::CodeRegenerationInput(target:, selection:, current_year_only:, typed_count:)` ; `target ∈ { "school_codes", "classroom_links" }` ; `selection` : `Dtos::School::SchoolSelection(drena:, school_type:, cycle:, status:, search:, school:)`, normalisé comme les filtres de la liste (`school` : `public_id` d'un établissement ; présent, il remplace les filtres) ; `#scoped?` : `drena` ou `school` présent.

1. Policy → `:forbidden`.
2. `count` : `schools.count_for_code_regeneration(selection:, created_before: now)` ou `classrooms.count_for_link_regeneration(selection:, school_year:, created_before: now)`, avec `school_year = SchoolYear.current(now)` si `current_year_only`, sinon `nil` (toutes années). `0` → `:invalid`, `{ base: [:empty] }`.
3. Hors d'une sélection `scoped?` : `typed_count != count` → `:invalid`, `{ typed_count: [:mismatch] }`, avec le nombre dans `Result#value` pour le réafficher.
4. `fail_stale(kind: target, before: now - StartImport::STALE_AFTER, at: now)` (jugé sur `updated_at`), **après** la validation : un nombre refusé ne touche aucun rapport.
5. `reports.create(kind: target, checksum_sha256: nil, imported_by_id:, at: now, details: { "selection" => selection.to_h.merge("school_year" => school_year), "expected_count" => count })` ; l'index « un seul en cours par `kind` » donne `:conflict`.
6. `queue.enqueue(kind: target, report_id:)` ; `false` → rapport `failed` (motif `not_enqueued`) et `:unavailable` (§4.8).

→ `Result(ImportReport) | :forbidden | :invalid | :conflict | :unavailable`. Rien n'est écrit dans `schools` ni `classrooms` ici.

### 4.3 Exécution — moteur `UseCases::School::RegenerateInBulk`

Classe de base du domaine ; deux use cases concrets : `UseCases::School::RegenerateSchoolCodes` et `UseCases::Classroom::RegenerateClassroomLinks`. Deux jobs fins (`School::RegenerateSchoolCodesJob`, `Classroom::RegenerateClassroomLinksJob`, `limits_concurrency to: 1, duration: STALE_AFTER` (le verrou tombe avec la limite d'un rapport sans signe de vie), `discard_on ActiveJob::DeserializationError`) les câblent sur les repositories réels.

- `claim` le rapport ; s'il est déjà pris, `resume` (rapport `validating` ou `importing` d'un job que Solid Queue relance **après un arrêt propre** du processus) ; sinon `:conflict` (`already_claimed`) et rien n'est écrit : **exécuter deux fois le même rapport ne change rien de plus**.
- **Un processus tué net n'est pas rejoué** (Solid Queue 1.7 ne relance qu'après un arrêt propre) : le rapport reste `importing`. Il est dit **bloqué** à l'écran dès que son `updated_at` (rafraîchi à chaque lot) dépasse `STALE_AFTER`, sans attendre un nouveau lancement, et passé `failed` (`fail_stale`, jugé sur `updated_at`) au prochain lancement du même genre, **après** la validation de ce lancement. `advance` et `finish` ne touchent qu'un rapport encore en cours et rendent `false` sinon : le moteur s'arrête alors, sans rien écrire de plus.
- Relit l'auteur et **revérifie la policy** : refus (droit retiré, ou compte anonymisé — `actor_for` ne rend alors aucun acteur) → rapport `failed` **avec son motif** (`ImportError` `forbidden`, affiché dans le rapport), rien d'écrit.
- `launched_at = report.created_at`. Puis, tant que le lot n'est pas vide : `batch` (candidats `Entities::School::RegenerationCandidate(id, public_id, label, school_id, rotated_at)`, par `id` croissant) ;
  - un candidat dont `rotated_at >= launched_at` est compté `skipped` (« déjà changé »), sans écriture ;
  - les autres sont écrits par `@transaction.attempt { ids = replace(...) ; @audit_log.record_many(entries: lignes des ids écrits) }` ; la garde SQL (§4.4) écarte un candidat changé entre la lecture et l'écriture : il est compté `skipped` ;
  - lot refusé : rejoué objet par objet ; un objet n'est rejoué (5 tirages au plus, ADR-0057) que sur **collision** (`RecordNotUnique`, code ou jeton déjà pris) ; toute autre cause (`TransactionPort#attempt_with_cause`) : une seule tentative, un `Rails.logger.warn` avec le `public_id` du rapport et le libellé de l'objet, jamais le code ; un échec restant compte `error` (`write_failed`, avec la classe de l'exception), avec le **libellé** de l'objet comme chemin (nom de l'établissement, ou « établissement · classe »), jamais un code ;
  - `@reports.advance(id:, status: "importing", processed_count:)`.
- Fin : `finish(counts: { imported: changés, skipped: déjà changés, error: }, details: ceux du lancement, errors:)` ; journal `import.run` avec le `kind`.
- **Codes d'établissement** : `taken = schools.taken_school_codes` (une fois) ; codes tirés par `SchoolCode.generate_unique(count:, taken:)` ; `replace_school_codes(rows:, at:, unchanged_since: launched_at)`.
- **Liens des classes** : `rotate_link_tokens(ids:, at:, unchanged_since: launched_at)` ; les jetons sont tirés par la base (`LINK_TOKEN_SQL`, ADR-0085 §4.1), une collision de l'index unique est rejouée comme ci-dessus.

### 4.4 Ports (gelés au Lot 0)

| Port | Méthode | Contrat |
|---|---|---|
| `Ports::School::SchoolRepositoryPort` | `count_for_code_regeneration(selection:, created_before:)` (**nouveau**) | `Integer` |
| | `code_regeneration_batch(selection:, created_before:, after_id:, limit:)` (**nouveau**) | `[RegenerationCandidate]`, `id > after_id`, par `id` croissant, `label` = nom, `rotated_at` = `school_code_rotated_at` |
| | `replace_school_codes(rows:, at:, unchanged_since:)` (**nouveau**) | `rows` : `[{ id:, school_code: }]` ; un seul `UPDATE … FROM (VALUES …) … WHERE school_code_rotated_at IS NULL OR school_code_rotated_at < unchanged_since RETURNING id` qui pose `school_code_rotated_at = at` ; → `[Integer]` (ids écrits). Un code pris lève l'erreur d'unicité, que `TransactionPort#attempt` change en `:conflict` |
| | `replace_school_code`, `taken_school_codes` | **inchangés** |
| `Ports::Classroom::ClassroomRepositoryPort` | `count_for_link_regeneration(selection:, school_year:, created_before:)` (**nouveau**) | `Integer` ; classes `active` des établissements de la sélection ; `school_year` `nil` = toutes années |
| | `link_regeneration_batch(selection:, school_year:, created_before:, after_id:, limit:)` (**nouveau**) | `[RegenerationCandidate]`, `label` = « établissement · classe », `rotated_at` = `link_token_rotated_at` |
| | `rotate_link_tokens(ids:, at:, unchanged_since:)` (**nouveau**) | un seul `UPDATE … SET link_token = LINK_TOKEN_SQL, link_token_rotated_at = at … WHERE status = 'active' AND (link_token_rotated_at IS NULL OR < unchanged_since) RETURNING id` ; → `[Integer]` |
| | `rotate_link_token(id:)` | **précisé** : pose aussi `link_token_rotated_at` (le geste unitaire ne change pas pour l'utilisateur) |
| `Ports::Catalog::ImportReportRepositoryPort` | `create(kind:, checksum_sha256:, imported_by_id:, at:, files: [], details: {})` (**argument ajouté**, défaut vide) | `Result(ImportReport)` |
| | `resume(id:, at:)` (**nouveau**) | `UPDATE … SET started_at = at WHERE status IN ('validating','importing')` → `Boolean` |
| `Ports::Identity::AuditLogPort` | `record_many(entries:)` (**nouveau**) | `entries` : `[{ action:, actor_id:, at:, subject_type:, subject_id:, metadata: }]` ; actions vérifiées comme `record` ; un seul `insert_all` ; `Integer` |

`Entities::Catalog::ImportReport` gagne `created_at` (défaut `nil`). `Entities::Catalog::ImportKind::SCHOOL_CODE_REGENERATION = "school_codes"` et `CLASSROOM_LINK_REGENERATION = "classroom_links"`, rapports sans fichier comme `CLASSROOM_GENERATION`, ajoutés à `REPORT_POLICIES`.

Audit, une ligne par objet changé, **sans code ni jeton** :

- établissement : `school.changed`, sujet `School`, `{ change: "code_regenerated", public_id:, report_public_id: }` (forme de l'unitaire, plus le rapport) ;
- classe : `school.changed`, sujet `School` (son établissement), `{ change: "classroom_link_changed", classroom_public_id:, report_public_id: }` (forme de l'archivage d'une classe). « Changer le lien » un par un reste **sans** audit.

### 4.5 Une seule définition de la sélection

Les filtres de `Queries::School::SchoolsQuery#filtered` sont extraits dans un scope `Orm::School.list_filtered(drena:, school_type:, cycle:, status:, search:)`, utilisé par la query (liste), par la query du compte de la modale et par les repositories (lancement, lots). Les classes sont `Orm::Classroom.where(status: "active", school_id: <établissements de la sélection>)`. Une liste et une régénération qui divergent seraient le pire défaut de ce geste.

### 4.6 Base

Une migration :

- la contrainte `import_reports_kind_values` accepte `school_codes` et `classroom_links` ; `import_reports_checksum_unless_generation` les exempte du checksum ;
- `classrooms.link_token_rotated_at` (`datetime`, nul : jamais changé).

### 4.7 Choix à confirmer par le porteur

Appliqués sans attendre : `admin` seulement ; ni affichage ni export en masse des nouveaux codes et liens ; aucune notification ; gestes un par un inchangés ; l'ancien lien de classe cesse aussitôt de marcher ; classes archivées non touchées ; option « année en cours seulement » cochée par défaut.

### 4.8 Corrections après revue (2026-10-19)

- **Rapport bloqué** : un processus tué net ne rejoue rien (§4.3). L'écran dit « bloqué » dès que `updated_at` dépasse `STALE_AFTER` (message : relancer depuis la liste ; les codes déjà changés le seront de nouveau) ; `fail_stale` juge sur `updated_at` et non `started_at`, et n'est appelé qu'après la validation du lancement ; `limits_concurrency` des deux jobs porte `duration: STALE_AFTER`.
- **Rapport `failed`** : l'écran garde les compteurs et la liste des motifs ; le droit retiré ou le compte anonymisé de l'auteur y laisse le motif `forbidden` ; une mise en file refusée, le motif `not_enqueued`.
- **Mise en file refusée** : `ImportQueuePort#enqueue` rend `false` quand `perform_later` rend `false` (ActiveJob 8.1 avale l'`EnqueueError`) ; le lancement passe alors le rapport `failed` et rend `:unavailable`, septième code de `Shared::Result` (amende l'ADR-0026).
- **Compte anonymisé** : `UserRepositoryPort#actor_for` ne rend aucun acteur pour un compte anonymisé ; la policy le refuse comme un visiteur.

## 5. Conséquences

### 🟢 Positives

- Une DRENA ou tout le pays change de codes, ou de liens de classes, en trois gestes, sans bloquer l'application.
- **Reprendre le même rapport** est sans risque : un objet changé depuis le lancement — par le job lui-même avant une panne, ou un par un pendant le job — est sauté, et la garde est dans l'`UPDATE`, pas dans une lecture préalable. **Relancer après un arrêt** (rapport `failed`, nouveau rapport, nouveau `created_at`) change de nouveau ce qui l'avait déjà été : l'écran le dit.
- Aucun code ni jeton hors de leurs tables : le rapport et le journal n'en portent pas ; l'écran des imports n'a pas besoin de `secret_response`.
- Suivi, historique et reprise sont ceux des imports : aucun écran de suivi nouveau.

### 🔴 Coûts consentis

- **Deux implémentations du remplacement** (unitaire et par lot) pour chaque genre : elles partagent le tirage, l'index unique et la forme de l'audit, pas le code.
- **Deux `kind` sans fichier de plus** dans `import_reports` : les compteurs « importés / ignorés » prennent encore d'autres sens (« changés / déjà changés »), renommés par l'écran (UDR-0105).
- **Le nombre confirmé peut différer du nombre fait** : un objet qui change de statut ou de DRENA entre la confirmation et son lot suit le filtre au moment du lot. Le rapport donne le nombre attendu et le nombre fait.
- **L'équipe ne voit pas les nouveaux codes ni liens d'ensemble** : un code se lit sur la fiche, un lien sur la page de la classe. Un export est un autre chantier, avec sa menace écrite.
- **Rien ne prévient** les directions, enseignants ni élèves ; un élève qui ouvre un ancien lien arrive sur l'inscription standard.
- **Asymétrie d'audit** : la masse écrit une ligne par classe, « Changer le lien » un par un n'en écrit pas.
- **Le code d'établissement est voué à disparaître** : `inscription-direction-sans-code` retirera la moitié `school_codes` (use case, job, `kind`, entrée de menu, UDR-0106) ; une migration videra les rapports `school_codes` de la contrainte ou les y laissera. La moitié `classroom_links` et le moteur restent.

## 6. Notes d'implémentation

```ruby
# app/domain/policies/school/regenerate_codes_in_bulk_policy.rb
module Policies
  module School
    class RegenerateCodesInBulkPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team? && actor.team_role == "admin"

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
```

```ruby
# config/initializers/imports.rb (lignes ajoutées)
"school_codes" => "School::RegenerateSchoolCodesJob",
"classroom_links" => "Classroom::RegenerateClassroomLinksJob"
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/policies/school/regenerate_codes_in_bulk_policy_test.rb` : `admin` oui ; `content`, `field`, direction, enseignant, élève, visiteur non.
- `test/domain/use_cases/school/start_code_regeneration_test.rb` : les deux cibles, sélection vide, nombre tapé faux hors DRENA, DRENA seule et établissement seul sans nombre, année en cours, `:conflict`, `details` sans code.
- `test/domain/use_cases/school/regenerate_school_codes_test.rb` et `test/domain/use_cases/classroom/regenerate_classroom_links_test.rb` : lots, « déjà changé », garde au moment de l'écriture, collision puis rejeu, droit retiré, reprise d'un rapport pris, second passage sans effet, `record_many` avec `report_public_id`.
- `test/infrastructure/repositories/school/school_repository_code_regeneration_test.rb` et `test/infrastructure/repositories/classroom/classroom_repository_link_regeneration_test.rb` : sélection identique à la liste, `created_before`, garde `unchanged_since`, index unique.
- `test/jobs/school/regenerate_school_codes_job_test.rb` et `test/jobs/classroom/regenerate_classroom_links_job_test.rb` : bout en bout sur une vraie base ; aucun code ni jeton dans `import_reports` ni dans `audit_events.metadata`.
- `test/support/fake_transaction.rb`, `test/infrastructure/repositories/shared/transaction_test.rb` : collision ou autre refus, rejeu ou non ; `test/infrastructure/repositories/catalog/import_report_repository_test.rb` : `fail_stale` sur `updated_at`, `advance` et `finish` d'un rapport encore en cours ; `test/controllers/teams/imports_controller_test.rb` : rapport bloqué, rapport échoué avec ses compteurs et son motif ; `test/integration/school/code_regeneration_end_to_end_test.rb` : l'ancien code et l'ancien lien ne marchent plus.
- `test/db/schema_constraints_test.rb` : les deux `kind` acceptés, checksum nul pour eux, `link_token_rotated_at` nul.
- `test/system/teams/code_regeneration_test.rb` : lancement depuis la liste et depuis la fiche, nombre tapé, rapport.
