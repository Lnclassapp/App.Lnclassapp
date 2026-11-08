# Journal — B-001 : privilèges entre sous-rôles de l'équipe

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-08 | `content` n'émet plus aucun code de récupération du PIN, même pour un élève | Matrice de l'ADR-0038 (« Émettre un code de récupération du PIN » : `admin`, `field`) ; l'audit ne visait que la cible `team`, mais un code d'enseignant ou de direction ouvre aussi un compte | Non, l'ADR-0038 le dit déjà |
| 2026-11-08 | Les boutons de la recherche d'un compte suivent les policies | Un bouton qui répond 403 trompe ; même schéma que `can_delete` | Non |

## À trancher

- [ ] 2026-11-08 · b001-privileges-equipe · Relire `audit_events` (`totp.reset`, `pin.recovery_code_issued`) en production pour voir si un membre `content` ou `field` a visé un admin avant le correctif — appliqué : rien (session sans accès production) ; autres : requête lancée par le porteur ; recommandé : requête lancée par le porteur.
- [ ] 2026-11-08 · b001-privileges-equipe · `content` perd l'émission de codes pour élèves et enseignants (ADR-0038) — appliqué : refus, conforme à l'ADR ; autres : rendre ce droit et amender l'ADR-0038 ; recommandé : refus.

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- **Chaîne** : `Teams::SecondFactorResetsController#create` → `UseCases::Identity::ResetSecondFactor#call` → `ResetSecondFactorPolicy#call` ; `Identity::PinRecoveryCodesController#create` (`allow_roles :team, :teacher`) → `IssuePinRecoveryCode#call` → `IssuePinRecoveryCodePolicy#call`. Les contrôleurs ne filtrent que le rôle, jamais le sous-rôle : c'est le travail de la policy.
- **Pourquoi aucun test ne l'a vu** : `create_team_member` crée un `admin` par défaut ; les tests de policy n'avaient qu'un acteur `admin`, et les tests du contrôleur et du use case de réinitialisation prenaient un acteur `field`, celui de l'émission un acteur `content`, comme cas nominal.
- **Chemins contrôlés** : `ResetPinWithCode` (anonyme, exige un code émis par la policy) ; `ChangeOwnPin` (son compte) ; `AnonymizeUser` / `DeleteUserPolicy` (admin) ; `PurgeArchivedStaff` (direction archivée, système) ; `BeginSecondFactorEnrollment` / `SecondFactorPolicy` (sa propre session) ; `InviteTeamPolicy` (admin) ; `classroom/classroom_students/_manage` (enseignant, même policy). Aucun autre chemin ne réinitialise un TOTP ou n'émet un code.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| ADR-0032 (tableau des émetteurs, ligne `team`) ne nomme pas les sous-rôles | L'ADR-0038 le précise et prévaut ; amender 0032 est de la doc seule | — |
