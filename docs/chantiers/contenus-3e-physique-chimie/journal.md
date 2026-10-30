# Journal — Les 10 premières leçons de Physique-Chimie de 3ème

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-30 | Lot P : avec `numbering: "numbers"`, les numéros suivent l'ordre du tableau `labels` (1, 2, 3…), pas celui des parties de la planche. Les 3 leçons à planche sont déjà écrites dans cet ordre. | Règle réelle de `plate.js` (index + 1) | Non |
| 2026-10-30 | Lot V (corrections après revues) : molécule bornée avant tout calcul (50 000 atomes refusés en moins de 0,5 s), clés d'un autre mode refusées (œil, alcane, dessin libre), curseur `carbons` entier, `bonds: []` accepté, liaison en double refusée (serveur et molecule.js). Dans figure_controller, le callback des modules ne fait que mémoriser le texte pendant un geste de curseur ; il écrit la zone live tout de suite hors curseur (poignées de géométrie). | Revues de sécurité et de tests de la PR | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Le contrôleur écrasait la mesure annoncée par le module avec le libellé du curseur : corrigé au lot D (`this.spoken`). Toute nouvelle sorte qui annonce doit passer par ce callback.
- Étiquettes de l'optique superposées et texte de l'œil coupé à 390 px : vu seulement sur les captures, aucun test ne le prenait. Les captures à 390 px se font avant la revue, pas après.
- La fusion de la vague 3 a touché 6 fichiers partagés (sortes, contrôleur, prompt, tests) : la règle « ajouter en fin de liste » a rendu chaque conflit mécanique.
- Les revues ont trouvé ce que les tests ne voyaient pas : validation quadratique d'une molécule (18 s pour 20 000 atomes) et figures acceptées au serveur mais cassées au navigateur (curseur non entier, clés d'un autre mode, liaison en double). Corrigé au lot V.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `required_errors` appelle `<sorte>_errors` même quand `params_errors` a déjà refusé la taille d'une liste : chaque validateur de sorte doit borner lui-même sa boucle.
- `plate.js` numérote les étiquettes dans l'ordre du tableau `labels`, pas des parties.
- Une partie de planche peut avoir plusieurs formes (`water` de l'eudiomètre) : un test d'ancrage accepte n'importe laquelle.
- La page de révision n'affiche que les figures que ses sections citent : le nombre de figures affichées n'est pas celui du fichier.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `geometry_errors` a la même boucle quadratique (`ids.count` dans la boucle, sans garde de taille) | Code d'une autre vague, hors périmètre | À ouvrir : `validation-figures-bornee` |
| Marge du libellé de curseur à 390 px dans le contrôleur partagé | Fichier partagé par toutes les sortes | Même suivi ou chantier UI |
| Couverture 100 % lignes et branches non mesurée par fichier (SimpleCov mélange les processus) | Outillage | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-30 |
| **PR** | PR unique `feature/contenus-3e-physique-chimie` → `Develop` |
| **ADR produits** | Aucun (applique l'ADR figures-des-matieres-de-3eme) |
| **UDR produits** | Aucune (applique l'UDR figures-des-matieres-de-3eme) |
