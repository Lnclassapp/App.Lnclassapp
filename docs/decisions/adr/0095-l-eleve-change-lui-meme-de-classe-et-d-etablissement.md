# ADR-0095 : L'élève qui a une classe active en change lui-même, vers une classe de son établissement ou d'un autre, sans validation ; l'ancienne adhésion est close, jamais retirée
<!-- index
titre: L'élève change lui-même de classe ou d'établissement, sans validation ; l'ancienne adhésion est close, pas retirée
statut: Accepté *(porteur, 2026-10-16)* — *amende 0040 (élève connecté à classe active), 0085 §4.3 (JoinAsStudent)*
problematique: `UseCases::Classroom::ChangeClassroom` pour l'élève à classe active ; cascade ou lien ; confirmation explicite ; `left_at` sans `removed_at` sur l'ancienne adhésion, nouvelle adhésion principale dans la même transaction ; résultats sur l'élève ; trace `classroom.student_moved`
-->

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-16 : recommandations du memo ; l'élève seul déclenche le changement)* |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/changement-etablissement-eleve`](../../chantiers/changement-etablissement-eleve/memo.md) |
| **Remplace** | — *(amende ADR-0040 §4 « Règles de la V1 » et §5 « Coûts consentis » ; ADR-0085 §4.3)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0040 limite l'élève à **une seule classe principale active** (index partiel `index_classroom_students_one_active_primary`) et pose une règle de la V1 : un élève connecté qui a une classe active reçoit un refus (« Tu es déjà inscrit dans une classe ») quand il essaie d'en rejoindre une autre. Il prévoyait que le changement de classe en cours d'année passerait « par l'enseignant ou l'équipe », livré avec l'archivage de la V3.

Ce qui existe le 2026-10-16 :

