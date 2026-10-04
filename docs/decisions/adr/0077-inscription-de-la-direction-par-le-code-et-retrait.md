# ADR-0077 : La direction s'inscrit avec le code d'établissement, dans un plafond de 3, et un compte direction retiré est archivé puis supprimé à 30 jours

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-04 |
| **Chantier** | `docs/chantiers/inscription-direction` |
| **Remplace** | — *(amende [ADR-0044](0044-rattachement-de-la-direction-par-invitation.md) et [ADR-0065](0065-espace-direction-simple-en-lecture-seule.md) : l'invitation n'est plus la seule entrée de la direction)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Depuis l'ADR-0044 et l'ADR-0065, un compte direction (`school_admin`) ne naît que d'une invitation de l'équipe (`InviteSchoolStaff`, puis `AcceptInvitation`). L'équipe doit connaître le numéro de chaque chef d'établissement, et le lien ne vaut que 72 h. Avec le déploiement par les enseignants (parrainage, ADR-0063), des établissements actifs ont des dizaines d'enseignants et aucune direction.

Le porteur décide (memo Q1, Q2) que la direction s'inscrit **seule**, avec le **code d'établissement** que les enseignants utilisent déjà, et **accède tout de suite** à son espace. Ce code circule dans les groupes de professeurs : il ne prouve pas qu'on est la direction. Le risque est accepté, et il est encadré par quatre règles :

- un **plafond** de 3 directions actives inscrites par le code, par établissement (Q3, Q12) ;
- une **visibilité** des arrivées pour les directions en place (Q9) ;
- un **retrait** par l'équipe ou par une autre direction de plus de 7 jours (Q4, Q10, Q11) ;
- un retrait **réversible** pendant 30 jours, puis une suppression automatique, avec un signal à l'équipe (Q4 bis, Q6).

Aujourd'hui, aucun compte direction ne peut être retiré ; `school_staffs` ne sait ni comment la direction est arrivée, ni si elle est encore là.

## 2. Moteurs de décision

1. Un code qui fuit ne doit pas ouvrir plus de 3 comptes direction, même avec deux inscriptions simultanées.
2. Un imposteur qui vient de s'inscrire ne doit pas pouvoir évincer la direction en place.
3. Un retrait abusif se répare sans perte, et un compte retiré ne garde pas de données personnelles indéfiniment.
4. Ne pas toucher au modèle des comptes : un compte = un rôle, un rattachement de direction par compte.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Code de direction distinct, transmis par l'équipe | Le code des enseignants ne donnerait plus accès au travail des élèves | Écartée par le porteur (Q2) : un code de plus à gérer et à transmettre |
| B — Inscription par le code, compte en attente de validation par l'équipe | Aucun accès sans contrôle humain | Écartée par le porteur (Q1) : l'équipe reste le goulot |
| C — Inscription par le code, accès immédiat, plafond, retrait réversible | Autonomie de la direction, risque borné | **Retenue** |
| D — Retrait = suppression immédiate | Simple | Un retrait abusif serait irréparable (Q4 bis) |

## 4. Décision

> **Nous laissons la direction s'inscrire avec le code d'établissement d'un établissement actif et accéder tout de suite à son espace. Au plus 3 directions actives arrivées par le code coexistent par établissement ; les directions invitées n'entrent pas dans ce compte. Un compte direction est retiré par l'équipe (`admin`, `field`), ou par une autre direction du même établissement actif inscrite depuis au moins 7 jours, jamais par soi-même. Le retrait archive le compte : il ferme ses sessions, il refuse sa connexion et il libère sa place. L'équipe le voit, et peut le restaurer pendant 30 jours ; au-delà, une tâche quotidienne anonymise le compte et supprime son rattachement.**

### 4.1 Schéma

Une migration sur `school_staffs` :

| Colonne | Type | Règle |
|---|---|---|
| `joined_via` | `string`, non nul, défaut `"invitation"` | `CHECK joined_via IN ('invitation', 'code')` ; les lignes existantes valent `invitation` |
| `archived_at` | `datetime`, nul | non nul = compte archivé |
| `archived_by_id` | `bigint`, nul, FK `users` `on_delete: :restrict` | l'auteur du retrait |
| — | `CHECK (archived_at IS NULL) = (archived_by_id IS NULL)` | `archived_together` |

