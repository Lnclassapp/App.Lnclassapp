# Journal — Sous-rôles de l'équipe appliqués

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Cadrage écrit sur les recommandations, en attente des réponses du porteur aux questions 1 à 10 du memo | Le porteur a lancé les vagues V2 à V6 d'un coup ; les décisions sont proposées, pas prises | ADR-0100 et UDR-0116 à 0118 `Proposé` |
| 2026-10-16 | Contrôle par **capacité** nommée (`Actor#may?`), pas par constante `TEAM_ROLES` dans chaque policy | 27 policies concernées : une seule matrice testable case par case | ADR-0100 §4.2 |
| 2026-10-16 | Changer un sous-rôle depuis la fiche « Débloquer un compte », sans attendre `annuaire-equipe` | L'annuaire est au backlog ; la fiche existe et porte déjà la réinitialisation du TOTP | ADR-0100 §4.3, UDR-0118 (question 5 et 8) |

## Ce qui a dérapé

- Rien à ce stade (cadrage).

## Ce qu'on a appris sur la codebase

- **6 policies sur 27** lisent déjà `team_role`, chacune avec sa propre constante : `InviteTeamPolicy`, `DeleteUserPolicy` (admin) ; `ManageArticlesPolicy` (admin, content) ; `InviteSchoolStaffPolicy`, `RemoveSchoolStaffPolicy`, `RestoreSchoolStaffPolicy` (admin, field). Les 21 autres testent `team?`.
- `ResetSecondFactorPolicy` laisse **tout membre** réinitialiser le TOTP d'un autre : l'ADR-0031 prévoyait `admin` « à partir de la V4 ».
- Mission Control (`/teams/jobs`) hérite de `Teams::BaseController` par `config.mission_control.jobs.base_controller_class` (`config/application.rb`) : seule garde, le rôle `team` et le second facteur.
- L'action d'audit `team_role.changed` est déclarée (`Entities::Identity::AuditAction`) sans aucun émetteur.
- L'écran d'invitation fait déjà choisir le sous-rôle et décrit des accès restreints (`config/locales/teams/invitations.fr.yml`, `team_role_hints`) que le code n'applique pas : des membres « Contenu » ou « Terrain » peuvent exister en production avec un accès presque complet.
- Le Pilotage exige aujourd'hui `ReadIndicatorsPolicy` **et** `ReadUserPolicy` pour s'afficher : restreindre la lecture nominative sans le découper aurait fermé le Pilotage au contenu.
- `ImportKind` porte déjà une policy par type (`authorize_report`) : le filtre des imports par sous-rôle n'attendait que des policies qui lisent le sous-rôle.
- L'acteur est relu en base à chaque requête (`UserRepository#actor_for`) : un changement de sous-rôle vaut dès la page suivante, sans toucher aux sessions.
- La feuille de route place ce chantier **après** `annuaire-equipe` (tableau de collision V2/V4) ; l'annuaire n'a pas de dossier de chantier au 2026-10-16.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Liste des membres de l'équipe, départ d'un membre, révocation d'une invitation | Hors périmètre (memo) | `annuaire-equipe` (V2, backlog) |
| `manage_schools` groupe des gestes de poids très différents (supprimer un établissement, valider un enseignant) | Le porteur n'a pas demandé de les séparer ; un amendement de l'ADR-0100 suffira | — |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | ADR-0100 *(Proposé)* |
| **UDR produits** | UDR-0116, UDR-0117, UDR-0118 *(Proposés)* |
