# ADR-0038 : Un rôle `team` créé par invitation en V1, trois sous-rôles et leur matrice fixés dès maintenant pour la V4

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-16**, bloque la V1 (minimal) et la V4 |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Dans l'ancien dépôt, les comptes `team` se créent par la console, et l'`enum` de rôle contient un `parent` jamais implémenté. [`feature_listing.md`](../../feature_listing.md) prévoit des sous-rôles d'équipe (contenu, terrain, gestionnaire DRENA), alors que l'ADR-0025 ne protège par un second facteur que `team`, sans dire si les sous-rôles en héritent (**C-20**). Le back-office de la V4 a besoin d'une matrice, et les policies de la V1 doivent pouvoir l'accueillir sans être réécrites.

## 2. Moteurs de décision

1. Aucun compte privilégié ne se crée hors de l'application.
2. Les sous-rôles s'ajoutent en V4 sans migration de données.
3. Le moindre privilège : chacun n'a que ce qu'il lui faut.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — `team` seul, pour toujours | Minimal | Tout membre peut tout, y compris anonymiser |
| B — **`team` + `team_role`, matrice fixée maintenant** | Les policies de la V1 prévoient déjà la colonne | Une matrice à tenir à jour |
| C — Table de permissions fines | Souple | Surdimensionné pour une équipe de quelques personnes |

## 4. Décision

> **Nous créons les comptes `team` uniquement par invitation, nous leur donnons un sous-rôle `team_role` dès la V1, et nous appliquons la matrice ci-dessous à partir de la V4.**

**Rôles** : `users.role` en `string`, `CHECK IN ('student','teacher','school_admin','team')`. `parent` n'existe pas.

**Sous-rôle** : `users.team_role` en `string NULL`, `CHECK IN ('admin','content','field')`. Une seconde contrainte impose `(role = 'team') = (team_role IS NOT NULL)`.

En V1, tout compte `team` est `admin` et les policies ne testent que `role == :team` ; en V4, elles testent `team_role` selon la matrice.

**Table `invitations`** (contexte `identity`, partagée avec l'ADR-0044) :

| Colonne | Contrainte |
|---|---|
| `kind` | `CHECK IN ('team','school_staff')` |
| `contact` | 10 chiffres normalisés (ADR-0050) |
| `team_role` | pour `kind = 'team'` |
| `school_id`, `position` | pour `kind = 'school_staff'` |
| `invited_by_id` | FK `users`, `NULL` seulement pour l'invitation d'amorçage |
| `token_digest` | HMAC-SHA256, index unique |
| `expires_at` | création + 72 h |
| `accepted_at`, `accepted_user_id`, `revoked_at` | |

Index unique partiel `(kind, contact) WHERE accepted_at IS NULL AND revoked_at IS NULL`.

**Parcours** :

- `Identity::InviteTeamMember` (policy `Identity::InviteTeamPolicy`) génère un jeton de 32 caractères base58, affiché une fois dans un lien `/invitations/:token`.
- `Identity::AcceptInvitation` (anonyme) demande nom, prénoms (ADR-0037) et PIN (ADR-0050) ; un autre contact que celui de l'invitation donne `:invalid`, un jeton périmé `:expired`.
- Le compte passe par l'activation TOTP (ADR-0031) avant toute page de l'équipe. La première invitation est créée par le seed (ADR-0034).
- **Second facteur** : exigé pour **tout** `team_role` (C-20).

**Matrice de la V4** (✅ autorisé) :

| Action | `admin` | `content` | `field` |
|---|---|---|---|
| Inviter, changer le sous-rôle d'un membre, réinitialiser son TOTP | ✅ | | |
| Anonymiser un compte | ✅ | | |
| Superviser les jobs (`/teams/jobs`) | ✅ | | |
| Créer, publier, archiver le contenu ; importer (ADR-0039) | ✅ | ✅ | |
| Gérer DRENA, écoles, classes ; inviter la direction | ✅ | | ✅ |
| Émettre un code de récupération du PIN | ✅ | | ✅ |
| Publier une annonce nationale (ADR-0045) | ✅ | ✅ | ✅ |
| Lire les indicateurs agrégés ([ADR-0049](./0049-mesure-d-audience-cote-serveur-et-csp-stricte.md)) | ✅ | ✅ | ✅ |

**Invariant** : il reste toujours au moins un `admin` non anonymisé. Rétrograder ou anonymiser le dernier renvoie `:conflict`.

**Journal** : `invitation.sent`, `invitation.accepted`, `team_role.changed`.

## 5. Conséquences

### 🟢 Positives

- Aucun compte privilégié n'est créé par la console ni avec un PIN connu.
- La V4 ajoute les sous-rôles en changeant les policies, sans migration.
- C-20 est fermée pour l'équipe : un seul régime, TOTP pour tous.

### 🔴 Coûts consentis

- La colonne `team_role` existe en V1 sans servir : c'est le prix d'une V4 sans migration.
- Un jeton d'invitation transmis par un canal non sûr donne le compte à qui le lit en premier. La vérification du contact à l'acceptation limite ce risque sans le supprimer.
- « Gestionnaire DRENA » n'est pas un sous-rôle : `field` couvre tout le terrain.

## 6. Notes d'implémentation

```ruby
# db/migrate/…_add_roles_to_users.rb
add_column :users, :team_role, :string
add_check_constraint :users, "role IN ('student','teacher','school_admin','team')", name: "users_role_values"
add_check_constraint :users, "team_role IN ('admin','content','field')", name: "users_team_role_values"
add_check_constraint :users, "(role = 'team') = (team_role IS NOT NULL)", name: "users_team_role_iff_team"
```

## 7. Comment vérifier que la décision est respectée

- Test de schéma : un `teacher` avec `team_role` est refusé par la base.
- Test de use case : l'acceptation d'une invitation périmée donne `:expired` ; avec un autre contact, `:invalid`.
- Test de use case : rétrograder le dernier `admin` donne `:conflict`.
- En V4, un test paramétré parcourt la matrice : chaque cellule vide a son test de refus.

## 8. Remplace, complète, amende

- Ne remplace aucun ADR. Il **complète** l'ADR-0025, compensation 5, pour les sous-rôles (C-20), et retire `parent` de l'`enum` du glossaire §1.

## 9. Points à confirmer par le porteur

- Trois sous-rôles (`admin`, `content`, `field`) et la matrice ci-dessus.
- Pas de sous-rôle « gestionnaire DRENA ».
- Une invitation expire au bout de 72 heures.
