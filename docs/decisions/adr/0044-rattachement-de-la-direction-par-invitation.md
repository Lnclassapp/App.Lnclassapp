# ADR-0044 : Rattachement de la direction par invitation, une école par membre, quatre fonctions de référence, second facteur exigé
<!-- index
titre: Rattachement de la direction par invitation, une école par membre, quatre fonctions de référence, second facteur exigé
statut: Accepté ; amendé par [0065](./0065-espace-direction-simple-en-lecture-seule.md) *(proposé)*
problematique: Invitation par l'équipe ou un membre de l'école ; Proviseur, Censeur, Éducateur, Secrétaire ; un proviseur actif par école ; TOTP pour `school_admin`. F-22.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-22**, bloque la V2 |
| **Remplace** | — |
| **Remplacé par** | — *(amendé par [ADR-0065](./0065-espace-direction-simple-en-lecture-seule.md) le 2026-09-28, statut `Proposé`)* |

---

## 1. Contexte et problématique

Dans l'ancien, un membre de direction se déclare lui-même rattaché à une école, par `school_admins/registrations`, sans vérification. Il lit ensuite des listes nominatives de mineurs. Les fonctions (`SchoolRole`) sont des lignes libres créées par chaque école. `has_one :school_staff` impose une seule école, alors que le glossaire laisse entendre le contraire, et aucun index ne le garantit (**C-30**). Le second facteur n'est exigé que pour `team`, alors que `school_admin` lit des données de mineurs (**C-20**). Enfin, on peut gérer le personnel d'une autre école que la sienne (SC-11 à SC-14).

## 2. Moteurs de décision

1. Personne ne s'attribue lui-même l'accès aux élèves d'une école.
2. Une seule école par membre, garantie en base.
3. Des fonctions comparables d'une école à l'autre.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Auto-déclaration (ancien) | Sans friction | Accès aux mineurs sans contrôle |
| B — Validation par l'équipe après demande | Contrôlé | L'équipe devient un goulet |
| C — **Invitation par l'équipe ou par un membre rattaché** | Contrôle et diffusion par cooptation | Le premier membre de chaque école dépend de l'équipe |
| D — Code d'établissement | Autonome | Le code fuit comme un code de classe |

## 4. Décision

> **Nous rattachons la direction uniquement par invitation, émise par l'équipe ou par un membre déjà rattaché à la même école, à une seule école, avec une fonction choisie parmi quatre, et avec un second facteur TOTP obligatoire.**

**Table `school_staffs`** (contexte `school`) :

| Colonne | Contrainte |
|---|---|
| `user_id` | `NOT NULL`, FK `users` |
| `school_id` | `NOT NULL`, FK `schools` |
| `position` | `CHECK IN ('principal','censor','educator','secretary')`, soit Proviseur, Censeur, Éducateur, Secrétaire |
| `invited_by_id` | FK `users` |
| `joined_at` | `datetime NOT NULL` |
| `left_at` | `datetime NULL` |

**Index** :

- unique partiel `(user_id) WHERE left_at IS NULL` : une seule école à la fois (C-30) ;
- unique partiel `(school_id) WHERE position = 'principal' AND left_at IS NULL` : un seul proviseur actif.

La table `school_roles` n'est pas reprise.

**Invitation** : table `invitations` de l'ADR-0038, avec `kind = 'school_staff'`, `school_id` et `position`.

- Use case `School::InviteStaffMember`, policy `School::InviteStaffPolicy`.
- Sont autorisés : `team` (sous-rôle `admin` ou `field` en V4) pour toute école, et un membre actif de la **même** école.
- Un membre ne peut inviter à la fonction `principal` que s'il est lui-même `principal`.
- L'acceptation crée le compte `school_admin` s'il n'existe pas, puis la ligne `school_staffs`.
- Un compte déjà rattaché à une autre école reçoit `:conflict`.

**Départ** : `School::DetachStaffMember` pose `left_at` et supprime les sessions du compte. Policy : `team`, ou le `principal` de l'école (qui ne peut pas se détacher lui-même). Le compte sans rattachement actif ne voit plus que son profil.

