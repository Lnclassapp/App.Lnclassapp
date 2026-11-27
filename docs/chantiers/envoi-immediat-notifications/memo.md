# Memo — Notifications envoyées dès l'événement

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-27 |
| **Branche** | `feature/envoi-immediat-notifications` |
| **Programme** | — |

---

## Le problème

Une notification n'atteint l'élève qu'au passage suivant de la tâche d'envoi, et seulement dans deux fenêtres par jour (midi et soir). Un exercice assigné à 15 h n'est annoncé qu'à 18 h. Les relances (non terminé, résultat, inactif) n'ont pas de case dans l'administration : elles ne partent que si l'équipe les valide chaque jour dans un plan du jour, une routine que personne ne tiendra.

## Pour qui

- **Élève** : il est prévenu au moment où quelque chose le touche (un exercice assigné par son professeur, une annonce qui le concerne, un résultat ou une médaille) et il reçoit ses rappels à une heure raisonnable.
- **Équipe (admin)** : elle décide une fois pour toutes, motif par motif, ce qui part : une case cochée, ça part ; décochée, rien ne part.

## Pourquoi maintenant

L'envoi est ouvert sur les trois environnements depuis le 2026-11-27. Le porteur veut une règle simple avant que les élèves ne s'y habituent : l'événement part tout de suite, les rappels en journée, la case fait foi.

## Hors périmètre

- Notifications aux enseignants, aux directions ou aux parents : seul l'élève en reçoit.
- Un réglage par élève, par classe ou par établissement : la case vaut pour tous.
- Un choix d'heure par l'élève, un « ne pas déranger », des notifications par courriel ou SMS.
- Un nouveau motif : « Exercice assigné » est le motif « Nouveaux exercices » renommé.
- La suppression de l'historique des validations passées : il reste lisible.
- Le contenu (texte) des notifications, inchangé.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Faut-il un nouveau motif « exercice assigné » ? | Non : « Nouveaux exercices » (`assignment_new`) l'est déjà ; renommé « Exercice assigné » (orchestrateur, mot du porteur) | Pas de nouveau motif ni de requête ; un libellé change |
| Quels motifs ont une case ? | Tous, résultat/médaille et inactif compris (porteur) | La contrainte de base des réglages s'élargit aux sept motifs (migration) ; l'interdit de l'UDR-0187 sur les relances est levé |
| L'annonce garde-t-elle « Prévenir les élèves » ? | Porteur sans préférence ; appliqué par défaut : oui, en plus de la case générale ; l'annonce part si les deux sont cochées | Deux conditions pour l'annonce ; entrée « tranché par défaut » dans § À trancher |
| « Exercice non terminé » reste-t-il ? | Oui, avec sa case, décochée au départ (orchestrateur) | Aucun motif retiré |
| Que devient « À valider » ? | Retiré : plan du jour et « Valider l'envoi » disparaissent ; deux états, coché ou décoché ; l'historique garde les validations passées (porteur) | Écran, route, use case et tâche de 12 h 20 retirés ; la table des validations reste en lecture |
| À quelle heure partent les notifications ? | Événements (exercice assigné, annonce, résultat/médaille) tout de suite, à toute heure ; rappels (interro demain, devoir à rendre, non terminé, inactif) de 6 h à 21 h, heure d'Abidjan (porteur) | Les fenêtres midi/soir disparaissent ; deux familles de motifs ; un passage est demandé à chaque événement |
| Le plafond tient-il ? | Oui : 10 par jour et par élève, jour d'Abidjan (porteur) | Inchangé |

## Cas limites identifiés

- Un professeur assigne trois envois en une minute : trois passages demandés, un seul tourne à la fois (verrou du job), un motif par élève et par passage.
- Un élève atteint son dixième envoi : les événements suivants du jour ne partent pas, même à 23 h.
- Une annonce programmée paraît à 2 h du matin avec « Prévenir les élèves » et la case cochée : elle part à 2 h.
- Une case décochée pendant qu'un passage tourne : le passage déjà lancé a lu la case avant.
- Un motif dont la case est cochée alors qu'une validation passée existait : seule la case compte.
- Un rappel prêt à 21 h 05 : il attend 6 h le lendemain s'il est encore valide, sinon il est perdu.

## Questions encore ouvertes

- Médaille et résultat « tout de suite » : aujourd'hui le motif attend 2 h après une médaille et ne part pas si l'élève est revenu depuis ; envoyé à l'instant, il toucherait un élève déjà dans l'application, qui voit sa médaille. Posée à l'orchestrateur avant les lots (plan, § Décisions ouvertes).
