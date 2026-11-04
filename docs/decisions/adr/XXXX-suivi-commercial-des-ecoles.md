# ADR-XXXX : Le suivi commercial des écoles vit dans le contexte `school`, avec une étape saisie stockée et une étape affichée calculée
<!-- index
titre: Suivi commercial des écoles (CRM)
statut: Proposé
problematique: où et comment stocker la relation de l'équipe avec chaque établissement, quand une partie de son étape se lit dans l'usage réel
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-11-04 |
| **Chantier** | `docs/chantiers/crm-ecoles` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'équipe démarche les établissements de la liste nationale (importée, ADR-0028), mais rien ne garde la relation : responsable, échanges, relances. Le grill du chantier (memo, réponses 1 à 7) a fixé :

- l'étape d'une école mélange une **saisie** (Prospect, Démo faite, Abonnée, Perdue) et un **calcul** (Inscrite = au moins un compte rattaché ; Active = un geste pédagogique dans les 14 derniers jours) ;
- l'usage **ne fait que monter** l'étape ; une Abonnée inactive reste Abonnée ; une Perdue qui sert de nouveau redevient Active et le responsable est prévenu ;
- un geste pédagogique, c'est un devoir donné ou un travail rendu sur un devoir, rattaché à l'école de la classe ; une connexion ne compte pas ;
- `admin` et `field` voient tout et notent partout ; seul le responsable ou un `admin` change l'étape ; seul un `admin` change le responsable ;
- le compte d'un responsable retiré libère ses écoles (« sans responsable »), sans bloquer le retrait.

Il n'existe aujourd'hui ni table de relation, ni mécanisme d'alerte interne (aucun modèle de notification), ni passage quotidien de calcul d'usage.

## 2. Moteurs de décision

- Une étape calculée ne doit jamais diverger de l'usage réel : elle ne se stocke pas.
- Le journal est la matière première des futurs agents IA (réponse 2) : il est structuré, pas libre.
- Livrer en 8 jours ouvrés : réutiliser les tables d'usage existantes, aucun moteur d'événements.
- Pas de couplage : `classroom` et `assessment` ne connaissent pas le suivi.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Colonnes ajoutées à `schools` | Pas de jointure | Mêle la donnée d'import (référentiel) et la relation commerciale ; l'import réécrit `schools` |
| B — Étape affichée stockée, recalculée par une tâche | Lecture simple | Fausse entre deux passages ; un devoir donné à 9 h ne rend l'école Active que le lendemain |
| C — Table de relation 1-1, étape saisie stockée, étape affichée calculée à la lecture (retenue) | Toujours juste ; la règle tient dans une fonction pure testable | Une jointure sur les signaux d'usage à chaque lecture de liste |
| D — Nouveau contexte borné `crm` | Isolation | Un septième contexte pour un seul acteur ; le suivi porte sur l'établissement, que `school` possède déjà |

## 4. Décision

> **Nous ajoutons au contexte `school` quatre tables : `school_relationships` (1-1 avec `schools`, étape saisie, responsable), `school_interactions` (journal structuré), `school_follow_ups` (relances), `team_alerts` (alertes « À voir »). L'étape affichée est calculée à chaque lecture par une fonction pure du domaine, à partir de l'étape saisie et de deux signaux d'usage lus par une query. Un passage quotidien détecte la reprise d'usage d'une école perdue.**

### 4.1 Tables

| Table | Colonnes |
|---|---|
| `school_relationships` | `school_id` (unique, FK), `owner_id` (FK `users`, nullable, `on_delete: nullify`), `manual_stage` (`prospect`·`demo_done`·`subscribed`·`lost`, défaut `prospect`, CHECK), `lost_reason` (CHECK : non nul ssi `lost`), `stage_changed_at`, `public_id`, horodatages. Ligne créée à la première écriture (échange, étape, responsable) : une école sans ligne vaut Prospect sans responsable |
| `school_interactions` | `school_id`, `author_id` (nullable : passage quotidien), `kind` (`call`·`whatsapp`·`visit`·`demo`·`email`·`other` pour un échange ; `stage_changed`·`owner_changed`·`follow_up_done`·`usage_resumed`·`report_downloaded` pour une trace), `contact_name` (≤ 120), `contact_role` (≤ 80), `outcome` (`positive`·`neutral`·`negative`·`no_answer`, nullable), `lost_reason`, `note` (≤ 4 000), `details` (jsonb : ancienne et nouvelle valeur, période du rapport, texte du rapport), `occurred_at`, `public_id`. Index (`school_id`, `occurred_at desc`) |
| `school_follow_ups` | `school_id`, `assignee_id` (nullable, `on_delete: nullify`), `created_by_id`, `due_on`, `note` (≤ 500), `done_at`, `done_by_id`, `cancelled_at`, `public_id`. Index partiel sur les ouvertes (`done_at IS NULL AND cancelled_at IS NULL`) |
| `team_alerts` | `recipient_id` (FK `users`, `on_delete: cascade`), `school_id`, `interaction_id` (nullable), `kind` (`colleague_note`·`usage_resumed`), `read_at`. Index (`recipient_id`, `read_at`) |

Motifs de perte : `price`·`no_internet`·`no_devices`·`competitor`·`not_interested`·`no_answer`·`other`.

### 4.2 Étape affichée

Ordre : `prospect` < `demo_done` < `registered` < `active` < `subscribed`, et `lost` à part.

