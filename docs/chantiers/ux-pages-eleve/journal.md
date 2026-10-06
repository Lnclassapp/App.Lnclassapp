# Journal — Amélioration UI/UX des pages élève

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-06 | Pas de mode focus en session : la barre du bas reste visible | Décision du porteur | Non |
| 2026-10-06 | Le filtre du catalogue s'affiche aussi sur téléphone | 19 cours font 4 560 px à 390 sans moyen de trier (décision du porteur) | UDR-0077, amendée |
| 2026-10-06 | « Refaire » au lieu de « Commencer » sur un exercice déjà fait | « Commencer » sur un exercice fait 6 fois trompe l'élève (décision du porteur) | UDR-0015, amendée |
| 2026-10-06 | Pas de 4e onglet « Annonces » dans la barre du bas : elles restent sur l'Accueil | Décision du porteur | Non |
| 2026-10-06 | Petits badges en 12 px au lieu de 11 | Illisibles sur téléphone | UDR-0005, amendée |
| 2026-10-06 | Sous 640 px, cartes bord à bord ; marge d'écran et rembourrage de carte à 16 px | 40 px perdus de chaque côté (décision du porteur) | UDR-0005, amendée |
| 2026-10-06 | Accueil sous lg : ni « Bonjour » ni bouton d'aide ; « Besoin d'aide ? » dans le menu du compte ; carte de classe en tête, coins du haut arrondis ; avatar collé à droite | Décision du porteur | UDR-0061, amendée |
| 2026-10-06 | « Mes matières » sous 640 px : abréviations (Math, PC, HG, Philo), sans « Tous les cours », titre remonté | Décision du porteur | UDR-0069, amendée |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Le premier audit, sans données, n'a vu ni le débordement de Ma classe ni la casse des formules : il faut auditer avec des titres longs et des sessions jouées (`db/seeds/demo/saint_michel.rb`).
- Le scratchpad est effacé à chaque reprise de session : le script d'audit vit dans `tmp/audit/audit.rb` (ignoré par git).
- Une sonde qui compare `scrollWidth` à `innerWidth` ne voit pas un débordement en mobile émulé : la fenêtre s'élargit avec la page. Il faut comparer `innerWidth` à la largeur demandée.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Catalogue : Leçon 1 avant Leçon 2 | La table `courses` n'a pas de rang : il faut une migration | À ouvrir |
| Résultat : nommer la lacune et renvoyer vers sa fiche | `SessionResultQuery` ne porte pas la lacune | À ouvrir |
| Cours : avancée et lacune par fiche ; Catalogue : avancée sur la carte | Demandent une lecture d'avancée par fiche et par cours | À ouvrir |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
