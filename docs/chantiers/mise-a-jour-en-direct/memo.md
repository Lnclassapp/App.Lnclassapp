# Memo — Mise à jour en direct

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-09-30 |
| **Branche** | `feature/mise-a-jour-en-direct` |
| **Programme** | — |

---

## Le problème

Après un import (DRENA, établissements, cours complets, fiches, exercices), le suivi affiche le bilan, mais l'écran derrière ne change pas : la liste des DRENA, des établissements ou des cours, ou le contenu d'un cours, reste celle d'avant l'import. Le porteur doit recharger la page à la main pour voir les nouvelles lignes. C'est la règle écrite aujourd'hui : « l'équipe recharge ou rouvre l'écran pour voir les nouvelles lignes » (décision d'interface des imports de DRENA).

Plus largement, la stack prévoit que chaque création, modification ou suppression mette la page à jour sans rechargement complet. Un relevé rapide trouve 57 actions de ce type : 42 le font, et parmi les 15 autres, quatre sont à vérifier (génération des classes par l'équipe, demandes d'adhésion d'enseignants, numéro et PIN du profil, partage du lien de parrainage). Les autres sont des parcours pleine page (connexion, inscriptions, rejoindre une classe), où une redirection est le comportement voulu.

## Pour qui

- **Équipe** : c'est elle qui importe, et elle seule.
- **Enseignant et élève** : concernés seulement si l'une des actions à vérifier les touche (profil, parrainage).

## Pourquoi maintenant

Le multi-import (jusqu'à 50 fichiers de cours) et l'import des DRENA sont en place : l'équipe importe beaucoup, et chaque import se termine par un rechargement manuel. Décision du porteur, 2026-09-30 : rafraîchir en fin d'import, sans WebSocket.

## Hors périmètre

*Première version, à durcir pendant le grill.*

- Une mise à jour ligne par ligne pendant l'import (elle exigerait des WebSockets et un nouvel ADR).
- Les parcours pleine page qui redirigent volontairement (connexion, déconnexion, inscriptions, rejoindre une classe, PIN oublié, second facteur, démarrer un exercice).
- Toute modification des imports eux-mêmes (formats, règles, bilans).

## Ce que le grill a révélé

> Rempli au fil du grill, une question à la fois.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Que voit l'équipe quand l'import se termine, alors que le bilan est dans une modale par-dessus la liste ? | **Le bilan reste ouvert, la liste se met à jour derrière**, sans bouger le défilement ; l'équipe ferme la modale après lecture | Le rafraîchissement doit **préserver la modale et son bilan** : un rechargement ordinaire de la page les ferait disparaître. La modale doit rester en place pendant la mise à jour de la page, et l'état de fin du suivi n'est plus rechargé ensuite |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
