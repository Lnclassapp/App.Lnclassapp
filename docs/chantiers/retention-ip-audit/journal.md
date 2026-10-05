# Journal — Rétention de l'adresse IP du journal d'audit

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-05 | Le porteur avait répondu à la question du grill dans le chantier `suites-inscription-direction` (« Gardée 12 mois puis effacée ») ; le cadrage reprend cette réponse sans nouvelle session de questions | La seule décision du chantier était déjà prise | Oui, ADR-0080 |
| 2026-10-05 | Challenger : les 5 points sont OK. 2 501 IP effacées en 63 ms (3 lots, 7 requêtes), seconde exécution à 0, refus `:forbidden` pour l'équipe ; l'index partiel est utilisé quand les statistiques le justifient. Suites : le nom de classe n'est plus répété dans le log (ActiveJob le met déjà en tag) ; l'écriture qui contourne `readonly?` est documentée dans l'ADR-0080 et dans le repository | Rapport du challenger | ADR-0080 §5 complété |
| 2026-10-05 | Tâche à 4 h 30, après la purge des directions (4 h) | Les tâches planifiées ne se chevauchent pas | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Le premier test du repository écrivait un `actor_id` inventé : `audit_events.actor_id` a une clé étrangère vers `users`. Il crée maintenant un vrai compte.
- `db:migrate` réécrit de nouveau toutes les contraintes `CHECK` de `db/schema.rb` (PostgreSQL local) : seuls l'index et la version ont été gardés.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| L'IP des sessions et des tentatives de connexion des comptes actifs n'a pas de rétention | Hors périmètre du memo : autres tables, déjà effacées à la suppression d'un compte | à décider par le porteur |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-05 |
| **PR** | [#176](https://github.com/Lnclassapp/App.Lnclassapp/pull/176) vers `Develop` |
| **ADR produits** | ADR-0080 |
| **UDR produits** | — (aucune vue) |
