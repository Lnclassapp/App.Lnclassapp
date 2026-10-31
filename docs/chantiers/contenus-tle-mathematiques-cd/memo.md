# Memo — Les 10 premières leçons de Mathématiques de Tle C et de Tle D

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré (PR vers `Develop`, leçons en brouillon) |
| **Ouvert le** | 2026-10-31 |
| **Branche** | `feature/contenus-tle-mathematiques-cd` |
| **Programme** | contenus-v3-tous-niveaux (vague T1) |

---

## Le problème

Un élève de Terminale C ou D n'a aucune leçon de Mathématiques à réviser au format v3 : les 10 premières leçons de chaque progression sont des fiches vides, et les 6 leçons rédigées (3 en C, 3 en D) sont au format v1, que l'import refuse.

## Pour qui

- **Student** de Tle C et de Tle D, qui révise avant une interrogation, un devoir ou le baccalauréat, et s'entraîne dans la fiche.
- **Teacher**, qui donne les exercices de la leçon à sa classe.
- **Team**, qui importe en brouillon, fait relire par un enseignant, publie.

## Pourquoi maintenant

Première vague du programme : la Tle ouvre l'ordre demandé (Tle → 1ère → 2nde → 4ème → 5ème → 6ème), et les Mathématiques de C et D sont la plus grosse vague du niveau.

## Hors périmètre

- Les leçons au-delà du rang 10 de chaque progression ; les séries A1 et A2 (vague T2).
- Toute sorte ou tout paramètre de figure nouveau (courbe de fonction, tableau de variations, arbre de probabilités, conique autre que le cercle) : aucune figure ne l'exige au point de bloquer une leçon ; les situations sont décrites dans l'énoncé et la demande est notée en dette.
- Le code, les tests et l'import : aucun changement.
- L'import en production, la relecture enseignante, la publication : faits par l'équipe ; les leçons restent en brouillon.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| La vague annonce 15 leçons distinctes ; la liste en donne 14 (10 en C, 10 en D, 6 communes). | On compte la liste : 14 leçons distinctes, 20 fichiers (un cours par série). | Le bilan dit 14 ; l'écart est noté au journal du programme. |
| Une leçon commune à C et D : un fichier ou deux ? | Deux (un cours = une série), écrits une fois. | Le rédacteur écrit la version C, puis la décline en D (série, rang, intitulé de la progression D) et adapte au niveau D les problèmes 3 et 4 et les questions de démonstration. |
| C9 « Fonctions exponentielles et fonctions puissances » et D6 « Fonctions exponentielles et puissances » ? | Même leçon, chaque fichier garde l'intitulé de sa progression. | Deux noms de fichier différents. |
| Que deviennent les 6 fichiers v1 du même intitulé (barycentre, divisibilité, limites en C ; limites, dérivabilité, probabilité en D) ? | Remplacés (décision D4 du programme). | Réécrits en v3 au même nom ; l'historique git garde les v1. |
| « Je m'entraîne » : `valider.rb` ne contrôle pas la clé `practice`. | Contrôle à part, mêmes règles que le test des mathématiques de 3e (schéma, `NotionPractice`, 1 à 6 questions, une question à plusieurs cases et un indice par leçon, aucune question reprise de l'exercice noté). | Chaque fichier passe ce contrôle en plus de `valider.rb`. |
| Les fonctions (ln, exp, coniques) appellent des courbes ; `coordinate_plane` ne trace que des droites. | Pas de sorte nouvelle : points, segments, vecteurs et droites suffisent aux tangentes, asymptotes, affixes et barycentres ; les courbes sont décrites. | Aucun code, aucun amendement d'ADR ; dette « courbe de fonction » notée. |
| Nombres complexes en D (rang 8) avant « Nombres complexes et géométrie du plan » (rang 10) ? | La leçon 8 s'arrête aux formes algébrique, trigonométrique et exponentielle et aux équations ; les transformations et configurations du plan sont interdites (rang 10). | Même découpage en C. |

## Questions encore ouvertes

- Aucune.
