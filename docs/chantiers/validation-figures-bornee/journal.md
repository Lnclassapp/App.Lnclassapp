# Journal — Validation des figures bornée

## Où part le temps (sur `aa72011`)

| Fichier et ligne | Coût | Chiffre |
|---|---|---|
| `figure.rb:279` `rooted?`, appelé pour chaque nœud par `tree_errors` (l. 276) | remontée de parent en parent, `seen.include?` sur un tableau : N³ sur une chaîne | 1,7 s à 1 000 nœuds, 11,5 s à 2 000 (×6,7 pour ×2), > 60 s à 5 000 |
| `figure.rb:246` `node_errors` | `nodes.select` pour chaque nœud : N² | inclus dans la ligne précédente |
| `figure.rb:222` `label_part_errors`, `figure.rb:211` `highlight` | `labels.index` / `highlight.index` dans la boucle : N² | 653,6 ms à 5 000 |
| `figure.rb:70` `geometry_errors` | `ids.count(id)` dans la boucle : N² | 116,7 ms à 5 000 |
| `figure.rb:162` `area_errors` | `seen.include?` sur un tableau : N² | 50,6 ms à 5 000 |

Tous tournent après le refus de borne : `required_errors` appelait `<sorte>_errors` sans regarder `params_errors`.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-30 | La coupure se pose une fois, dans `required_errors` (`oversized?`), pour toutes les sortes ; la garde propre à `molecule_errors` est retirée | Une seule règle au lieu d'une garde par sorte ; la garde de `molecule` devenait une branche morte | Non : ni port, ni borne, ni code d'erreur ne change |
| 2026-10-30 | Le test « plate : bornes de 12 étiquettes » attend `params.labels` seul, plus `params.labels[12].part` | Effet voulu de la coupure : une figure refusée pour sa taille ne reçoit plus les violations secondaires de cohérence | Non |
| 2026-10-30 | `first_indexes` (première apparition par valeur) remplace `index` / `select` dans `node_errors`, `label_part_errors` et `highlight` ; `rooted?` reçoit tous les nœuds et mémorise ceux déjà reconnus | Un seul parcours ; même règle « la première apparition gagne » | Non |

## Ce qui a dérapé

- La revue des tests a montré qu'aucun test ne fixait la frontière de la coupure (`>` changé en `>=` restait vert) : ajout d'un test « liste pile à sa borne » (12 points, un doublon refusé). Le test de garde `plate` met aussi 5 000 surlignages.
- Premier bench `map` et `plate` trop gentil (identifiants tous inconnus, ou aire connue dès le rang 0) : `known.include?` court-circuitait la recherche quadratique. Le pire cas est une moitié inconnue suivie d'une valeur connue répétée.

## Leviers abandonnés

- Aucun. Les deux leviers ont un gain mesuré séparément (memo, « Mesures après ») : la coupure rend le coût constant, `Set`/`Hash` le rend linéaire.

## Ce qu'on a appris sur la codebase

- `params_errors` refuse une liste trop longue sans parcourir ses éléments : avec la coupure, une figure hors borne ne coûte plus que la lecture de `size`.
- Sous les bornes (12 nœuds, 40 aires), l'ancien code était rapide : le risque ne venait que de l'absence de coupure.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| — | | |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-30 |
| **PR** | vers `Develop` depuis `perf/validation-figures-bornee` |
| **ADR produits** | — |
| **UDR produits** | — |
