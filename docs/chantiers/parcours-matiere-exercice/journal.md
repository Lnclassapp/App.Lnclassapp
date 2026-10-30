# Journal — Parcours matière → exercice

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-30 | Lot A : le test de requêtes de `GET /courses` passe de 18 à 20 | la carte ajoute deux lectures au plus (UDR §4) à la vue d'une matière | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Le bench visait d'abord la carte du téléphone seulement (`#material_next_exercise`) : sur ordinateur il prenait une notion et mesurait 3 clics. Corrigé (`#lesson_material_next_exercise`) ; un mode `MODE=lecon` mesure en plus l'écran de la leçon, que le raccourci de la matière saute.
- Plus de 2 connexions rapprochées depuis la même adresse butent sur le limiteur (`login_attempts`) : un élève neuf par passage, et 2 passages par série.
- Les tests contrôleur et système du lot ont été écrits après la vue : seul le test de la query a été vu rouge.
- Revue : une session `completed` sans `completed_at` faisait planter `max_by` (500) ; gardée dans `done`, écartée du calcul du dernier terminé.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Le contrôleur de la matière ne sert la carte que dans les blocs `if student` de `index` : `next_exercise_for` n'a donc pas de garde de rôle (sinon branche morte non couverte).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Exercices assignés dans la carte de la matière | déjà portés par la carte de l'accueil (UDR-0132), les répéter dirait deux fois la même chose | — |
| « Progression DPFC » et « Leçon N » sur la vue matière téléphone (65 mots à l'écran) | la cible est à 10 mots ; couper des titres de leçons retire des choix | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-30 |
| **PR** | |
| **ADR produits** | — |
| **UDR produits** | UDR-0144 |
