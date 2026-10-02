# Journal — Interface épurée

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-02 | Lot 0 : « Voir plus » rend toutes les lignes côté serveur et masque les suivantes (`hidden`), sans requête | Liste courte (≤ 10 sessions) ; une requête par clic coûterait plus cher sur un réseau lent que 7 lignes de HTML | non (UDR-0057) |
| 2026-10-02 | Porte des lots C à F : amendements des UDR 0009, 0011, 0013, 0015, 0021, 0022, 0023, 0041 et UDR-0060 acceptés par le porteur | Validation en un passage, sur résumé écran par écran | non (UDR amendées) |
| 2026-10-02 | Les retraits des lots C et D ne valent que pour l'élève, même les simples répétitions vues par l'enseignant et l'équipe | Grill Q1 : chantier élève seulement, hors écrans d'entrée | non (notes de décision dans 0013, 0015, 0021, 0023) |
| 2026-10-02 | « Meilleur score » % devient « Meilleure note » /20 sur la page exercice | Une seule forme de la note dans le parcours élève (R6) | non (UDR-0021) |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Mesure « avant » (Lot 0) : à 390 × 844, l'accueil élève commence 7 blocs avant le pli, dont le bloc d'aide, et montre 4 boutons principaux.
- La photo de la homepage (`homepage/student.png`) pèse 1,3 Mo et se charge aussi sur téléphone : la remplacer par une image ≤ 150 Ko est le plus gros gain de poids du chantier (Lot B / M2).

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
