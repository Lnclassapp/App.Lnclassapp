# Memo — Espace direction, version simple

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `feature/espace-direction-simple` |
| **Programme** | `refonte-application`, vague V2 ([feuille de route §5](../refonte-application/feuille-de-route.md#v2--organisation-scolaire-et-espace-direction)) |

---

## Le problème

Un établissement existe dans Lnclass, avec ses classes, ses enseignants et ses élèves. Pourtant, sa direction n'y a aucun accès : elle ne sait ni quels enseignants utilisent l'application, ni si les élèves font leurs devoirs.

La V2 avait été conçue en grand (chantier `espace-direction` : matricule de l'élève, quatre fonctions avec des droits différents, retrait d'enseignants, changement de classe, code d'établissement, ajout de classes). Le porteur l'a jugée trop lourde (2026-09-28) : « la liste des enseignants, et le travail des élèves. Aussi simple. Pas de choses compliquées. » Les vrais besoins viendront des échanges avec de vraies directions.

## Pour qui

- **La direction (SchoolStaff)** : un seul type de compte, invité par l'équipe. Elle **lit** deux pages sur son seul établissement : ses enseignants, et le travail de ses élèves classe par classe, puis élève par élève.
- **L'équipe (Team)** : elle invite la direction d'un établissement, depuis la fiche de l'établissement.
- **L'enseignant et l'élève** : rien ne change pour eux. Ils sont seulement vus.

## Pourquoi maintenant

La V1 est close et en production. La V2 est la vague suivante ; le porteur l'ouvre sous cette forme réduite le 2026-09-28, pour mettre un outil devant de vraies directions et apprendre d'elles.

## Hors périmètre

Au backlog, avec la conception complète gardée sur la branche distante `feature/espace-direction` :

- le **matricule** de l'élève ;
- les **fonctions** de direction (Proviseur, Censeur, Éducateur, Secrétaire) et leurs droits ;
- le **personnel** : une direction qui invite une autre direction, le départ d'un membre ;
- **retirer ou réintégrer** un enseignant ; **changer un élève de classe** ;
- le **code d'établissement** (lire, régénérer) et l'**ajout de classes** : ils restent à l'équipe ;
- **valider les enseignants en attente** : la direction ne le fait pas ; les garants et l'équipe valident (ADR-0063, inchangé) ;
- un **tableau de bord** élaboré (compteurs, périodes, historique) ;
- le **second facteur** de la direction ;
- toute **écriture** par la direction, hors son propre profil (nom, numéro, PIN, photo, déjà livrés) ;
- l'**annuaire de l'équipe** (chantier `annuaire-equipe`), le **multi-établissement** de l'enseignant, le **changement d'établissement** d'un élève ;
- les **parents**.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| La conception complète d'`espace-direction` (65 critères) est-elle le bon point de départ ? | **Non** : « une usine à gaz ». D'abord la liste des enseignants et le travail des élèves. (porteur, 2026-09-28) | Nouveau chantier court. `espace-direction` et `annuaire-equipe` passent au backlog, leur conception reste sur leurs branches. |
| Comment la direction obtient-elle son compte ? | **Invitée par l'équipe**, par un lien à usage unique pour un établissement, comme les comptes de l'équipe. **Un seul type de compte**, sans fonction. (porteur) | On réutilise l'invitation de l'équipe (type « direction » déjà prévu). La fonction disparaît du rattachement et de l'invitation : amendement de l'ADR-0044. |
| Faut-il un second facteur ? | **Non** : téléphone et PIN, comme les enseignants. (porteur) | Amendement de l'ADR-0044, qui l'exigeait. La direction lit des noms et des scores de mineurs avec un PIN seul : coût consenti dans le nouvel ADR, compensé par la lecture seule et le périmètre d'un établissement. |
| Que voit la direction ? | **Deux pages, en lecture seule** : Enseignants (nom, matière, classes) ; Travail des élèves (par classe : élèves, devoirs donnés, taux de rendu, moyenne, « — » sous 5 élèves ayant rendu), puis **le détail d'une classe** : chaque élève, ses devoirs rendus et son score moyen. (porteur) | Le grill 9 d'`espace-direction` (« aucune note d'élève nommé ») est levé par le porteur : la direction voit le score moyen de chaque élève de son établissement. Réutiliser les définitions du pilotage (ADR-0062). |
| Jusqu'où va son accès ? | **Son seul établissement.** Aucune écriture. (porteur) | Un test de refus inter-établissements sur chaque page. L'établissement vient toujours du compte, jamais de l'adresse. |
| Q1 : la direction valide-t-elle les enseignants en attente ? | **Non.** (porteur) | ADR-0063 inchangé. |
| Q2 et Q3 : code d'établissement, ajout de classes ? | **Restent à l'équipe pour l'instant.** (porteur) | ADR-0057 et ADR-0059 inchangés. |

## Cas limites identifiés

- **Numéro déjà lié à un compte** (un enseignant qui dirige aussi) : l'invitation est refusée, comme pour l'équipe. Un numéro, un compte.
- **Établissement inactif** : l'équipe ne peut pas y inviter une direction. Une direction déjà rattachée garde la lecture (rien ne s'écrit).
- **Plusieurs directions** pour un établissement : permis, sans limite. Une direction n'a qu'un établissement.
- **Élève parti ou compte anonymisé** : absent des listes et des chiffres. Tout se lit sur les élèves présents.
- **Classe archivée ou d'une autre année** : absente. Seules les classes actives de l'année comptent.
- **Enseignant en attente de validation** : absent de la liste (il n'est pas encore de l'établissement).
- **Zéro** : aucune classe, aucun enseignant, aucun élève, aucun devoir : chaque page a son état vide ; un taux ou une moyenne sans donnée s'affiche « — ».
- **Retirer une direction** : aucun geste dans ce chantier (voir « Questions encore ouvertes »).

## Questions encore ouvertes

- **Retirer une direction invitée par erreur, ou partie** : sans écran avant `annuaire-equipe`. D'ici là, un lien non utilisé expire seul en 72 h ; un compte déjà créé ne se retire qu'en console. À confirmer par le porteur.
- **« Moins de 5 rendus »** est lu comme « moins de 5 élèves ayant rendu » (définition déjà acceptée dans la conception complète). À confirmer.