- `UseCases::Classroom::JoinAsStudent` ne sert que l'élève **sans** classe active (classe archivée, ADR-0088 ; ou retiré, ADR-0085 §4.5). Il refuse l'élève dont la classe est active (`already_enrolled`), quelle que soit la classe visée, par la cascade comme par le lien.
- `UseCases::Classroom::RemoveStudent` (enseignant de la classe, direction, équipe) pose `left_at` et `removed_at`. L'élève retiré tombe sur « Choisis ta classe » et peut alors entrer dans **n'importe quelle** classe, d'un autre établissement compris, sauf celle dont il a été retiré.
- Le seul chemin d'un changement d'établissement est donc : quelqu'un qui gère l'**ancienne** classe retire l'élève, puis l'élève choisit sa nouvelle classe. Or la plupart des classes n'ont ni enseignant ni direction sur Lnclass (c'est la raison d'être de l'ADR-0085). L'élève qui déménage, ou qui s'est trompé de classe à l'inscription, reste bloqué.
- Le même blocage attend la rentrée : `Membership#classroom_active?` ne lit que `classrooms.status`, pas l'année scolaire. Un élève dont la classe de l'an dernier n'est pas archivée ne peut pas choisir une classe de l'année (la cascade ne propose que l'année courante).

L'adhésion sait déjà tout ce qu'il faut : une ligne par élève et par classe, jamais supprimée, `left_at` pour le départ, `removed_at` pour le retrait, et des résultats rattachés à l'élève (`exercise_sessions.student_id`) et à l'assignation, pas à l'adhésion (ADR-0036).

## 2. Moteurs de décision

1. **Aucune étape ne dépend d'un acteur qui n'est peut-être pas sur Lnclass** (même moteur que l'ADR-0085 §2) : ni l'ancien enseignant, ni la nouvelle direction.
2. **Ne rien perdre** : historique, résultats, lacunes de remédiation, adhésions passées (ADR-0036).
3. **Garder les invariants** : une classe principale active au plus (ADR-0040), plafond et verrou de la classe (ADR-0041), refus d'une classe archivée (ADR-0088), retrait levé par le seul lien (ADR-0085 §4.3).
4. **Pas plus d'exposition qu'aujourd'hui** : entrer dans une classe est déjà ouvert à tout visiteur qui crée un compte (ADR-0085 §5) ; changer de classe ne doit pas ouvrir davantage.
5. **Un geste volontaire** : un élève ne change pas de classe par mégarde, en suivant un lien ou en touchant une case.

## 3. Options envisagées

### Qui déclenche

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — **L'élève lui-même** | Marche sans enseignant ni direction ; même logique que l'inscription (ADR-0085) | Un élève peut quitter sa classe sans que personne le sache : protection a posteriori seulement |
| B — Qui gère l'ancienne classe le retire, l'élève choisit ensuite | Existe déjà, aucun code | Bloque l'élève de toute classe sans enseignant ni direction ; marque l'élève « retiré » alors qu'il est parti |
| C — La nouvelle direction ou le nouvel enseignant « tire » l'élève | Contrôle à l'arrivée | Il faut chercher un élève d'un autre établissement par son numéro : fuite de données ; bloque si personne n'est sur Lnclass |
| D — Demande de l'élève, validée par la nouvelle direction | Protège avant l'entrée | Même impasse que l'option C de l'ADR-0085 (demande en attente écartée au grill d'`inscription-eleve-sans-code`) ; la direction n'a pas de compte dans la plupart des établissements |

### Ce que devient l'ancienne adhésion

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — **`left_at` seul** (comme `leave_primary` aujourd'hui) | Aucune colonne ; l'élève peut revenir par la voie standard ; les lectures « présents » l'écartent déjà | On ne distingue pas, en base, un départ volontaire d'un départ par archivage : la trace d'audit le dit |
| B — `left_at` + `removed_at` (retrait) | Réutilise `RemoveStudent` | L'élève serait « retiré » de sa propre initiative et ne pourrait plus revenir sans le lien |
| C — Colonne `left_reason` | Lisible en base | Une migration et un `CHECK` pour une information qu'aucun écran ne lit ; reportable sans perte, la trace d'audit la porte |

### Use case

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Lever le refus `already_enrolled` de `JoinAsStudent` | Un seul use case | Le choix d'une case ou l'ouverture d'un lien déplacerait l'élève sans qu'il l'ait voulu : le moteur 5 tombe |
| B — **Nouveau use case `ChangeClassroom`, appelé seulement après confirmation** | Intention explicite ; `JoinAsStudent` garde son contrat | Deux use cases qui partagent `ClassroomDesignation` et la séquence « clore puis ouvrir » |

## 4. Décision

> **Nous permettons à l'élève qui a une classe principale active d'en changer lui-même, vers n'importe quelle classe que la cascade lui propose (son établissement ou un autre) ou vers celle d'un lien valide, après une confirmation explicite. Il n'y a ni demande ni validation. L'ancienne adhésion est close (`left_at`), jamais marquée retirée ; la nouvelle est ouverte dans la même transaction. Les résultats restent à l'élève.**

### 4.1 Use case

- `UseCases::Classroom::ChangeClassroom#call(actor:, dto:)`, `dto` = `Dtos::Classroom::StudentRegistrationInput` (voie `link` si `link_token`, sinon voie `standard` par la cascade), comme `JoinAsStudent`.
- Refus, dans l'ordre :
  - acteur qui n'est pas élève → `:forbidden` ;
  - élève **sans** classe active → `:forbidden`, `base: [:no_active_classroom]` (il passe par « Choisis ta classe », `JoinAsStudent`) ;
  - classe désignée = sa classe actuelle → `:invalid`, `base: [:same_classroom]` ;
  - `ClassroomDesignation` : classe hors cascade (`:invalid`), lien mort (`:not_found`), lien d'une classe archivée (`:forbidden`, `classroom_archived`) ;
  - `Policies::Classroom::JoinPolicy` inchangée : archivée, complète, retiré de cette classe sans le lien.
- *Exécution (2026-10-16)* : la classe d'arrivée est désignée (et verrouillée) **avant** la lecture de la classe actuelle. Un second envoi simultané vers la même classe attend le premier sous le verrou, lit alors la nouvelle classe et reçoit `same_classroom` : rien de plus n'est écrit. L'élève sans classe active n'atteint pas l'envoi (le contrôleur le renvoie à « Choisis ta classe ») ; s'il l'atteint, une classe mal désignée passe avant `no_active_classroom`.
- `ClassroomDesignation#designate(dto)` porte le choix « lien ou cascade » et le refus du lien mort ou archivé, partagés avec `JoinAsStudent`.
- Dans une transaction, sous le verrou de la classe d'arrivée (pris par `ClassroomDesignation`) :
  1. `memberships.leave_primary(student_id:, at: now)` ;
  2. `memberships.add_primary(classroom_id:, student_id:, via:, at: now)` — rouvre une ancienne adhésion à cette classe s'il en a une ;
  3. `audit_log.record(action: "classroom.student_moved", actor_id: élève, subject_type: "User", subject_id: élève, metadata: { from_classroom_id:, to_classroom_id:, to_school_id:, via: })`.
     *Exécution (2026-10-16)* : identifiants internes, comme les autres traces (`school_id` d'`invite_school_staff`) ; l'établissement de départ se lit par `from_classroom_id`. Les identifiants publics auraient demandé une lecture de plus de la classe quittée, que `MembershipRepositoryPort` ne donne pas.
- Un échec de l'étape 2 annule l'étape 1 (même mécanisme `Aborted` que `JoinAsStudent`).
- `→ success(Entities::Classroom::Classroom)` (la classe d'arrivée).
- Le port `MembershipRepositoryPort` ne change pas. `Entities::Identity::AuditAction::ALL` reçoit `classroom.student_moved`.

### 4.2 Ce que devient la classe d'origine

- L'adhésion reçoit `left_at`. **Ni `removed_at` ni `removed_by_id`** : l'élève peut revenir plus tard par la voie standard ; s'il revient, la même ligne est rouverte (`add_primary`).
- Il sort aussitôt de toutes les lectures « présents » de l'ancienne classe (liste, effectif, suivi des devoirs, rapports, « Fait seul », accueil de l'enseignant), comme un élève retiré : ces lectures filtrent déjà `left_at IS NULL`.
- La direction de l'ancien établissement le retrouve dans « Anciens élèves », avec ses résultats obtenus chez elle (`DepartedStudentsQuery`, inchangée).
- Une séance commencée dans l'ancienne classe garde son `classroom_assignment_id` ; terminée après le départ, elle reste dans l'historique de l'élève et ne compte pas dans le taux de rendu de l'ancienne classe (règle « présents », ADR-0072 §4.4).

### 4.3 Résultats et données de l'élève

- Rien n'est copié, déplacé ni effacé. Les séances, badges, lacunes de remédiation (`knowledge_gaps`, par élève) et l'historique suivent l'élève.
- Le nouvel enseignant voit l'élève dans sa liste, marqué « nouveau » 7 jours (ADR-0085 §4.4) avec sa voie (`standard` ou `link`). Ses suivis ne comptent que les assignations de sa classe : il ne voit pas les résultats obtenus ailleurs.
- `joined_via` ne reçoit pas de nouvelle valeur : la voie dit comment l'élève est arrivé dans la classe, pas d'où il vient.

### 4.4 Garde-fous

- **Confirmation obligatoire** : le use case n'est appelé que par l'envoi de la page de confirmation (UDR-0102). Choisir une case ou ouvrir un lien n'écrit rien.
- **Débit** : 5 envois par minute et par compte sur l'action de changement, comme l'inscription.
- **Trace** : `classroom.student_moved` dans le journal d'audit (`Entities::Identity::AuditAction`), lisible par l'équipe.
- **Pas de quota** de changements par an : un abus se voit dans le journal et se traite par le retrait existant.

### 4.5 Ce qui change dans les ADR existants

- **ADR-0040 §4, « Règles de la V1 »** : la règle « un élève connecté qui a une classe principale active reçoit `:conflict` » ne vaut plus que pour `JoinAsStudent` et `/c/<jeton>` **sans confirmation**. Avec confirmation, il change de classe par `ChangeClassroom`.
- **ADR-0040 §5, « Coûts consentis »** : « Un élève qui change de classe en cours d'année passe par l'enseignant ou l'équipe » est remplacé par le présent ADR.
- **ADR-0085 §4.3** : `JoinAsStudent` reste réservé à l'élève sans classe active ; l'élève à classe active passe par `ChangeClassroom`.

### 4.6 Ce qui ne change pas

- L'index partiel « une principale active » (ADR-0040) ; le schéma de `classroom_students` : **aucune migration**.
- `JoinPolicy`, le plafond et le verrou (ADR-0041), le refus d'une classe archivée (ADR-0088), le retrait et sa levée par le lien (ADR-0085).
- L'élève ne garde qu'**une** classe : pas d'adhésion secondaire (`multi-classes-eleve`, V3, Q5 de la feuille de route).

## 5. Conséquences

### 🟢 Positives

- L'élève qui déménage, qui change d'établissement ou qui s'est trompé de classe à l'inscription se débloque seul, en deux écrans.
- À la rentrée, l'élève dont la classe de l'an dernier n'a pas été archivée peut choisir une classe de l'année.
- Aucune migration, aucun nouveau port : la décision réutilise `ClassroomDesignation`, `JoinPolicy` et les méthodes d'adhésion existantes.
- Le départ volontaire se distingue du retrait : l'élève reste libre de revenir.

### 🔴 Coûts consentis

- **Personne n'est prévenu** du départ : l'ancien enseignant voit simplement un élève de moins. Aucun canal n'existe (`notifications-push` au backlog).
- **Un élève peut sauter de classe en classe** et lire, dans chacune, ce qu'un élève y voit (camarades, annonces, exercices). C'était déjà possible en créant des comptes (ADR-0085 §5) ; la trace d'audit et le débit le rendent visible et lent, pas impossible.
- **Un compte prêté ou volé** peut être déplacé par un tiers ; l'élève le découvre à sa prochaine visite. Le retour par la voie standard est possible, sauf si l'ancienne classe l'a retiré entre-temps.
- **En base, un départ volontaire et un départ après archivage se ressemblent** (`left_at` seul) : seule la trace d'audit les distingue.
- **Le taux de rendu de l'ancienne classe baisse** d'un élève sans explication à l'écran.

## 6. Notes d'implémentation

```ruby
# app/domain/use_cases/classroom/change_classroom.rb
module UseCases
  module Classroom
    class ChangeClassroom
      def initialize(classrooms:, schools:, taxonomy:, memberships:, audit_log:, policy:, transaction:, clock:)
        @designation = ClassroomDesignation.new(classrooms:, schools:, taxonomy:, clock:)
        # …
      end

      # → success(Entities::Classroom::Classroom) | :forbidden (no_active_classroom, raison de JoinPolicy, classroom_archived)
      #   | :invalid (same_classroom, classe hors cascade) | :not_found (lien mort) | :conflict
      def call(actor:, dto:)
        return Shared::Result.failure(:forbidden) unless actor&.student?

        @transaction.call { change(actor, dto) }
      rescue Aborted => e
        e.result
      end
    end
  end
end
```

```ruby
# app/domain/entities/identity/audit_action.rb (extrait)
message.published message.withdrawn
classroom.student_moved
```

```ruby
# config/routes/classroom.rb (extrait) — ADR-0095 : l'élève à classe active change de classe, après confirmation.
get  "students/classroom/change",         to: "classroom/student_classroom_changes#new",     as: :new_student_classroom_change
get  "students/classroom/change/confirm", to: "classroom/student_classroom_changes#confirm", as: :confirm_student_classroom_change
post "students/classroom/change",         to: "classroom/student_classroom_changes#create",  as: :student_classroom_change
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/use_cases/classroom/change_classroom_test.rb` : élève à classe active → nouvelle adhésion principale, ancienne close **sans** `removed_at`, trace écrite ; sans classe active → `no_active_classroom` ; même classe → `same_classroom` ; classe complète, archivée, retiré sans lien → refus de `JoinPolicy` ; retiré avec le lien → accepté ; échec d'écriture → l'ancienne adhésion reste ouverte.
- `test/infrastructure/repositories/classroom/membership_repository_test.rb` : retour dans une ancienne classe → la même ligne est rouverte, pas de doublon.
- `test/domain/use_cases/classroom/join_as_student_test.rb` (existant) : l'élève à classe active reste refusé `already_enrolled`.
- `test/system/classroom/classroom_change_test.rb` : parcours complet profil → choix → confirmation → accueil de la nouvelle classe ; l'ancienne classe ne le liste plus.
- **Non vérifiable automatiquement** : qu'un élève qui saute de classe en classe soit repéré. La décision tient à la lecture du journal d'audit.

## 8. Réponses du porteur

Le 2026-10-16, le porteur a accepté les recommandations des questions 1 à 9 du [memo](../../chantiers/changement-etablissement-eleve/memo.md#réponses-du-porteur-2026-10-16) : le changement de classe se fait **par l'élève lui-même seulement**, ni la direction ni l'enseignant n'ont ce geste.
