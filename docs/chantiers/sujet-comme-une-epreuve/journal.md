# Journal — Le sujet se lit comme une vraie épreuve

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-04 | `_sheet` rend `_paper` par un `if/else` de partiel, pas par un `return` | un `<% return %>` dans un partiel ERB n'est pas fiable (syntaxe, rendu partiel) | Non |
| 2026-11-04 | La mention de statut de l'équipe n'apparaît que pour un brouillon (« Brouillon — visible uniquement par l'équipe ») | UDR §3.4 : « la mention Brouillon existante si l'exercice est en brouillon » ; « Publié » disparaît de la lecture | Non |
| 2026-11-04 | Éléments d'une question à ordonner, relier, choisir : rendus en simples listes `ul.ps-paper-items` par `_paper`, pas par les partiels `kinds/*` | ces partiels contiennent select et boutons : interdits sur l'épreuve (« jamais de champ ») | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Challenger à 390 px : le tableau de QCM à colonnes fixes coupait les mots au milieu (« prop|riété ») et les formules ; une colonne en `table-layout: auto` débordait de 25 à 166 px (formules des affirmations, jusqu'à 6 propositions). Solution retenue : sur téléphone, la ligne devient une grille, propositions deux par deux, lettre en tête (UDR §3, ajout du 2026-11-04).
- Une première mesure « 0 débordement » était fausse : le script de captures avait échoué (serveur arrêté) et `grep -c` comptait 0. Toujours lire la sortie entière d'une mesure, pas seulement un compteur.
- `bin/rails test:system <fichier>` ignore le fichier et lance les 573 tests système : utiliser `bin/rails test <fichier système>`.

- Les tests de lecture lisaient `turbo-frame#sheet-exercise-<id>`, `.ps-title`, `.ps-remember`, `.ps-progress` : la lecture est désormais une `section` du même id (pas de cadre), le reste vit sur la page à remplir. 16 tests repointés, aucun affaibli.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Nokogiri (assert_select) ne connaît pas `:is()` : écrire des sélecteurs séparés par des virgules.
- `rails-i18n` français : `one` couvre 0 ≤ n < 2, donc « (1,5 point) » au singulier, comme en français.
- Conséquence de l'UDR : la page de lecture d'un devoir de « Ma classe » n'affiche plus « À rendre le … » (`subtitle` ignoré) ; l'échéance reste sur la case et sur la feuille à remplir.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Au-delà de 26 questions dans un exercice, la lettre `(96 + number).chr` sort de l'alphabet (« { » après « z ») | motif déjà présent sur la feuille à remplir ; aucun sujet n'en a plus de 10 | aucun : à reprendre si un sujet dépasse 26 questions |
| Les tests d'épreuve renforcés après la revue n'ont pas été vus rouges (le code était déjà conforme) | le rendu existait avant les tests | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-04 |
| **PR** | [#466](https://github.com/Lnclassapp/App.Lnclassapp/pull/466) vers `Develop` |
| **ADR produits** | — |
| **UDR produits** | UDR-0152 (amende UDR-0151 §3) |
