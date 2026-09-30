# Journal — Importer plusieurs fichiers de cours en une fois

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-30 | Cible de durée revue de 15 s à 20 s pour 500 cours, après mesure | Contrôle du schéma, nettoyage du HTML et règles métier sont incompressibles sans parallélisme (grill, question 8) | Oui, ADR-0068 |
| 2026-09-30 | Les noms des fichiers vivent dans `import_reports.files` dès la création du rapport, et les queries n'y joignent plus les pièces jointes | `has_many_attached` aurait dupliqué les lignes de l'historique à chaque fichier. Les noms en `jsonb` suppriment la jointure sans N+1 | Oui, ADR-0068 (rapport) |
| 2026-09-30 | Les trois queries des imports (`import_report`, `import_reports`, `team_home`) ont été adaptées dès le Lot 0, au lieu du Lot A | Le passage à `has_many_attached :sources` les cassait. Le même exécutant tient les deux lots, donc il n'y a aucune collision | Non |
| 2026-09-30 | Le test du Lot C modifie le test système existant du rechargement (attente ramenée de 8 s à 2 s), au lieu d'un nouveau fichier | C'est le même comportement, et un second test aurait dupliqué sa mise en place | Non |
| 2026-09-30 | Une erreur de schéma sur la racine d'un fichier, ou une cible inconnue, refuse ce seul fichier, comme un JSON illisible | C'est la même logique : le fichier ne peut pas être lu comme un envoi valide. Pour un seul fichier, rien ne change | Oui, ADR-0068 |
| 2026-09-30 | ADR-0068 et UDR-0055 laissés « Proposé » | L'acceptation revient au porteur, qui a délégué les décisions de la nuit mais pas la signature | — |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
