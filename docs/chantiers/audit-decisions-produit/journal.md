# Journal — Décisions produit de l'audit

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-08 | Une seule PR (≈150 lignes de code applicatif) | Sous le seuil de 600 lignes de revue | non |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-08 · audit-decisions-produit · O-X04 : optimiser les requêtes 7/30 jours du Pilotage sans cache ? — appliqué : rien (aucune mesure ne le justifie, le code n'avait pas de cache 7/30) ; autres : `/optimize` avec EXPLAIN (EXISTS au lieu de `IN (subquery)`) ; recommandé : `/optimize` si le temps de page dépasse 1 s en production
- [ ] 2026-11-08 · audit-decisions-produit · B-046 : limiter aussi l'exercice/la session lus par adresse aux matières de l'enseignant ? — appliqué : non (hors décision) ; autres : l'étendre à `assessment/*` ; recommandé : non tant que le contenu reste commun

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

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
