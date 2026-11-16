# Journal — Activation de l'élève : de l'inscription au premier exercice réussi

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-16 | Pas de changement de champs à l'inscription ; le message de bienvenue reste « Bienvenue dans ta classe ! » | Le numéro reste (porteur) ; la classe, le genre et le PIN sont des règles d'identité ; un niveau sans exercice publié n'aurait pas de carte : un message « Fais ton premier exercice » mentirait | Non (UDR) |
| 2026-11-16 | Une query de lecture `classroom` pour l'activation, qui réutilise la query « Prochain exercice » matière par matière | Aucun port, aucune table (ADR-0049, ADR-0062) ; la règle de choix existe déjà | Non (PRD §6) |
| 2026-11-16 | L'exercice de la carte sort de « À faire », quelle que soit sa source | Une porte par action (UDR-0173 règle 3) : pour l'élève seul, le premier exercice du programme peut aussi être un devoir | Non (UDR) |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-16 · activation-eleve · « Premier exercice réussi » : à partir de quelle note ? — appliqué : 10/20 arrondi (seuil de la moyenne de la notation) ; autres : 14/20 (maîtrise, seuil de « Refaire » d'avant) ; recommandé : 10/20
- [ ] 2026-11-16 · activation-eleve · L'élève seul (entré par la liste) dont la classe a des devoirs : la carte propose le programme ou le devoir ? — appliqué : le programme (le devoir reste dans « À faire ») ; autres : le devoir, comme l'élève amené ; recommandé : le programme
- [ ] 2026-11-16 · activation-eleve · « Refaire » dans l'historique de l'accueil : sur toute copie terminée, ou seulement sous 14/20 comme avant ? — appliqué : toute copie terminée, hors pause (le porteur veut pouvoir refaire ce qu'on a touché) ; autres : sous 14/20 ; recommandé : toute copie

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