Plus un index `index_school_staffs_on_school_id_and_joined_via` partiel `WHERE archived_at IS NULL`, pour le comptage du plafond.

### 4.2 Ports

`Ports::School::StaffRepositoryPort` est **étendu**. `attach` garde sa signature, et l'invitation reste `joined_via: "invitation"` par défaut de la colonne.

```ruby
# Inscription par le code : verrouille la ligne de l'établissement, compte les directions actives arrivées par le code,
# rattache si le compte est sous le plafond. → true | false (plafond atteint)
def attach_by_code(user_id:, school_id:, cap:, at:)
# Le rattachement d'un compte direction, archivé ou non ; nil si aucun.
def find_by_user_id(user_id:)            # → Entities::School::Staff | nil
def find_by_public_id(public_id:)        # public_id du compte (users.public_id) → Entities::School::Staff | nil
def archive(user_id:, by_id:, at:)       # → true | false (déjà archivé : aucune écriture)
# Restaure si le compte est encore archivé et, pour une arrivée par le code, si le plafond le permet (même verrou).
def restore(user_id:, cap:)              # → :restored | :not_archived | :cap_reached
def archived_before(at:)                 # → [Entities::School::Staff] archivés avant `at` (tâche de suppression)
def delete(user_id:)                     # → true
```

`Entities::School::Staff` est créée (Ruby pur) : `user_id`, `user_public_id`, `school_id`, `joined_via`, `joined_at`, `archived_at`, `archived_by_id`, `#archived?`, `#newcomer?(now)` (`joined_at > now - 7 jours`), `#deletion_due_on` (`archived_at + 30 jours`).

`Ports::Identity::RegistrationRepositoryPort` gagne `create_school_admin(user:, pin:)` → `Result(User) | failure(:conflict, errors: { contact: [:taken] })`, sur le modèle de `create_student` : la direction inscrite par le code n'a pas d'invitation à marquer, et détourner `create_from_invitation(invitation_id: nil)` aurait faussé son contrat (Lot 0 rouvert, 2026-10-04). `UserRepositoryPort` ne change pas de signature. L'adaptateur `UserRepository#authenticate` exclut un `school_admin` dont la ligne `school_staffs` est archivée. `#actor_for` donne `school_id: nil` à un compte archivé, ce qui le mène à l'écran d'attente si une session survivait.

### 4.3 Use cases et policies

| Use case | Policy | Rôle |
|---|---|---|
| `UseCases::Identity::RegisterSchoolStaff` | `Policies::Identity::RegisterSchoolStaffPolicy` (aucun acteur connecté) | Crée le compte `school_admin` (nom, prénoms, genre, numéro, PIN), puis `attach_by_code` ; un refus du plafond annule la création dans la transaction ; ouvre la session ; journal `school_staff.registered` |
| `UseCases::School::ArchiveSchoolStaff` | `Policies::School::RemoveSchoolStaffPolicy(actor:, school:, target:, actor_staff:, now:)` | Archive, ferme toutes les sessions de la cible (`destroy_all_for`), journal `school_staff.archived` |
| `UseCases::School::RestoreSchoolStaff` | `Policies::School::RestoreSchoolStaffPolicy(actor:)` (équipe `admin`, `field`) | `restore(cap: 3)` ; journal `school_staff.restored` |
| `UseCases::School::PurgeArchivedStaff` | `Policies::School::PurgeArchivedStaffPolicy` (le système seul, acteur `nil` accepté) | Pour chaque archivé depuis plus de 30 jours : `anonymize` (ADR-0036 §4, nom « Compte supprimé »), `destroy_all_for`, `delete` du rattachement ; journal `school_staff.deleted` |

`RemoveSchoolStaffPolicy` accepte :
- l'équipe `admin` ou `field`, pour toute cible ;
- une direction, si son rattachement n'est pas archivé, que son établissement est actif et que c'est celui de la cible, qu'elle n'est pas elle-même la cible, et que `actor_staff.newcomer?(now)` est faux.

Tout autre cas → `:forbidden`. Une cible d'un autre établissement → `:not_found` (comme ADR-0071).

