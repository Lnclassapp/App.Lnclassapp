# ADR-0093 : L'équipe désactive un compte avant de l'anonymiser ; un adulte désactivé depuis 30 jours est anonymisé, jamais le dernier admin
<!-- index
titre: Désactivation d'un compte par l'équipe, anonymisation des adultes (à la main et à 30 jours), garde du dernier admin
statut: Proposé
problematique: `users.deactivated_at`/`deactivated_by_id` ; connexion refusée ; `UpdateAccount`, `DeactivateAccount`, `ReactivateAccount` sous `ManageAccountPolicy` ; `AnonymizeUser` étendu à l'enseignant et à l'équipe ; garde « soi-même » et « dernier admin » sous verrou ; `AnonymizeDeactivatedUsersJob` quotidien pour les adultes. Chantier `annuaire-equipe`.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | `docs/chantiers/annuaire-equipe` |
| **Complète** | [ADR-0036](./0036-suppression-archivage-et-anonymisation.md) (anonymisation) · [ADR-0038](./0038-comptes-de-l-equipe-et-sous-roles.md) (invariant « toujours un admin ») · [ADR-0077](./0077-inscription-de-la-direction-par-le-code-et-retrait.md) (même forme de purge) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Sur `Develop` au 2026-10-16, un compte n'a que deux états : actif, ou anonymisé (`users.anonymized_at`, irréversible). L'équipe ne peut empêcher une connexion qu'en effaçant le compte, et seulement pour un élève : `DeleteUserPolicy` refuse l'enseignant, la direction et l'équipe, parce que l'anonymisation ne sait pas traiter leurs rattachements. Un faux compte enseignant, un doublon, un membre de l'équipe parti restent actifs ou se traitent en console.

Le grill du 2026-09-28 a fixé la règle : **désactiver d'abord** (réversible), puis anonymiser, automatiquement 30 jours plus tard ; jamais son propre compte ni le dernier `admin`. Deux décisions postérieures la bornent :

- le **2026-10-02**, le porteur a retiré l'anonymisation automatique au « départ » : les données d'un élève restent accessibles comme archive ; et anonymiser un élève **efface ses résultats** (ADR-0036, amendement 2) ;
- le **2026-10-04**, l'ADR-0077 a donné à la direction un retrait archivé, restaurable 30 jours puis purgé par une tâche quotidienne, avec refus de connexion.

L'invariant de l'ADR-0038 (« il reste toujours au moins un `admin` non anonymisé ») n'est vérifié nulle part dans le code.

## 2. Moteurs de décision

1. Un geste réversible avant tout geste irréversible.
2. Aucun effacement des résultats d'un élève sans demande (décision du 2026-10-02, amendement 2).
3. Un seul mécanisme par population : la direction garde celui de l'ADR-0077.
4. L'équipe ne peut pas se retrouver sans `admin`, même sous deux requêtes simultanées.
5. La base refuse les états incohérents, même si le code oublie.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Désactivation dans une table à part (`account_deactivations`) | historique des désactivations | une jointure de plus à chaque connexion ; le journal d'audit garde déjà l'historique |
| B — **Colonnes `users.deactivated_at` et `deactivated_by_id`** | une lecture dans `authenticate`, contrainte `CHECK` simple, même forme que `school_staffs.archived_at` | — retenue |
| C — Étendre `school_staffs.archived_at` à tous les rôles | un seul mécanisme | les élèves, enseignants et membres de l'équipe n'ont pas de ligne `school_staffs` |
| D — Anonymisation automatique pour tous les rôles (grill littéral) | une seule règle | efface les résultats d'un élève sans demande, contre la décision du 2026-10-02 (Q1 du memo) |
| E — Aucune anonymisation automatique | rien à planifier | un compte adulte désactivé garde son nom et son numéro sans limite, alors que la direction est purgée à 30 jours |

## 4. Décision

> **Nous ajoutons un état « désactivé » sur `users`, posé et levé par l'équipe ; il ferme les sessions et refuse la connexion. L'équipe modifie le nom, le genre et le numéro d'un compte. L'anonymisation s'étend à l'enseignant et au membre de l'équipe ; un adulte désactivé depuis plus de 30 jours est anonymisé par une tâche quotidienne, jamais un élève. Ni son propre compte, ni le dernier `admin` actif ne se désactivent ni ne s'anonymisent. La direction garde le retrait de l'ADR-0077.**

