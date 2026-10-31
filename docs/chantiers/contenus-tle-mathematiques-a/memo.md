# Memo — Les leçons de Mathématiques de Tle A1 et de Tle A2

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-31 |
| **Branche** | `feature/contenus-tle-mathematiques-a` |
| **Programme** | contenus-v3-tous-niveaux (vague T2) |

---

## Le problème

Un élève de Terminale A1 ou A2 n'a aucune leçon de Mathématiques à réviser au format v3 : les leçons de chaque progression sont des fiches vides, et les 6 leçons rédigées (3 en A1, 3 en A2) sont au format v1, que l'import refuse.

## Pour qui

- **Student** de Tle A1 et de Tle A2 (séries littéraires), qui révise avant une interrogation, un devoir ou le baccalauréat, et s'entraîne dans la fiche.
- **Teacher**, qui donne les exercices de la leçon à sa classe.
- **Team**, qui importe en brouillon, fait relire par un enseignant, publie.

## Pourquoi maintenant

Deuxième vague du programme, en parallèle de T1 (Maths C, D) : la Tle ouvre l'ordre demandé.

## Hors périmètre

- Les séries C et D (vague T1).
- Toute sorte ou tout paramètre de figure nouveau (courbe de fonction, tableau de variations) : les situations sont décrites dans l'énoncé, la dette est déjà notée par T1.
- Le code, les tests (les fixtures v1 de `test/fixtures` restent intactes) et l'import.
- L'import en production, la relecture enseignante, la publication : faits par l'équipe ; les leçons restent en brouillon.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Combien de leçons ? La progression donne 8 rangs en A1 et 7 en A2. | 9 leçons distinctes, 15 fichiers : 6 communes (fonctions, ln, exp, statistique, suites, systèmes), « Probabilité et variable aléatoire » (A1 seule), « Primitives et calcul intégral » (A1 seule), « Probabilité » (A2 seule). | La feuille de route disait 8 : l'écart est noté au journal. |
| Une leçon commune à A1 et A2 : un fichier ou deux ? | Deux (un cours = une série), écrits une fois. | Le rédacteur écrit la version A1, puis la décline en A2 (série, rang de la progression A2, problèmes 3 et 4 allégés si le programme d'A2 l'est). |
| Les acquis diffèrent : A2 n'a pas de leçon Primitives, et son ln vient au rang 3 (rang 4 en A1). | La version A2 ne cite ni primitive ni intégrale, ni variable aléatoire. | Contrôlé à la relecture. |
| Niveau d'une série littéraire ? | Calculs simples, contextes concrets (prix, recettes, populations, épargne), pas de démonstration théorique. | Le brief des rédacteurs le dit. |
| Que deviennent les 6 fichiers v1 du même intitulé ? | Remplacés (décision D4 du programme). | Réécrits en v3 au même nom ; l'historique git garde les v1. Aucun test ne les lit. |
| « Je m'entraîne » : `valider.rb` ne contrôle pas `practice`. | Contrôle à part, mêmes règles que le test des mathématiques de 3e (schéma, `NotionPractice`, cases, indice, pas de reprise de l'exercice noté). | Chaque fichier passe ce contrôle. |
| Nuage de points, arbre de probabilités ? | `coordinate_plane` (points, droite d'ajustement) et `diagram` en `tree` suffisent. | Aucun code, aucun amendement d'ADR. |

## Questions encore ouvertes

- Aucune.