Le plafond vit dans le domaine : `Entities::School::Staff::CODE_CAP = 3`, `NEWCOMER_DAYS = 7`, `RETENTION_DAYS = 30`.

### 4.4 Lecture

`Queries::School::SchoolStaffQuery` fournit :
- `active_for(school_id:)` : nom, date d'arrivée, `joined_via`, `public_id`, pour le bloc « Direction » ;
- `recent_arrivals(school_id:, since:, except_user_id:)`, pour le bandeau d'arrivée ;
- `archived(school_id: nil)` : nom, établissement, auteur, date de retrait, date de suppression, pour l'équipe.

### 4.5 Tâche planifiée

`School::PurgeArchivedStaffJob` est ajoutée à `config/recurring.yml` (production) : `every day at 4am`, file `default`. Elle appelle `PurgeArchivedStaff` avec `at: now - 30.days`.

## 5. Conséquences

### 🟢 Positives

- Une direction entre seule, depuis la page d'accueil, avec un code qu'elle a déjà.
- Un code qui fuit ouvre au plus 3 comptes, et un imposteur récent ne peut rien retirer.
- Un retrait abusif se répare pendant 30 jours ; ensuite, aucune donnée personnelle ne reste.
- `school_staffs` sait enfin d'où vient chaque direction et si elle est encore là.

### 🔴 Coûts consentis

- **Le code d'établissement donne accès au travail de tous les élèves** à quiconque le connaît, dans la limite de 3 comptes. C'est un choix du porteur (Q1, Q2), contre la recommandation d'un code distinct ou d'une validation.
- Un imposteur inscrit depuis plus de 7 jours peut retirer la vraie direction. Le recours est l'équipe : elle voit le retrait et restaure.
- Les 3 places peuvent être prises par des imposteurs : la vraie direction passe alors par l'équipe (invitation, hors plafond).
- La connexion d'un compte archivé reçoit le même refus qu'un mauvais PIN : le compte n'est pas révélé, mais la vraie direction retirée ne comprend pas tout de suite pourquoi.
- Un nouveau verrou de ligne sur `schools` à chaque inscription par le code.
- `DeleteUserPolicy` reste limitée aux comptes élèves : la suppression d'un compte direction ne passe que par la tâche à J+30.

## 6. Notes d'implémentation

```ruby
# app/infrastructure/repositories/school/staff_repository.rb
def attach_by_code(user_id:, school_id:, cap:, at:)
  Orm::School.lock.find(school_id) # verrou : deux inscriptions sur la dernière place se sérialisent
  return false if Orm::SchoolStaff.where(school_id:, joined_via: "code", archived_at: nil).count >= cap

  Orm::SchoolStaff.create!(user_id:, school_id:, invited_by_id: nil, joined_via: "code", created_at: at)
  true
end
```

```ruby
# app/domain/policies/school/remove_school_staff_policy.rb
def call(actor:, school:, target:, actor_staff:, now:)
  return Shared::Result.success if actor&.team? && TEAM_ROLES.include?(actor.team_role)
  return Shared::Result.failure(:forbidden) unless actor&.school_admin? && actor_staff && !actor_staff.archived?
  return Shared::Result.failure(:not_found) unless target.school_id == actor.school_id
  return Shared::Result.failure(:forbidden) if !school.active? || target.user_id == actor.user_id || actor_staff.newcomer?(now)

  Shared::Result.success
end
```

## 7. Comment vérifier que la décision est respectée

- `test/architecture/port_contracts_test.rb` : `StaffRepository` implémente toutes les méthodes du port, avec les mêmes signatures.
- `test/architecture/use_case_policies_test.rb` : les quatre use cases prennent un `policy:`.
- Un test d'intégration de `attach_by_code` lance deux inscriptions sur la 3ᵉ place dans deux threads : une seule ligne est écrite.
- La contrainte `archived_together` et le `CHECK joined_via` sont testés en base (insertion refusée).
- Le test de `RemoveSchoolStaffPolicy` couvre chaque branche : équipe, direction de plus de 7 jours, nouvel arrivant, soi-même, autre établissement, établissement inactif, auteur archivé.
- Le test de `UserRepository#authenticate` vérifie qu'un compte archivé ne se connecte pas.