*Les points marqués (Qn) suivent la recommandation du memo ; une réponse différente du porteur amende cet ADR avant le Lot 0.*

### 4.1 Schéma

```ruby
# db/migrate/20261020000000_add_deactivation_to_users.rb
add_column :users, :deactivated_at, :datetime
add_reference :users, :deactivated_by, foreign_key: { to_table: :users }, index: false # on_delete :restrict (ADR-0027)
add_index :users, :deactivated_at, where: "deactivated_at IS NOT NULL AND anonymized_at IS NULL"
add_check_constraint :users, "(deactivated_at IS NULL) = (deactivated_by_id IS NULL)", name: "users_deactivated_together"
```

L'anonymisation remet `deactivated_at` et `deactivated_by_id` à `NULL` : un compte anonymisé n'est plus « désactivé », il est hors de toute liste.

### 4.2 Ports (gelés au Lot 0)

`Ports::Identity::UserRepositoryPort` gagne :

| Méthode | Contrat |
|---|---|
| `update_identity(user_id:, first_name:, last_name:, gender:, contact:)` | → `:ok` \| `:contact_taken` (violation de l'index unique, lue sans exception) |
| `deactivate(user_id:, by_id:, at:)` | → `Boolean` (faux si déjà désactivé ou anonymisé) |
| `reactivate(user_id:)` | → `Boolean` |
| `lock_active_admins` | `SELECT … FOR UPDATE` des comptes `team`/`admin` ni désactivés ni anonymisés, dans la transaction appelante → `Array<Integer>` (leurs ids) |
| `deactivated_before(at:, roles:, limit: 500)` | → `Array<Integer>` (comptes désactivés strictement avant `at`, non anonymisés, des rôles donnés) |
| `authenticate(contact:, pin:)` | **amendée** : `nil` pour un compte désactivé, comme pour une direction archivée |

`Entities::Identity::User` gagne `deactivated_at`, `#deactivated?` et `#anonymization_due_on` (`deactivated_at + 30 jours` pour un adulte, `nil` pour un élève).

### 4.3 Use cases et policies

| Use case | Policy | Effet |
|---|---|---|
| `UseCases::Identity::UpdateAccount` | `ManageAccountPolicy` | nom, genre, numéro (format de l'ADR-0028 via `Entities::Identity::Contact`) ; numéro changé → `SessionRepositoryPort#destroy_all_for` ; journal `user.updated_by_team` avec `metadata.fields` (noms des champs, jamais les valeurs) |
| `UseCases::Identity::DeactivateAccount` | `ManageAccountPolicy` | `deactivate` + sessions fermées ; journal `user.deactivated` ; refus `:conflict` `last_admin` |
| `UseCases::Identity::ReactivateAccount` | `ManageAccountPolicy` | `reactivate` ; journal `user.reactivated` |
| `UseCases::Identity::AnonymizeUser` | `DeleteUserPolicy` **amendée** | en plus de l'élève : l'enseignant (retiré de ses établissements comme par `DetachTeacher`, devoirs actifs archivés, Q7) et le membre de l'équipe (second facteur déjà effacé) ; refus `:conflict` `last_admin` ; `metadata.reason` = `request`, `team` ou `retention` |
| `UseCases::Identity::AnonymizeDeactivatedUsers` | `AnonymizeDeactivatedUsersPolicy` (acteur `nil` seul) | rôles `teacher` et `team` désactivés avant `now - 30 jours` ; une transaction par compte ; un échec n'arrête pas les suivants (forme de `PurgeArchivedStaff`) ; un compte réactivé entre la lecture et son tour est sauté |

`Policies::Identity::ManageAccountPolicy#call(actor:, target:)` (Q5) :

- `:forbidden` si l'acteur n'est pas `team`, si `target.id == actor.user_id`, si la cible est anonymisée ;
- `admin` : tout rôle sauf `school_admin` ; `field` : `student` et `teacher` ; `content` : rien ;
- `school_admin` : `:forbidden` ici, la fiche appelle `ArchiveSchoolStaff` / `RestoreSchoolStaff` et leur policy (Q2).

`DeleteUserPolicy` : `admin` seul (ADR-0038), cible `student`, `teacher` ou `team`, jamais soi-même.

**Garde du dernier `admin`** — dans `DeactivateAccount` et `AnonymizeUser`, quand la cible est `team`/`admin` :

```ruby
# app/domain/use_cases/identity/deactivate_account.rb (extrait prévu)
@transaction.call do
  admins = @users.lock_active_admins
  next Shared::Result.failure(:conflict, errors: LAST_ADMIN) if admins == [ target.id ]
  # … deactivate, sessions, journal
end
```

Le verrou porte sur les lignes `admin` : deux requêtes qui visent les deux derniers `admin` se sérialisent, la seconde lit un seul `admin` restant et reçoit `:conflict`.

### 4.4 Tâche planifiée

```yaml
# config/recurring.yml (production)
  # ADR-0093 : adult accounts deactivated for 30 days are anonymized; students never are.
  anonymize_deactivated_users:
    class: Identity::AnonymizeDeactivatedUsersJob
    queue: default
    schedule: every day at 4:15am
```

Elle ne lit que `teacher` et `team`. Un élève désactivé reste désactivé : son anonymisation passe par une demande de suppression (ADR-0036, amendement 2) ou par le geste de l'`admin`. Ses échecs sont visibles dans Mission Control (ADR-0052).

## 5. Conséquences

### 🟢 Positives

- L'équipe ferme un compte sans rien effacer, et rattrape une erreur d'un clic.
- Les comptes adultes inactifs ne gardent pas de données personnelles au-delà de 30 jours, comme la direction.
- L'invariant de l'ADR-0038 devient une règle testée.
- Aucune donnée d'élève n'est effacée sans demande.

### 🔴 Coûts consentis

- Deux régimes : un adulte désactivé est purgé à 30 jours, un élève désactivé ne l'est jamais. La fiche doit le dire.
- La direction suit un troisième chemin (ADR-0077), sans colonne `users.deactivated_at`.
- Une colonne lue à chaque connexion ; l'index partiel ne sert qu'à la tâche.
- Un numéro corrigé par l'équipe ferme les sessions du titulaire sans le prévenir.
- `sous-roles-equipe` réécrira `ManageAccountPolicy`.

## 6. Notes d'implémentation

- `UserRepository#authenticate` : ajouter `deactivated_at: nil` à la recherche, à côté de `archived_school_admin?`.
- `UpdateAccount` lit la cible, refuse un compte anonymisé (`:not_found`), et n'écrit que les champs changés.
- La date de la demande de `AnonymizeUser` reste exigée (`DeletionRequestInput`) ; pour un geste de l'équipe sans demande, la modale propose la date du jour et `reason: "team"`.
- Pour un enseignant, `AnonymizeUser` reçoit les ports `schools`, `teachings` et `assignments` de `DetachTeacher` et les appelle pour chaque établissement rattaché ; aucune ligne de `teacher_school_departures` (ce n'est pas un départ décidé par la direction).
- Aucune cascade nouvelle (ADR-0036 §4).

## 7. Comment vérifier que la décision est respectée

- `test/infrastructure/repositories/identity/user_repository_test.rb` : un compte désactivé n'est pas authentifié ; `users_deactivated_together` refuse une colonne sans l'autre ; `lock_active_admins` exclut désactivés et anonymisés.
- `test/domain/use_cases/identity/deactivate_account_test.rb` : soi-même, dernier admin, sessions fermées, journal.
- `test/integration/identity/last_admin_concurrency_test.rb` : deux threads, deux derniers `admin`, une seule désactivation réussit.
- `test/domain/use_cases/identity/anonymize_deactivated_users_test.rb` : 31 jours oui, 29 non, élève jamais, réactivé sauté, échec isolé.
- `test/jobs/recurring_tasks_test.rb` : la tâche est programmée en production.
- `test/domain/policies/identity/manage_account_policy_test.rb` : la matrice du §4.3, case par case.
