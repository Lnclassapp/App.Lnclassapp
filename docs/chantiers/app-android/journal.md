# Journal — App Android pour élèves et enseignants

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-30 | Android d'abord, Hotwire Native, deux apps ; établissements sur le web ; PWA et iOS au backlog | Stratégie fixée par le porteur, puis grill de 15 questions (memo) | Oui : ADR-0070, proposé |
| 2026-09-30 | Les notifications poussées sortent du chantier vers `notifications-push` | Le chantier ne tenait plus dans une PR (grill, question 14) | Non : l'ADR viendra avec `notifications-push` |
| 2026-09-30 | Chantier mis en attente après le grill et l'ADR, sans PRD ni plan | Décision du porteur | — |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- La stratégie mobile a changé trois fois (février, juin, septembre 2026) dans des dépôts successifs sans jamais entrer dans celui-ci : il a fallu fouiller 25 dépôts et leurs branches pour la retrouver. D'où l'ADR-0070 écrit avant même le PRD.
- Le numéro d'ADR 0069 était déjà pris sur une branche non fusionnée (`perf/ci-quota`) : vérifier toutes les branches distantes, pas seulement `Develop`, avant de numéroter.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- La table `sessions` enregistre déjà le User-Agent, et le use case d'authentification le reçoit : la détection de l'app et le refus par rôle se branchent sans nouveau paramètre de bout en bout.
- Les liens à ouvrir dans les apps existent déjà : `/c/:code` et `/join` (classe), `/teacher-signup` et `/e/:code` (inscription enseignant), `/invitations/:token` (direction et équipe, restent au navigateur).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Notifications poussées (quatre événements, résumés, heures calmes) | Trop gros pour la même PR | `notifications-push` |
| Apps et notifications de la direction et de l'équipe ; notification de test de l'équipe | Hors du premier public | à nommer |
| App iOS | Exige un Mac ; public sur Android | à nommer |
| PWA installable | Placée au backlog par le porteur | `installation-pwa` (V4) |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
