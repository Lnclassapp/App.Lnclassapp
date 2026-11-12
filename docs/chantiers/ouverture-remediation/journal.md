# Journal — La fiche s'ouvre sous l'Or

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-09 | `GapDecision` reçoit `treated:` ; une copie sans réponse n'ouvre ni ne compte | Aucune médaille = hors remédiation (consigne) ; avant, 0 % ouvrait | ADR-0043 (2) |
| 2026-11-09 | Pas de migration ni de réouverture rétroactive | La clôture seule ouvre ; les fiches se rouvrent à la prochaine séance sous l'Or | ADR-0043 (2) |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-09 · ouverture-remediation · Une copie sans réponse n'ouvre plus de fiche (elle en ouvrait une à 0 %) — appliqué : n'ouvre rien ni ne compte ; autres : garder l'ouverture à 0 % ; recommandé : appliqué
- [ ] 2026-11-09 · ouverture-remediation · Le compteur d'échecs compte un Argent — appliqué : oui ; autres : ne compter que sous 10/20 ; recommandé : appliqué
- [ ] 2026-11-09 · ouverture-remediation · Deux clôtures concurrentes qui ouvrent la même fiche : `KnowledgeGapRepository#open` avale `RecordNotUnique` sans compter l'échec (plus probable depuis l'ouverture à l'Argent) — appliqué : rien (hors diff) ; autres : incrémenter dans le `rescue` ; recommandé : incrémenter, dans un chantier de suivi

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
