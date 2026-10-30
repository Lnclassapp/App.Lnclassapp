# Journal — Les 10 premières leçons de SVT de 3ème et leurs planches

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-30 | Lot P : le contexte de dessin passé à `draw` ajoute à `{ highlighted, el }` les aides `part`, `tube`, `sketch`, `pattern`, `uid`, `defs`, `label` ; `fill: "ghost"` pour une zone superposée à un dessin | Les 8 planches partagent surlignage, motifs et identifiants uniques sans importer `plate.js` ; la vague 4 n'a rien à changer dans `plate.js` | Non (détail d'UDR §3 plate) |
| 2026-10-30 | Lot D : `plate` exige `plate`, `labels` (non vide) et `numbering`, comme `diagram` exige `nodes` ; `figure_kinds.rb` charge `figure_catalogs` lui-même (l'enum des planches lit `PLATES` au chargement, hors Zeitwerk pour `valider.rb`) ; `item_range` (0..1) car aucun élément de `plate` ne porte de nombre | Cohérence avec la vague 2 ; une planche sans étiquette n'a pas de sens | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Les tests système demandent `yarn build` et `yarn build:css` sur un poste neuf (`application.css` introuvable sinon).

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
