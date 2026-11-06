# Journal — Base de leçons

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-06 | Les leçons à reprendre sont rangées par ce qui leur manque (3 dossiers) | la reprise se fera par vague, une vague par manque | non |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-06 · base-de-lecons · L'aperçu (`lib/tasks/apercu.rake`, `bin/apercu-lecon`) refuse tout fichier hors `docs/contenus/lecons-traitees/` : un fichier de `a-reprendre/` ne s'y prévisualise plus — appliqué : rien changé ; autres : accepter aussi `a-reprendre/` ; recommandé : l'accepter, pour travailler la reprise avec l'aperçu
- [ ] 2026-11-06 · base-de-lecons · `script/ci/scope.rb` (`LESSON_FILE`) ne connaît que `lecons-traitees/` : une PR qui ne touche que `a-reprendre/` est classée comme de la doc, sans test de rendu — appliqué : rien changé ; autres : ajouter `a-reprendre/` au motif ; recommandé : laisser ainsi tant que ces fichiers ne sont pas chargés
- [ ] 2026-11-06 · base-de-lecons · `V3ProgrammeLevels` non modifié : Staging ne trouvera plus de dossier de lycée dans `lecons-traitees/` (seul `3eme/` y reste), aucun test ne l'exige — appliqué : rien changé
- [ ] 2026-11-06 · base-de-lecons · `jeu.yml` : `sans_v3` vidé (`[]`), `StandardTestSet` l'accepte sans changement ; le jeu standard ne charge plus que 6 leçons (3ème). Empreinte d'activité de `standard_activity_test` recalculée (`8645917579`) — appliqué : tel quel

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
