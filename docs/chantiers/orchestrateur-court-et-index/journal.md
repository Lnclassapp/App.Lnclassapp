# Journal — Orchestrateurs courts et index des chantiers généré

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-05 | Tableau des chantiers par ordre alphabétique, pas par date | Deux branches qui ajoutent chacune un chantier touchent rarement des lignes voisines : git fusionne seul | non |
| 2026-11-05 | Sections « Chantiers ouverts », « Fermés » et « Chantiers de la refonte » remplacées par le tableau généré ; 22 lignes livrées retirées du backlog | Elles redisaient le statut des memos et changeaient à chaque clôture | non |
| 2026-11-05 | `fusionneur` sur Sonnet, pas Haiku | Une fusion ne se défait pas d'un clic | amendement ADR-0104 |
| 2026-11-05 | `etat.md` commité une fois par session, pas à chaque fusion | Sinon on recrée les commits d'index qu'on supprime | non |

## À trancher

- [ ] 2026-11-05 · orchestrateur-court-et-index · Passer `fusionneur` sur Haiku ? — appliqué : Sonnet ; autres : Haiku après 20 fusions sans erreur ; recommandé : Sonnet, revoir à la mesure du 1er décembre
- [ ] 2026-11-05 · orchestrateur-court-et-index · La colonne « Statut » reprend la tête de chaque memo : 10 memos ont un statut libre (« lots 0 », « preuve »…) — appliqué : laissés tels quels ; autres : normaliser leurs en-têtes ; recommandé : normaliser au fil des clôtures

## Ce qui a dérapé

- Revue `silent-failure-hunter` : 4 constats corrigés dans le lot. Le cache de `bin/ci-quiet` ne voyait ni les memos ni `origin/Develop` pour la garde d'index ; le pre-commit aurait commité un index nourri de fichiers non stagés (il refuse désormais) ; `grep -q` sous `pipefail` pouvait rater un memo dans un gros commit ; un memo sans `Statut` passait sans avertissement.
- Les tests lancés par le pre-commit héritaient de `GIT_DIR` : le dépôt jetable lisait le vrai. Le test vide les variables `GIT_*`.

## Ce qu'on a appris sur la codebase

- La garde `--check` ne voit `origin/Develop` que si la référence existe : sur une CI GitHub en clone superficiel, elle se limite à la branche, comme avant.

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-05 |
| **PR** | |
| **ADR produits** | amendement ADR-0104 |
| **UDR produits** | — |
