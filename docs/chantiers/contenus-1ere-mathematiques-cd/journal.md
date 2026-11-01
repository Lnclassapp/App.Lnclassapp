# Journal — Les 10 premières leçons de Mathématiques de 1ère C et de 1ère D

> Rempli **pendant** le chantier.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-01 | 13 leçons distinctes, 20 fichiers (C 10 + D 10, 7 communes) | La liste des rangs fait foi | Non |
| 2026-11-01 | Leçon commune : acquis = leçons précédentes dans les deux progressions, interdit = leçons suivantes dans l'une ou l'autre | Rangs différents entre C et D (Barycentre C4/D8, Dérivation C9/D6…) | Non |
| 2026-11-01 | « Généralités » et « Dénombrement » écrites sans s'appuyer sur Angles / Limites | Déclinables en 1ère A (vague P2, rangs 3 et 2) | Non |

## Ce qui a dérapé

- Les relectures indépendantes ont trouvé à chaque leçon : leurres non expliqués, étapes de correction plaquées d'une autre notion, propositions désignées par leur rang, indices dans les questions notées, LaTeX hors `$…$`, caractères « § » cassés. Chaque défaut a été corrigé puis les contrôles relancés ; les calculs étaient justes partout.

## Ce qu'on a appris sur la codebase

- `fill_blank` accepte 5 réponses au plus ; `hint` et `blank` ne sont permis que dans `practice`.
- Un script de contrôle de `practice` (`controle-entrainement.rb`) évite de découvrir les refus à l'import.

## À faire valider par un enseignant

| Leçon | Point à valider |
|---|---|
| Équations et inéquations dans ℝ (C1) | Valeur absolue, systèmes et équations irrationnelles non traités (périmètre du rang 1) ; équations bicarrées ou à fractions absentes en D1. |
| Angles orientés et trigonométrie (C2, D2) | Formules d'addition et de duplication, longueur d'arc et équations trigonométriques : traitées ou non selon le programme DPFC. |
| Généralités sur les fonctions (C3, D3) | Périodicité, composée, fonctions majorée/minorée : périmètre retenu. |
| Barycentre (C4, D8) | Découpage en cinq notions ; coefficients négatifs et somme nulle en D. |
| Limites et continuité (C5, D4) | Partage avec « Extension de la notion de limite » ; théorème des valeurs intermédiaires et prolongement par continuité absents. |
| Dénombrement (C6, D5) | Binôme de Newton, triangle de Pascal et 2ⁿ absents ; convention 0! = 1. |
| Extension de la notion de limite (C7, D7) | Asymptote oblique placée ici ; fonctions irrationnelles et quantité conjuguée absentes. |
| Composées de transformations du plan (C8) | Rotations et homothéties de même centre ; rapport des aires en k². |
| Dérivation (C9, D6) | Dérivée d'une composée absente ; √x en 0 ; dérivée seconde. |
| Orthogonalité de l'espace (C10) | Théorème des trois perpendiculaires et réciproque, distances point-droite et point-plan ; demande de figure « solide en perspective ». |
| Étude et représentation graphique d'une fonction (D9) | Asymptote oblique par la définition ; types de fonctions étudiées ; modèles agronomiques fictifs (anacarde, manioc, hévéa). |
| Probabilité (D10) | Probabilité conditionnelle, variable aléatoire et loi binomiale non traitées ; tirages et loi de probabilité ; notations card(A) et C_n^p. |

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Sorte de figure « courbe de fonction », « tableau de variations », « arbre de probabilités », « solide en perspective » | Pas de code dans la vague | Figures mathématiques du lycée (déjà notée en Tle) |
