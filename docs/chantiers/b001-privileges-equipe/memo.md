# Memo — B-001 : privilèges entre sous-rôles de l'équipe

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-11-08 |
| **Branche** | `fix/b001-privileges-equipe` |
| **Programme** | — (audit [`2026-11-08-bugs-code-mort.md`](../../audits/2026-11-08-bugs-code-mort.md), B-001, P1) |

---

## Le problème

**Symptôme** : un membre de l'équipe `content` ou `field` obtient `200` là où la matrice de l'[ADR-0038](../../decisions/adr/0038-comptes-de-l-equipe-et-sous-roles.md) lui refuse le geste :

- `POST /teams/members/:public_id/second-factor-reset` réinitialise le TOTP d'un autre membre, admin compris (ADR-0031 §4 et ADR-0038 : `admin` seul) ;
- `POST /accounts/:public_id/pin-recovery-codes` émet le code de récupération du PIN de tout compte, membre admin compris (ADR-0038 : `admin` et `field`, jamais `content`).

**Reproduction** (tests de contrôleur, rouges avant le correctif) : connecté `content`, émettre un code pour un admin, réinitialiser son TOTP, poser un nouveau PIN par `/identity/pin-reset`, enrôler son propre TOTP : le compte admin est pris.

**Portée** : depuis l'arrivée des sous-rôles (V4). Tout compte admin de l'équipe. Pas de donnée à réparer : le journal `audit_events` (`totp.reset`, `pin.recovery_code_issued`) dit qui a fait quoi ; à relire par le porteur (voir journal, À trancher).

## Pour qui

L'équipe (`team`), sous-rôles `content` et `field` ; la cible est un membre `admin`.

## Hors périmètre

- B-002 (second facteur de la direction) : chantier séparé.
- Pas d'ADR : la règle existe (ADR-0031, ADR-0038), le code ne la suivait pas.
- Pas d'UDR : on retire des boutons qu'un sous-rôle ne peut pas utiliser, sans nouvel état ni libellé.

## Cause

Les deux policies testaient `actor.team?` sans `actor.team_role` (`reset_second_factor_policy.rb:8`, `issue_pin_recovery_code_policy.rb:11`), alors que `InviteTeamPolicy` et `DeleteUserPolicy` le testent. Les tests ne construisaient que des acteurs `admin` ; le test du contrôleur de réinitialisation validait même un acteur `field`.

## Correction (un lot)

- `ResetSecondFactorPolicy` : `admin` seul, cible `team` autre que soi ; sans cible, refus (revue sécurité).
- `IssuePinRecoveryCodePolicy` : équipe `admin` pour tout compte sauf le sien ; `field` hors équipe ; `content` jamais (matrice ADR-0038).
- Recherche d'un compte (`teams/account_lookups/_result`) : les boutons suivent les deux policies (`Teams::AccountLookupsHelper`).

## Portes de sortie

- Tests de refus rouges avant le correctif, verts après : policies (domaine) et contrôleurs.
- L'admin garde ses deux gestes ; personne ne vise son propre compte.
- `bin/ci-quiet` vert sur le head final ; revue `security-reviewer` sur le diff final.
