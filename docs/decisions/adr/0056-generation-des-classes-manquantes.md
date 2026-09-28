# ADR-0056 : Les classes manquantes se génèrent après coup, en arrière-plan, pour les seuls établissements sans classe de l'année, avec un rapport d'import sans fichier

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/generer-classes`](../../chantiers/generer-classes/prd.md) |
| **Remplace** | — (amende [ADR-0030](./0030-une-ecole-par-enseignant-et-creation-des-classes.md) et [ADR-0039](./0039-format-d-import-du-contenu.md), voir §8) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0030, amendé le 2026-09-25, dit que les classes par défaut ne naissent **qu'à l'import** d'un établissement, et qu'aucune tâche ne crée de classes. Le 2026-09-28, en production, 3 851 établissements ont été importés avant le référentiel : le barème n'a rien trouvé, ces établissements n'ont aucune classe, et un réimport les ignore comme doublons (ADR-0039). Il faut une seconde porte d'entrée pour la même génération, sans rouvrir ce que l'ADR-0030 protège : un établissement qui a des classes n'est jamais régénéré.

Volume : ~3 900 établissements, ~79 000 classes.

## 2. Moteurs de décision

1. Ne jamais toucher un établissement qui a déjà des classes de l'année ; relancer sans risque.
2. Même barème et mêmes codes que l'import, sans deuxième implémentation.
3. Pas de requête HTTP longue ni de transaction géante.
4. L'équipe voit ce qui a été fait, avec les mêmes mots que pour un import.
5. Le moins de nouvelles pièces possible.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Passer par le moteur d'import (`RunImport`) avec un faux fichier | Tout est réutilisé | Le moteur lit et valide un JSON ; un faux document serait un contournement, et ses racines ne sont pas des établissements existants |
| B — Table et écran propres à la génération | Vocabulaire exact | Duplique statut, progression, compteurs, reprise des rapports bloqués, un seul en cours, écran rechargé |
| C — **Un use case propre, et le rapport des imports avec un nouveau `kind` `classrooms`, sans fichier** | Réutilise la table, l'index « un seul en cours par type », `fail_stale`, la file des jobs d'import, l'écran de suivi | Deux colonnes du rapport (fichier, checksum) n'ont pas de sens pour ce type |

Option C retenue.

## 4. Décision

> **Nous générons les classes manquantes par un job Solid Queue qui reprend `DefaultClassroomPlan` et `JoinCode.generate_unique`, lot de 200 établissements par transaction, pour les seuls établissements actifs ou brouillons sans aucune classe de l'année scolaire en cours ; son compte rendu est un `import_report` de `kind` `classrooms`, sans fichier.**

- **Candidats** : `SchoolRepositoryPort#without_classrooms(school_year:, after_id:, limit:)` — statut `active` ou `draft`, aucune classe (active ou archivée) de `school_year`, `id > after_id`, par `id` croissant. Relus lot par lot, juste avant l'écriture : un établissement doté entre-temps n'est plus candidat.
- **Écriture** (`UseCases::Classroom::GenerateMissingClassrooms`) : référentiel (`TaxonomyRepositoryPort#lookup`) et codes pris (`taken_join_codes`) chargés une fois ; par lot, `DefaultClassroomPlan.rows_for`, puis `ClassroomRepositoryPort#insert_generated` dans `TransactionPort#attempt`. Un lot refusé est rejoué établissement par établissement ; celui qui échoue encore passe en erreur (`write_failed`, chemin = nom de l'établissement).
- **Compteurs** : `imported_count` = établissements dotés ; `skipped_count` = candidats pour qui le barème ne donne aucune classe (référentiel incomplet) ; `error_count` ; `total_count` = leur somme ; `processed_count` avance à chaque lot. `details` : `classrooms_created`, et `skipped_levels` / `skipped_series` s'il y en a, cumulés par établissement comme à l'import.
- **Lancement** (`UseCases::Classroom::StartClassroomGeneration`) : `School::ManageSchoolPolicy`, libération des rapports bloqués (`fail_stale`, `StartImport::STALE_AFTER`), rapport `queued` sans checksum, job mis en file par `ImportQueuePort` (`config.x.import_jobs["classrooms"]`). Un rapport déjà en cours → `:conflict`.
- **Exécution** : `Classroom::GenerateMissingClassroomsJob` (`limits_concurrency to: 1`), qui revérifie la policy de l'auteur : un droit retiré passe le rapport `failed`. Journal `import.run`, `kind: "classrooms"`.
- **Registre** : `Entities::Catalog::ImportKind::CLASSROOM_GENERATION = "classrooms"` n'est **pas** un type d'import (pas de format, pas de téléversement) ; `ImportKind.authorize_report(kind:, actor:)` autorise la lecture d'un rapport de tout type, `REPORT_KINDS` sert au filtre de l'écran des imports.
- **Base** : la contrainte `import_reports_kind_values` accepte `classrooms` ; `checksum_sha256` devient nul, et la contrainte `import_reports_checksum_unless_generation` l'exige pour tous les autres types.

## 5. Conséquences

### 🟢 Positives

- Les 3 851 établissements reçoivent leurs classes sans réimport ni saisie.
- Relancer est sans risque : l'idempotence tient au critère de sélection, pas à une mémoire du dernier passage.
- Aucun nouvel écran : suivi, historique et filtre sont ceux des imports.

### 🔴 Coûts consentis

- Le rapport des imports porte un type qui n'est pas un import : deux colonnes restent vides pour lui, et l'écran des imports doit afficher un rapport sans fichier.
- Les compteurs « importés / ignorés » changent de sens pour ce type ; l'écran les renomme (UDR-0043).
- Un établissement doté partiellement (niveau sauté) n'est pas complété par une relance : il a des classes. On l'accepte (hors périmètre, geste « Ajouter une classe »).
- Une génération de plus de 10 minutes pourrait être déclarée bloquée par un lancement suivant ; mesuré bien en dessous sur le volume de production (journal du chantier).

## 6. Notes d'implémentation

```ruby
# app/domain/use_cases/classroom/generate_missing_classrooms.rb
batch = @schools.without_classrooms(school_year:, after_id:, limit: @batch_size)
break if batch.empty?

write_batch(batch.map { plan_for(it, school_year) }, at)
after_id = batch.last.id
```

```ruby
# app/infrastructure/repositories/school/school_repository.rb
classrooms = Orm::Classroom.where(school_year:).where("classrooms.school_id = schools.id")
Orm::School.where(status: GENERATION_STATUSES).where(id: (after_id + 1)..).where.not(classrooms.arel.exists)
           .order(:id).limit(limit).pluck(*INSERTED_COLUMNS)
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/use_cases/classroom/generate_missing_classrooms_test.rb` : lots, rejeu, compteurs, droit retiré, avec ports simulés.
- `test/infrastructure/repositories/school/school_repository_test.rb` : candidats (désactivé, classe archivée, année précédente).
- `test/system/school/generate_classrooms_test.rb` : le bouton, la confirmation, les classes créées, l'établissement déjà doté inchangé.
- `test/performance/classroom/generate_missing_classrooms_performance_test.rb` (`PERF=1`) : 500 établissements en moins de 60 s.
- `test/db/schema_constraints_test.rb` : `kind` et checksum.

## 8. Remplace, complète, amende

- **Amende l'ADR-0030** (amendement du 2026-09-25, « Quand les classes par défaut sont générées ») : en plus de l'import, les classes par défaut d'un établissement **sans aucune classe de l'année** peuvent être générées après coup par l'équipe. Un établissement qui a des classes n'est toujours jamais régénéré.
- **Complète l'ADR-0039** : `import_reports.kind` accepte `classrooms`, rapport sans fichier ni checksum, suivi par le même écran ; un seul en cours, libéré après 10 minutes comme les autres types.
