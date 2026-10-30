# Journal — Leçons de 3ème en Histoire-Géographie, et leurs figures

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-30 | `CONTROL_BOUND` passe de 1 000 à 3 000 (figure_kinds.rb) | Les bornes d'un curseur de frise sont des années (jusqu'à −3000..2100) : à 1 000, le curseur `start` du Lot A était refusé. | Non (constante, amende ADR §4.2) |
| 2026-10-30 | Garde de `figure.rb` écrite `defined?(…) \|\| require_relative(…)` | Même effet que `require_relative … unless defined?`, mais la branche `then` n'existe qu'hors Zeitwerk (valider.rb) et la couverture de branches de 100 % ne peut pas l'atteindre ; `\|\|` n'est pas une branche. Un test lance un sous-processus qui ne charge que figure_kinds et figure. | Non |
| 2026-10-30 | Lot B : la légende est dessinée sous le cadre, le `viewBox` de la carte est donc 640 × (cadre + légende), le cadre du fond restant 640×640 (CI, Afrique) ou 640×360 (monde) | UDR §3 demande la légende dans le SVG, sous le dessin ; la hauteur dépend du nombre de lignes (catégories, numéros de repli, attribution). | Non (précise UDR §3) |
| 2026-10-30 | Lot B : contour des aires sans catégorie en `muted` (trait 0,8 à 60 % d'opacité) au lieu de `grid` | `grid` (bordure de champ) est presque invisible sur le fond blanc de l'application : un fond d'Afrique ou du monde ne se lisait plus. Aucune couleur nouvelle, seulement un autre jeton. | À confirmer à la clôture (écart à UDR §3) |
| 2026-10-30 | Lot B : zones naturelles de la CI = cellules convexes prioritaires (littoral, montagnes, savane + « V Baoulé », forêt = reste) découpées sur le contour Natural Earth 1:50m du pays, puis fusionnées | Les arêtes des 14 districts geoBoundaries ne se recollent qu'à 75 % : on ne peut pas en déduire le contour du pays. | Non |
| 2026-10-30 | Lot B : `world.js` exporte aussi `CONTINENT_NAMES` ; `map.js` redessine quand le rapport `--figure-text` change (ResizeObserver) | Le titre d'un continent coloré ; un cadre masqué (`:empty`) n'a pas de largeur au premier dessin, la mise en page des étiquettes doit suivre la largeur réelle. | Non |

- Écart retenu : le contour des aires sans catégorie est tracé en `muted` (au lieu de `grid`, illisible), voir la décision du lot B ci-dessus.
- Lot G, corrections de revue (domaine, `Figure.errors_for`, donc import et `valider.rb` ensemble) : graduations comptées sans division entière ; route d'un lieu à lui-même refusée ; libellé blanc refusé (lieu, route, arête) ; légendes de carte et de schéma faites de textes non vides ; curseurs de frise bornés (`start` < `end`, `end` > `start`, au plus 200 graduations aux extrêmes). Script `fonds_de_carte.rb` : écriture via `.part` puis renommage, JSON illisible signalé avec « supprimer pour retélécharger ».
- Hors périmètre, à traiter plus tard : `coordinate_plane.js:53`, l'identifiant du `clipPath` repart de zéro à chaque figure (deux repères sur une même page se mélangent).

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot B : la bande littorale, calculée comme enveloppe convexe de la côte relevée de 0,23°, a d'abord pris la frontière est (lon −2,6) pour de la côte et coupé le pays en diagonale. Corrigé en n'échantillonnant que les longitudes où le pays touche la mer (lat < 5,8).
- Lot B : un seul `d` par zone exige de fusionner les morceaux convexes ; les ponts dégénérés de Sutherland-Hodgman (sur un sujet concave) s'annulent comme les frontières internes, par suppression des arêtes parcourues dans les deux sens.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `Coverage` ne garde que la dernière charge d'un fichier : un test qui recharge un fichier avec `load` détruit sa couverture.

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
