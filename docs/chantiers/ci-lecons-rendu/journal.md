# Journal — Rendu des leçons en CI

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-12 | Levier « attente par leçon » non joué | Le porteur a choisi le rendu ciblé, qui ramène le coût d'un train sans leçon changée de 98,7 à environ 3 min : l'attente devient marginale. | non |
| 2026-11-12 | Train : leçons changées seulement, sinon 2 témoins | Décision du porteur, coût en minutes de machine | oui, ADR-0131 |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [x] 2026-11-12 · ci-lecons-rendu · Que rend un train ? — tranché par le porteur : les leçons nouvelles ou modifiées seulement (2 ou 3 parts), sinon 2 leçons témoins.
- [x] 2026-11-12 · ci-lecons-rendu · Rendu complet hebdomadaire ? — tranché par le porteur : rendu complet seulement quand le train touche aux écrans (pas d'hebdomadaire).
- [ ] 2026-11-12 · ci-lecons-rendu · 10 leçons par part (décision du porteur) : ≈ 250 s pour 300 s ; sur #541 une part de 9 leçons a été coupée (installation de 1 min 40). — appliqué : 10 ; autres : 7 ; recommandé : garder 10 et repasser à 7 si une part est coupée au prochain train.

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
