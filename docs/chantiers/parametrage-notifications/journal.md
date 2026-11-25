# Journal — Paramétrage et confirmation des notifications par l’équipe

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## À trancher

- [ ] 2026-11-25 · parametrage-notifications · Grill 2 sans réponse : un motif validé part-il vers les élèves devenus concernés après la validation ? — appliqué : non, liste figée à la validation (ce que l'équipe a vu = ce qui part), relue avant l'envoi ; autres : motif ouvert toute la journée, revalidation d'un complément ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications · Grill 7 sans réponse : l'équipe valide le motif entier, par établissement, ou élève par élève ? — appliqué : motif entier, avec la répartition par établissement affichée ; autres : case par établissement, élève par élève ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications · Heure limite de validation — appliqué : jusqu'à la fermeture de la dernière fenêtre du jour (20 h) ; après, refus ; autres : midi ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications · La règle « 4 h entre deux envois » (`PUSH_MIN_INTERVAL_HOURS`) — appliqué : retirée ; le porteur a fixé un plafond de 10 par jour et par élève (2026-11-25), la variable n'est plus lue ; recommandé : appliqué.
- [ ] 2026-11-25 · parametrage-notifications · Écart minimal entre deux notifications d'un même élève, avec le plafond de 10 par jour — appliqué : un motif par passage de la tâche (15 min) ; autres : 30 min, 1 h ; recommandé : 1 h si la tuile du Pilotage montre des élèves qui coupent les notifications.
- [x] 2026-11-25 · parametrage-notifications · Grill 5 : qu'est-ce qui distingue « À valider » d'« Automatique » une fois que les motifs non validés partent seuls à 17 h ? — appliqué : « À valider » apparaît le matin dans le plan du jour, l'équipe le valide (départ 12 h) ou le retire, sans geste il part à 17 h ; autres : revenir sur 17 h (rien ne part sans geste), deux modes seulement (Automatique retirable, Coupé) ; recommandé : appliqué. → Porteur : un motif est automatique tant que sa case est cochée dans l'administration.
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
