# Memo — Annuaire de l'équipe

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | décision |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `feature/annuaire-equipe` (partie de `feature/espace-direction`, Lot 0a fusionné) |
| **Programme** | `refonte-application`, vague V2 ([feuille de route §5](../refonte-application/feuille-de-route.md#v2--organisation-scolaire-et-espace-direction)) |

---

## Le problème

L'équipe n'a aucune vue d'ensemble des comptes. Elle ne peut ni lister les comptes, ni ouvrir la fiche d'un compte, ni corriger une erreur de saisie, ni supprimer un compte proprement. L'ancienne application avait une fiche ouverte à tout connecté, qui exposait le contact. Sa suppression détruisait en cascade les sessions, les badges et les lacunes. La V2 ajoute le matricule de l'élève : un matricule usurpé ne se libère que par l'anonymisation du compte usurpateur (ADR-0065). Sans annuaire, l'équipe ne peut pas le faire.

## Pour qui

- **L'équipe (Team)** : elle retrouve un compte (par nom, numéro ou matricule entier), le consulte, le corrige, le désactive et l'anonymise.
- **Le titulaire du compte** : son compte est corrigé, désactivé ou anonymisé par l'équipe, jamais exposé à un autre utilisateur.

## Pourquoi maintenant

C'est le second chantier de la V2, ouverte par le porteur le 2026-09-28. Il doit être en production **avant l'ouverture aux élèves** : c'est lui qui libère un matricule usurpé (ADR-0065, PRD `espace-direction` §8).

## Hors périmètre

- **Modifier le matricule** : seul l'élève le corrige (ADR-0065).
- **Changer le rôle d'un compte** : jamais (question 1).
- **La matrice des sous-rôles de l'équipe** (qui voit quoi selon `admin`, `content`, `field`) : V4, ADR-0038.
- **L'annuaire pour la direction** : la direction a ses propres listes dans `espace-direction`.

## Ce que le grill a révélé

> Rempli au fil du grill, une question à la fois.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| 1. Sur la fiche d'un compte (ID-18), que peut modifier l'équipe ? | **Le nom, le genre et le numéro de téléphone.** Le rôle ne change jamais. Le matricule n'est jamais modifié par l'équipe. (porteur, 2026-09-28) | Changer le numéro ferme toutes les sessions du compte, et le nouveau numéro doit respecter le format et l'unicité. Chaque modification est journalisée (qui, quand, quels champs). ID-18 est réécrit : ce n'est plus la route générique `/users/:id/edit`. |
| 2. « Supprimer un compte » (ID-23) : l'anonymisation est-elle définitive d'emblée ? | **Non : désactiver d'abord.** Un état « désactivé », réversible, où le compte ne peut plus se connecter, puis l'anonymisation définitive. (porteur, 2026-09-28) | Un nouvel état du compte, donc un ADR : désactivation (sessions fermées, connexion refusée avec un message neutre), réactivation, puis anonymisation (ADR-0036). Un compte désactivé **garde** son matricule : seule l'anonymisation le libère. |
| 3. Quand l'anonymisation définitive a-t-elle lieu ? | **Automatiquement, 30 jours après la désactivation.** L'équipe peut aussi anonymiser avant, par exemple un usurpateur. (porteur, 2026-09-28) | Une tâche planifiée quotidienne (Solid Queue, ADR-0052) anonymise les comptes désactivés depuis 30 jours ou plus. Elle est idempotente et journalisée, et son échec est visible dans la supervision. La fiche d'un compte désactivé affiche la date d'anonymisation prévue. Une réactivation annule l'échéance. |
| 4. Où placer l'annuaire, alors que la navigation de l'équipe est pleine (5 entrées, UDR-0006) ? | **Fusionner avec « Débloquer un compte »** : l'entrée devient « Comptes » (recherche, liste, puis fiche avec débloquer, modifier, désactiver, anonymiser). (porteur, 2026-09-28) | La navigation reste à 5 entrées. Amendement de l'UDR de « Débloquer un compte » et de l'UDR-0006 (libellé). Le déblocage garde son parcours actuel, désormais depuis la fiche. Le Lot F d'`espace-direction` touche la même page : l'annuaire passe **après** sa fusion. |
| 5. L'équipe peut-elle désactiver ou anonymiser un compte de l'équipe ou de la direction ? | **Oui, sauf son propre compte et le dernier compte équipe `admin` actif.** (porteur, 2026-09-28) | Deux refus nommés et testés (« soi-même », « dernier admin »), vérifiés sous verrou pour que deux désactivations simultanées ne suppriment pas les deux derniers admins. Désactiver un membre de la direction termine son rattachement actif ; un Proviseur désactivé laisse l'établissement sans Proviseur jusqu'à une nouvelle invitation par l'équipe (ADR-0066). |
| 6. Comment chercher un compte parmi des milliers (ID-21) ? | **Une seule barre** : nom partiel, numéro de téléphone et matricule seulement **entiers**. Des filtres par rôle, état (actif, désactivé) et établissement. Liste paginée. (porteur, 2026-09-28) | La recherche par nom est insensible aux accents et à la casse, et indexée. Numéro et matricule en égalité stricte : aucune recherche partielle, qui permettrait de sonder. Les comptes anonymisés n'apparaissent pas. |

## Cas limites identifiés

> Tranchés par l'orchestrateur sur la délégation du porteur (2026-09-28), amendables.

- **Fiche d'un compte** : visible par l'équipe seule (second facteur exigé, comme tout l'espace équipe). Elle montre le nom, le genre, le rôle, le numéro, le matricule (élève), la fonction et l'établissement (direction), les classes (élève, enseignant), l'état, les dates de création, de désactivation et d'anonymisation prévue. Jamais le PIN, jamais le secret du second facteur. L'identifiant dans l'URL est l'identifiant public, jamais l'identifiant numérique.
- **Numéro déjà pris** à la modification : refus nommé « numéro déjà utilisé ». L'équipe est de confiance, et l'oracle est borné par le second facteur.
- **Compte désactivé** : ses sessions sont fermées. À la connexion, il reçoit un message neutre qui ne dit pas que le compte existe. Un élève désactivé reste dans les listes de sa classe, marqué « désactivé ». Ses résultats restent. Un enseignant désactivé garde ses classes, qui restent dans l'établissement.
- **Réactivation** : elle rend la connexion, sans rien restaurer d'autre. Un membre de la direction réactivé n'est pas rattaché de nouveau ; il faut une nouvelle invitation.
- **Anonymisation** (manuelle, ou automatique à 30 jours) : elle suit l'ADR-0036 amendé par l'ADR-0065. Le nom devient « Compte supprimé » ; le numéro, le matricule, la photo, le second facteur et les sessions sont effacés ; le rattachement à la direction est terminé. Les résultats restent dans les statistiques des classes. Elle est irréversible, avec une confirmation où l'équipe tape le nom du compte.
- **Usurpation d'un matricule** : l'équipe retrouve l'usurpateur par le matricule entier, le désactive, puis l'anonymise tout de suite. Le matricule redevient libre.
- **Tâche des 30 jours** : quotidienne et idempotente. Elle ignore un compte réactivé entre-temps. Elle journalise chaque anonymisation et signale son échec dans la supervision (ADR-0052).
- **Zéro résultat** : l'état vide dit quoi essayer (nom plus court, numéro complet). Mille résultats : pagination de 25.
- **Concurrence** : deux membres de l'équipe qui modifient la même fiche ; le dernier enregistrement gagne, et le journal garde les deux.

## Questions encore ouvertes

- Aucune question bloquante. Les délais (30 jours) et la taille des pages (25) sont des défauts amendables.
