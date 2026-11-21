# Journal — [Titre du chantier]

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-21 | Lot C : `PrepareSheetsQuery#call(only:)` ne construit (questions, copies, devoirs dus) que les exercices demandés ; numéro = rang dans la feuille entière ; seul `StudentAssignedSheetsQuery` le passe. | « Ma classe », médiane de 3 exécutions de `script/mesure/pages` (rôle élève) : allocations 114 963 → 54 483 (-52,6 %), p50 164,3 → 124,3 ms, p95 200,1 → 175,6 ms, SQL 91 → 91 (inchangé). Seuil de -30 % atteint. | Non |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- …

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Garde de requêtes (lot B) : le cache de requêtes survit d'une visite à l'autre dans un test d'intégration (compte faussé à 0), d'où `clear_query_cache` avant la visite comptée ; vérifiée en ajoutant 5 requêtes distinctes par devoir dans `StudentAssignedSheetsQuery#exercises` (« Ma classe » 53 pour un budget de 48, échec constaté, modification retirée) ; une seule requête par devoir (+3) ou un appel dupliqué à l'identique (mis en cache) passent sous la marge de 25 %.

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