**Second facteur (C-20)** : `school_admin` suit le régime de l'ADR-0031 (TOTP, codes de secours). Le contrôleur de base de l'espace direction exige `second_factor_verified_at` comme `Teams::BaseController`. En cas de perte, la réinitialisation est faite par `team`.

**Périmètre** : toute policy de la direction compare `actor.school_id` à l'école de la ressource. Sont concernés la gestion des classes (ADR-0030), le personnel, les annonces (ADR-0045) et les listes d'élèves.

**Journal** : `invitation.sent`, `invitation.accepted`, `staff.detached`.

## 5. Conséquences

### 🟢 Positives

- C-30 est fermée par un index, et C-20 par un régime explicite.
- Les trous SC-11 à SC-14 deviennent des tests de refus sur l'école de l'acteur.
- Les fonctions se comparent d'une école à l'autre dans les indicateurs.

### 🔴 Coûts consentis

- Le premier membre de chaque école attend l'équipe.
- Un membre qui dirige deux établissements (public et privé) doit avoir deux comptes.
- Le TOTP ajoute une étape pour des utilisateurs parfois peu équipés.
- Quatre fonctions seulement : un intendant ou un surveillant général prend la plus proche.

## 6. Notes d'implémentation

```ruby
# db/migrate/…_create_school_staffs.rb
create_table :school_staffs do |t|
  t.references :user, null: false, foreign_key: true
  t.references :school, null: false, foreign_key: true
  t.string :position, null: false
  t.references :invited_by, foreign_key: { to_table: :users }
  t.datetime :joined_at, null: false
  t.datetime :left_at
end
add_check_constraint :school_staffs, "position IN ('principal','censor','educator','secretary')", name: "school_staffs_position_values"
add_index :school_staffs, :user_id, unique: true, where: "left_at IS NULL", name: "index_school_staffs_one_active_school"
add_index :school_staffs, :school_id, unique: true, where: "position = 'principal' AND left_at IS NULL",
          name: "index_school_staffs_one_principal"
```

## 7. Comment vérifier que la décision est respectée

- Tests de policy : un membre d'une école A refusé sur toute ressource de l'école B ; un `educator` refusé pour inviter un `principal`.
- Test de repository : un second rattachement actif lève `RecordNotUnique`.
- Test d'intégration : un `school_admin` connecté par PIN seul est redirigé sur chaque route de l'espace direction.

## 8. Remplace, complète, amende

- Ne remplace aucun ADR.
- **Complète** l'ADR-0025, compensation 5, pour `school_admin` (C-20).
- **Corrige** le glossaire §1 (`SchoolRole` dynamique, C-30).

## 9. Points à confirmer par le porteur

- Tout membre rattaché peut inviter, pas seulement le proviseur.
- Second facteur **obligatoire** pour la direction.
- Liste fermée de quatre fonctions.

## Amendement du 2026-09-28 — version simple de l'espace direction

*Chantier [`docs/chantiers/espace-direction-simple`](../../chantiers/espace-direction-simple/memo.md), [ADR-0065](./0065-espace-direction-simple-en-lecture-seule.md). Statut : `Proposé`. Le texte ci-dessus reste tel qu'accepté ; une fois l'ADR-0065 accepté, cette section fait foi en cas d'écart.*

Décision du porteur : une direction qui **lit** son établissement, sans plus.

- **Pas de fonction** : un seul type de compte direction. `school_staffs` n'a ni `position` ni `left_at` ; l'invitation `school_staff` n'exige plus de fonction (contrainte `invitations_staff_has_school` assouplie). Les index « un proviseur actif » et `School::DetachStaffMember` ne sont pas créés.
- **Pas de second facteur** : la direction se connecte par téléphone et PIN, comme l'enseignant. Le paragraphe « Second facteur (C-20) » et le troisième test du §7 ne s'appliquent pas. Coût consenti dans l'ADR-0065 §5.
- **Seule l'équipe invite** : un membre de la direction n'invite personne.
- **Aucun départ** à l'écran : un compte à retirer passe par la console jusqu'à `annuaire-equipe`.
- **Inchangé** : l'invitation comme seule entrée, un seul établissement par compte (index unique sur `user_id`), toute lecture limitée à l'établissement de l'acteur.
- La conception complète (quatre fonctions, TOTP, personnel) reste au backlog, sur la branche `feature/espace-direction`.
