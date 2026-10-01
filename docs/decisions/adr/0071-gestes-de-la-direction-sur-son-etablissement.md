# ADR-0071 : La direction change le lien des enseignants, ajuste ses classes et retire ou réintègre un enseignant, sur son seul établissement actif ; un retrait se trace et barre le retour par le code

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-01 |
| **Chantier** | [`docs/chantiers/gestion-etablissement-direction`](../../chantiers/gestion-etablissement-direction/prd.md) — critères GD-01 à GD-27 |
| **Amende** | [ADR-0065](./0065-espace-direction-simple-en-lecture-seule.md) (la direction n'est plus en lecture seule), [ADR-0057](./0057-code-d-etablissement.md) (la direction régénère le code), [ADR-0059](./0059-ajuster-les-classes-d-un-niveau.md) (la direction a « + » et « − »), [ADR-0030](./0030-une-ecole-par-enseignant-et-creation-des-classes.md) (un enseignant quitte et rejoint un établissement) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0065 a donné à la direction un compte, sans fonction ni second facteur, et deux lectures de son établissement. Tout geste reste à l'équipe : transmettre le code d'établissement, ajouter une classe, faire partir un enseignant. Le porteur (grill du 2026-10-01) donne à la direction trois gestes, **toujours sans fonction** :

- **le lien d'inscription des enseignants** (`/e/<code>`) : le lire, le partager et le changer s'il fuit (grill 4) ;
- **« + » et « − »** sur un niveau, comme l'équipe (grill 7, ADR-0059) ;
- **retirer un enseignant** : il perd l'établissement et ses classes, **ses devoirs actifs sont archivés** (grill 6) ; il peut rejoindre un **autre** établissement par son code (grill 8), **jamais** revenir seul dans celui qui l'a retiré (grill 5) ; seule la direction le **réintègre** (grill 9 : pas l'équipe).

Trois contraintes d'existant :

1. `AddLevelClassroom`, `RemoveLevelClassroom` et `RegenerateSchoolCode` appellent `ManageClassroomPolicy` ou `ManageSchoolPolicy` avec le seul acteur, **avant** de lire l'établissement : aucune policy ne peut borner la direction à son établissement sans le voir. Et `ManageSchoolPolicy` autorise aussi l'import, les DRENA et la validation des comptes en attente, refusés à la direction (Q1).
2. Retirer un enseignant supprime ses lignes `teacher_schools` et `teacher_classrooms` : **rien ne garde la trace** qu'il a été retiré de cet établissement. Sans trace, le code de l'établissement le reprend aussitôt, et le retrait ne sert à rien (grill 5).
3. Un enseignant **déjà inscrit** sans établissement n'a aujourd'hui aucun moyen de rejoindre un établissement : l'inscription par code ne vaut que pour un nouveau compte (`RegisterTeacher`).

## 2. Moteurs de décision

1. **Aucune fuite inter-établissements** : l'établissement d'un geste de la direction est toujours celui de son compte, comparé dans le domaine ; chaque geste a son test de refus.
2. **Ne rien donner que le porteur a écarté** : ni validation des comptes en attente, ni import, ni personnel, ni retrait d'enseignant par l'équipe.
3. **Aucune production d'élève perdue** (ADR-0036) : sessions et résultats restent ; un devoir archivé reste lisible.
4. Réutiliser les use cases de l'équipe plutôt que les dupliquer.
5. Une donnée nouvelle seulement si un geste la lit.

## 3. Options envisagées

**Autorisation des gestes partagés avec l'équipe (« + », « − », code)**

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Élargir `ManageClassroomPolicy` et `ManageSchoolPolicy` à la direction | Deux fichiers | Elles ne voient pas l'établissement, et `ManageSchoolPolicy` ouvrirait l'import, les DRENA et la validation des comptes en attente |
| B — **Une policy `ManageSchoolStructurePolicy(actor:, school:)`, injectée dans les trois use cases, appelée après la lecture de l'établissement** | Une comparaison, testée une fois ; l'équipe garde tout ; les autres usages de `ManageSchoolPolicy` ne bougent pas | Retenue — l'ordre « lire puis autoriser » change dans trois use cases (voir coûts) |
| C — Des use cases propres à la direction | Aucun use case de l'équipe touché | Duplique la numérotation de l'ADR-0059 et la régénération de l'ADR-0057 : deux règles qui divergeront |

**Trace du retrait**

| Option | Pour | Contre |
|---|---|---|
| D — Lire le journal d'audit (`teacher.detached`) | Aucune table | Une règle métier qui lit un journal ; un journal se purge |
| E — Une colonne `detached_at` sur `teacher_schools` | Une colonne | Chaque lecture de `teacher_schools` doit filtrer ; l'index « une école principale » ne tient plus |
| F — **Table `teacher_school_departures`** (une ligne par retrait, close à la réintégration) | Lue par deux gestes seulement ; garde l'historique (qui, quand) ; ne touche aucune lecture existante | Retenue — une table de plus |

Options B et F retenues.

## 4. Décision

> **Nous autorisons la direction, sur son seul établissement actif, à changer le lien d'inscription des enseignants, à ajouter ou retirer une classe d'un niveau, et à retirer ou réintégrer un enseignant ; un retrait archive ses devoirs actifs dans l'établissement, s'inscrit dans `teacher_school_departures` et lui interdit de revenir seul par le code ; un enseignant sans établissement rejoint un autre établissement par son code.**

### 4.1 Policies

| Policy | Règle |
|---|---|
| `Policies::School::ManageSchoolStructurePolicy#call(actor:, school:)` (**nouvelle**) | `team` → succès. `school_admin` → succès si `actor.school_id == school.id` **et** `school.status == "active"`. Sinon `:forbidden`. `school` nil → `:forbidden` |
| `Policies::School::ManageSchoolTeachersPolicy#call(actor:, school:)` (**nouvelle**) | `school_admin` dont `actor.school_id == school.id`, établissement `active` → succès. **Tout autre acteur, `team` compris** → `:forbidden` (grill 9) |
| `Policies::School::JoinSchoolWithCodePolicy#call(actor:, pending_request:)` (**nouvelle**) | `teacher` sans établissement (`actor.school_id` nil) **et** sans demande `pending` (`pending_request` nil) → succès ; sinon `:forbidden`. Une demande `rejected` ou `approved` n'empêche pas (délégué) |
| `ManageSchoolPolicy`, `ManageClassroomPolicy`, `ReadOwnSchoolPolicy` | **Inchangées** |

### 4.2 Gestes partagés avec l'équipe (use cases modifiés)

`Classroom::AddLevelClassroom`, `Classroom::RemoveLevelClassroom`, `School::RegenerateSchoolCode` reçoivent `ManageSchoolStructurePolicy` et l'appellent **après** avoir lu l'établissement : `@policy.call(actor:, school:)`. Signatures, écritures, refus et audit **inchangés**. Un établissement introuvable reste `:not_found`. Les contrôleurs de l'équipe injectent la nouvelle policy (comportement identique pour `team`) ; ceux de la direction passent le `public_id` de **son** établissement, lu par `current_actor.school_id`, jamais par un paramètre.

### 4.3 Gestes propres à la direction (use cases nouveaux)

Tous lisent l'établissement **avant** toute écriture et l'autorisent par `ManageSchoolTeachersPolicy`. Écritures dans une transaction ; un refus après une écriture lève et ressort en `Result`, comme `JoinWithCode` (`raise Aborted`).

| Use case | Signature | Écritures | Refus | Audit |
|---|---|---|---|---|
| `School::DetachTeacher` | `call(actor:, school_id:, teacher_public_id:)` | supprime les lignes `teacher_schools` de cet établissement ; supprime ses `teacher_classrooms` des classes de cet établissement ; archive ses `classroom_assignments` **actifs** (`assigned_by_id` = l'enseignant) des classes de cet établissement (`archived_by_id` = l'acteur) ; insère une `teacher_school_departures` ouverte | `:forbidden` (policy ; `school_id` ≠ établissement de l'acteur) ; `:not_found` : compte inconnu, non enseignant, anonymisé, ou non rattaché à cet établissement (un enseignant en attente n'est pas rattaché) | `teacher.detached`, sujet le compte, `{ school_id:, classrooms_count:, assignments_archived: }` |
| `School::ReinstateTeacher` | `call(actor:, school_id:, teacher_public_id:)` | `attach_teacher(primary: true)` ; ferme le départ ouvert (`reinstated_at`, `reinstated_by_id`). Aucune classe, aucun devoir rendu (délégué) | `:forbidden` (policy) ; `:not_found` : pas de départ ouvert de cet établissement, ou l'enseignant a un établissement (il a rejoint ailleurs), ou anonymisé | `teacher.reinstated`, sujet le compte, `{ school_id: }` |
| `School::JoinSchoolWithCode` | `call(actor:, dto:)` — `dto` : `Dtos::School::SchoolJoinInput` (`school_code`, normalisé comme à l'inscription) | `attach_teacher(primary: true)` | `:forbidden` (policy) ; `:invalid` `school_code: [:inclusion]` — **même erreur** pour un code inconnu, un établissement non actif **et** un établissement qui a un départ ouvert pour cet enseignant | `school.changed`, sujet l'établissement, `{ change: "teacher_joined" }` |

L'enseignant retiré reste en session : la garde existante (`hold_pending_teacher`, ADR-0063) le renvoie vers l'écran d'attente à sa requête suivante.

### 4.4 Données

**Table `teacher_school_departures`** (contexte `school`) :

| Colonne | Contrainte |
|---|---|
| `teacher_id` | `NOT NULL`, FK `users` `RESTRICT` |
| `school_id` | `NOT NULL`, FK `schools` `RESTRICT` |
| `detached_by_id` | `NOT NULL`, FK `users` `RESTRICT` |
| `detached_at` | `datetime NOT NULL` |
| `reinstated_by_id` | FK `users` `RESTRICT`, `NULL` |
| `reinstated_at` | `datetime NULL` ; `CHECK ((reinstated_at IS NULL) = (reinstated_by_id IS NULL))` |

Index unique partiel `(teacher_id, school_id) WHERE reinstated_at IS NULL` : un seul départ ouvert par couple. Index `(school_id, detached_at)` pour la liste.

### 4.5 Ports (gelés au Lot 0)

| Port | Méthode | Contrat |
|---|---|---|
| `Ports::School::TeacherDepartureRepositoryPort` (**nouveau**) | `record(teacher_id:, school_id:, detached_by_id:, at:)` | `Entities::School::TeacherDeparture` |
| | `open_for(teacher_id:, school_id:)` | `TeacherDeparture \| nil` |
| | `close(id:, reinstated_by_id:, at:)` | `true` |
| `Ports::School::SchoolRepositoryPort` | `detach_teacher(teacher_id:, school_id:)` (**nouveau**) | `Integer` (lignes `teacher_schools` supprimées) |
| `Ports::Classroom::TeachingRepositoryPort` | `withdraw_all_in_school(teacher_id:, school_id:)` (**nouveau**) | `Integer` (déclarations supprimées) |
| `Ports::Classroom::AssignmentRepositoryPort` | `archive_all_by_teacher_in_school(teacher_id:, school_id:, archived_by_id:, at:)` (**nouveau**) | `Integer` (devoirs archivés) |

Réutilisés sans changement : `UserRepositoryPort#find_by_public_id`, `SchoolRepositoryPort#find_by_id`, `#find_by_school_code`, `#attach_teacher`, `#primary_school_id_for`, `JoinRequestRepositoryPort` (lecture de la demande en attente : `Queries::School::JoinRequestsQuery#status_for`, déjà lue par l'écran d'attente).

Entité nouvelle `Entities::School::TeacherDeparture` (`id, teacher_id, school_id, detached_by_id, detached_at, reinstated_by_id, reinstated_at`, `open?`). `Entities::Identity::AuditAction::ALL` gagne `teacher.detached` et `teacher.reinstated`.

### 4.6 Lectures (CQRS, ADR-0006)

| Query | Contenu |
|---|---|
| `Queries::School::OwnSchoolQuery#call(school_id:)` (**nouvelle**) | `public_id`, nom, type, statut, `school_code` de l'établissement de l'acteur |
| `Queries::School::LevelClassroomsQuery#call(public_id:)` | **Inchangée**, lue aussi par la direction |
| `Queries::School::SchoolTeachersQuery` | ajoute `public_id` à chaque ligne (pour « Retirer ») |
| `Queries::School::DepartedTeachersQuery#call(school_id:)` (**nouvelle**) | départs **ouverts** de l'établissement dont l'enseignant n'a **aucun** établissement et n'est pas anonymisé : nom, matière, `detached_at`, `public_id` ; triés du plus récent au plus ancien ; nombre de requêtes fixe |

## 5. Conséquences

### 🟢 Positives

- La direction fait seule ses trois gestes courants ; l'équipe n'est plus appelée pour un lien, une classe ou un départ.
- Une fuite du lien se répare sans l'équipe : changer le lien, puis retirer qui s'est inscrit à tort.
- Le retrait garde classes, élèves et résultats ; l'historique des départs reste (qui, quand).
- Les gestes refusés par le porteur restent refusés par construction : `ManageSchoolPolicy` ne change pas.

### 🔴 Coûts consentis

- **Pas de fonction** : tout compte de direction a tous les gestes. Deux directions d'un même établissement peuvent défaire le travail l'une de l'autre ; seul le journal dit qui a fait quoi.
- **Un établissement sans direction ne peut retirer aucun enseignant** : l'équipe n'a pas ce geste (grill 9).
- **Archiver en masse** les devoirs actifs de l'enseignant retire aussi un devoir qu'un collègue de la même classe utilisait : il doit le redonner. La réintégration ne rend ni les devoirs ni les classes.
- **Changer le lien casse aussi les liens de parrainage personnels** (`/e/<code>?ref=…`, ADR-0063) déjà partagés par les enseignants : ils se réaffichent avec le nouveau code, mais les anciens messages ne marchent plus.
- **Ordre « lire puis autoriser »** dans trois use cases de l'équipe : un acteur non autorisé reçoit `:not_found` pour un établissement inconnu au lieu de `:forbidden`. Sans effet visible : l'espace de l'équipe refuse les autres rôles avant le use case, et la direction ne passe jamais d'identifiant.
- **L'enseignant retiré reste en session** jusqu'à sa requête suivante, sans être prévenu.
- **Un retrait n'empêche pas un nouveau compte** : la personne peut s'inscrire de nouveau avec un autre numéro par le lien. La parade est « Changer le lien ».
- Une table de plus, lue par deux gestes.

## 6. Notes d'implémentation

```ruby
# app/domain/policies/school/manage_school_structure_policy.rb
# 🧠 DOMAINE · Policies::School::ManageSchoolStructurePolicy
# Rôle : « + », « − » et code d'un établissement : l'équipe partout, la direction sur son seul établissement actif
# ADR  : 0028, 0057, 0059, 0071
module Policies
  module School
    class ManageSchoolStructurePolicy
      def call(actor:, school:)
        return Shared::Result.failure(:forbidden) if actor.nil? || school.nil?
        return Shared::Result.success if actor.team?
        return Shared::Result.success if actor.school_admin? && actor.school_id == school.id && school.status == "active"

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
```

```ruby
# db/migrate/…_create_teacher_school_departures.rb
create_table :teacher_school_departures do |t|
  t.references :teacher, null: false, foreign_key: { to_table: :users }
  t.references :school, null: false, foreign_key: true
  t.references :detached_by, null: false, foreign_key: { to_table: :users }
  t.datetime :detached_at, null: false
  t.references :reinstated_by, foreign_key: { to_table: :users }
  t.datetime :reinstated_at
end
add_check_constraint :teacher_school_departures, "(reinstated_at IS NULL) = (reinstated_by_id IS NULL)",
                     name: "teacher_school_departures_reinstated_together"
add_index :teacher_school_departures, %i[teacher_id school_id], unique: true, where: "reinstated_at IS NULL",
          name: "index_teacher_school_departures_one_open"
add_index :teacher_school_departures, %i[school_id detached_at]
```

`archive_all_by_teacher_in_school` : un seul `UPDATE classroom_assignments … WHERE assigned_by_id = :teacher AND status = 'active' AND classroom_id IN (classes de l'établissement)`, posant `status = 'archived'`, `archived_at`, `archived_by_id` (les contraintes `classroom_assignments_archived_at_iff_archived` tiennent).

Contrôleurs de la direction : héritent de `SchoolAdmin::BaseController` (ADR-0065) ; l'établissement est `current_actor.school_id`. `Identity::PendingSchoolJoinsController` : `rate_limit to: 10, within: 1.minute, by: -> { request.remote_ip }` ; `skip_before_action :hold_pending_teacher`.

## 7. Comment vérifier que la décision est respectée

- `test/domain/policies/school/manage_school_structure_policy_test.rb`, `manage_school_teachers_policy_test.rb`, `join_school_with_code_policy_test.rb` : chaque rôle ; direction de A sur B refusée ; établissement inactif et brouillon refusés ; équipe acceptée par la première, **refusée** par la deuxième.
- `test/domain/use_cases/classroom/add_level_classroom_test.rb`, `remove_level_classroom_test.rb`, `test/domain/use_cases/school/regenerate_school_code_test.rb` : la direction de A réussit sur A, est refusée sur B ; l'équipe réussit comme avant.
- `test/domain/use_cases/school/detach_teacher_test.rb` : seuls les devoirs **actifs** de l'enseignant **dans cet établissement** sont archivés ; sessions, classes, élèves, compte intacts ; départ ouvert créé ; enseignant en attente → `:not_found`.
- `test/domain/use_cases/school/reinstate_teacher_test.rb`, `join_school_with_code_test.rb` : départ ouvert exigé ; le code de l'établissement qui a retiré l'enseignant donne **la même erreur** qu'un code inconnu.
- `test/db/schema_constraints_test.rb` : un seul départ ouvert par couple ; `reinstated_at` et `reinstated_by_id` ensemble ; clés `RESTRICT`.
- `test/architecture/port_contracts_test.rb` (existant) : chaque nouvelle méthode a son adaptateur.
- Chaque contrôleur `SchoolAdmin::` du chantier : 403 aux autres rôles, 404 pour une ressource d'un autre établissement.

## 8. Remplace, complète, amende

- **Amende l'ADR-0065** : la direction n'est plus en lecture seule ; trois gestes, sans fonction ni second facteur.
- **Amende l'ADR-0057** : `RegenerateSchoolCode` est autorisé par `ManageSchoolStructurePolicy` (équipe, ou direction de l'établissement actif).
- **Amende l'ADR-0059** : `AddLevelClassroom` et `RemoveLevelClassroom` sont autorisés par `ManageSchoolStructurePolicy`.
- **Amende l'ADR-0030** : un enseignant quitte un établissement par la direction, et un enseignant sans établissement en rejoint un par son code.
- **Complète l'ADR-0063** : la direction ne valide toujours pas les comptes en attente ; un enseignant en attente ne rejoint pas par code.

## 9. Points à confirmer par le porteur

Décisions prises par délégation (grill du 2026-10-01), amendables :

- La réintégration ne rend **ni les classes ni les devoirs archivés**.
- Un enseignant dont la demande a été **refusée** peut rejoindre un établissement par code.
- L'enseignant retiré n'est **pas prévenu** et reste en session jusqu'à sa requête suivante.