```
signals   = { accounts_count, last_teaching_act_at }   # SchoolUsageSignalsQuery
computed  = active     si last_teaching_act_at ≥ aujourd'hui − 14 j
            registered si accounts_count > 0
            nil        sinon
displayed = subscribed                       si manual = subscribed
            lost                             si manual = lost        (la reprise passe par 4.4)
            max(manual, computed)            sinon
```

Comptes rattachés : `teacher_schools`, `school_staffs` non archivés, élèves présents (`classroom_students` sans `left_at` ni `removed_at`) d'une classe de l'école. Geste pédagogique : `classroom_assignments.assigned_at`, ou `exercise_sessions.completed_at` d'une session rattachée à un `classroom_assignment` ; les deux sont rattachés à l'école par `classrooms.school_id`. `registered` et `active` ne sont jamais acceptés en saisie : le use case `ChangeStage` les refuse (`:invalid`).

### 4.3 « À relancer »

Une école figure dans la file d'un acteur (ses écoles ; un `admin` peut choisir « toutes ») pour **un** motif, le premier qui s'applique :

1. `follow_up_due` : une relance ouverte dont `due_on ≤ aujourd'hui` ;
2. `demo_stalled` : étape saisie `demo_done` et aucun échange depuis 7 jours ;
3. `inactive` : étape affichée `registered` ou `subscribed` (donc pas Active), au moins un geste pédagogique passé, le dernier il y a plus de 14 jours, et aucun échange depuis 7 jours.

La règle est une fonction pure (`Entities::School::FollowUpRule`) appliquée sur des lignes déjà filtrées en SQL par `FollowUpQueueQuery` (relances dues, démos sans échange, écoles sans geste récent). Tri : motif, puis ancienneté.

### 4.4 Passage quotidien

`School::DetectResumedSchoolsJob`, quotidien à 5 h 10 (`config/recurring.yml`), appelle `UseCases::School::DetectResumedSchools`. Pour chaque relation `lost` dont le dernier geste pédagogique est postérieur à `stage_changed_at`, il fait dans une transaction : `manual_stage = prospect`, une interaction `usage_resumed` (`details: { from: "lost", lost_reason: … }`), et une alerte `usage_resumed` pour le responsable, ou pour chaque `admin` sans responsable. La requête ne retient que les relations encore `lost` : un second passage ne fait rien.

### 4.5 Alertes

Créées par `NoteInteraction` (kind `colleague_note`) quand l'auteur n'est pas le responsable et que l'école en a un, et par 4.4. Elles se lisent sur la page Suivi (« À voir ») et se marquent lues à l'ouverture de la fiche de l'école. Il n'y a ni e-mail, ni push, ni WhatsApp (hors périmètre).

### 4.6 Responsable libéré

`UseCases::Identity::AnonymizeUser` appelle `UseCases::School::ReleaseOwnedSchools` dans sa transaction : `owner_id = nil` sur ses relations, `assignee_id = nil` sur ses relances ouvertes, et une interaction `owner_changed` par école. La clé étrangère `on_delete: nullify` couvre une suppression directe. Réattribuer (`AssignOwner`, une ou plusieurs écoles, `admin`) écrit `owner_changed` et donne au nouveau responsable les relances ouvertes sans destinataire.

## 5. Conséquences

### 🟢 Positives

- L'étape affichée est toujours juste, et le calcul tient dans une fonction testée sans base.
- Le journal structuré sert à la fois l'humain, la file « à relancer » et les assistants IA.
- `classroom` et `assessment` ne changent pas.

### 🔴 Coûts consentis

- Chaque liste joint les signaux d'usage : `SchoolUsageSignalsQuery` agrège par lot d'écoles (une requête par signal, jamais par ligne) ; la cible est ≤ 8 requêtes pour 50 lignes (PRD §7).
- `team_alerts` est une boîte de réception minimale, propre au suivi. Un futur mécanisme de notification commun devra la reprendre.
- `AnonymizeUser` (identity) appelle un use case de `school` : c'est une dépendance entre contextes, acceptée et limitée à cet appel.
- Une école retirée du référentiel garde sa relation et son journal (FK `restrict`) : la suppression d'un établissement utilisé est déjà refusée.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/school/relationship_stage.rb
module Entities
  module School
    module RelationshipStage
      ORDER = %w[prospect demo_done registered active subscribed].freeze
      ACTIVE_WINDOW_DAYS = 14

      def self.displayed(manual:, accounts_count:, last_teaching_act_at:, today:)
        return manual if %w[subscribed lost].include?(manual)

        computed = if last_teaching_act_at && last_teaching_act_at.to_date >= today - ACTIVE_WINDOW_DAYS then "active"
                   elsif accounts_count.positive? then "registered"
                   end
        [ manual, computed ].compact.max_by { ORDER.index(it) }
      end
    end
  end
end
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/school/relationship_stage_test.rb` : la table du §4.2, cas par cas, dont « connexion seule = pas Active » et « 15 jours = pas Active ».
- `test/domain/use_cases/school/change_stage_test.rb` : `active` et `registered` refusés ; `field` non responsable refusé.
- `test/domain/use_cases/school/detect_resumed_schools_test.rb` : reprise, puis idempotence.
- `test/domain/use_cases/identity/anonymize_user_test.rb` : écoles et relances libérées.
- `test/domain/domain_purity_test.rb` (pre-commit et CI) : aucune entité du suivi n'importe `Orm::`.
