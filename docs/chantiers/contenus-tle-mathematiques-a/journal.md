# Journal — Les leçons de Mathématiques de Tle A1 et de Tle A2

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-31 | 9 leçons distinctes, 15 fichiers (la feuille de route en comptait 8) | « Probabilité et variable aléatoire » (A1) et « Probabilité » (A2) sont deux intitulés, donc deux leçons | Non |
| 2026-10-31 | Leçons communes écrites une fois en A1, déclinées en A2 sans appui sur Primitives ni variable aléatoire | La progression A2 ne les a pas | Non |
| 2026-10-31 | Contrôle de « Je m'entraîne » par un script d'orchestrateur, comme T1 | `valider.rb` ne lit pas `practice` | Non |
| 2026-10-31 | L'A2 garde la notion « Équation de la tangente » des Fonctions et ses questions dans les problèmes 3 et 4 : A2 = A1 sauf série et rang | Acquis de 1ère A ; un retrait partiel rendait l'A2 incohérent | Non |
| 2026-10-31 | Tableaux à double entrée en `statement_blocks` de type `table` (Probabilité A2), pas en HTML dans la fiche | `valider.rb` avertit sur le HTML, le rendu l'échappe | Non |
| 2026-10-31 | Réponses tirées d'une valeur approchée (ln 2 ≈ 0,7…) : tolérance qui accepte aussi la valeur exacte | Une tolérance 0 refusait le résultat de la calculatrice | Non |

## Ce qui a dérapé

- Les relectures (Opus, 5 relecteurs distincts des auteurs) ont trouvé 6 défauts bloquants, tous corrigés : intégrales en « dx » pour un intégrande en t (Primitives) ; tolérances 0 sur des réponses issues de ln 2 ≈ 0,7 ou e^0,7 ≈ 2, qui refusaient la valeur exacte (14 questions, ln et exp, A1 et A2) ; deux explications de leurres fausses (2/3 « inverse » de 4/6, 1/30) ; une question qui employait A et B définis ailleurs (Probabilité A2).
- Fautes mineures répétées malgré le brief : étapes de correction renommées ou numérotées d'après une autre méthode, leurres non expliqués, renvois à « la question précédente », critères plus nombreux que les points du barème.
- Le scratchpad partagé : un rédacteur a écrasé le générateur d'un autre (`gen/build.py`) ; le JSON a été corrigé à la main. Donner à chaque rédacteur son propre dossier.

## À faire valider par un enseignant

| Leçon | Point à valider |
|---|---|
| Fonctions (A1, A2) | f′ = (ad − bc)/(cx + d)² donnée sans démonstration ; signe et factorisation du trinôme supposés acquis ; limites à gauche et à droite ; extremums d'un polynôme de degré 3 en A2. |
| Probabilité et variable aléatoire (A1) | variance et écart-type absents ; espérance du gain algébrique et « jeu équitable si E(X) = 0 » ; niveau et barème du problème 4. |
| Primitives et calcul intégral (A1) | primitive de 1/x² et valeur moyenne non traitées ; aire avec deux unités différentes au problème bac ; signe du trinôme par Δ ; barèmes. |
| Fonction logarithme népérien (A1, A2) | définition (A1 : primitive de 1/x ; A2 : admise par sa dérivée) ; limites en 0⁺ et +∞ ; e² cité avant la leçon exp ; (ln u)′ en A2 ; valeurs ln 2 ≈ 0,7, ln 3 ≈ 1,1, ln 10 ≈ 2,3 ou 0,69 ; problème bac x − ln x. |
| Fonction exponentielle népérienne (A1, A2) | limites en ±∞ ; (e^u)′ avec u polynôme ; inéquations e^x ≥ k ; modèle N₀e^{kt} ; aucune figure (courbe non traçable). |
| Statistique à deux variables (A1, A2) | moindres carrés, covariance et coefficient de corrélation non traités ; Mayer réservée aux effectifs pairs ; vocabulaire interpolation / prévision. |
| Suites numériques (A1, A2) | somme géométrique au programme A ? suite uₙ₊₁ = a·uₙ + b et limite d'une suite géométrique non traitées. |
| Systèmes d'équations linéaires (A1, A2) | changement d'inconnue X = ln x, Y = ln y au programme A ? niveau de calcul du problème bac. |
| Probabilité (A2) | « 2 parmi n » = n(n − 1)/2 seulement (pas C(n, p)) ; arbre qui mêle hasard et choix ; niveau bac du problème 4. |

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Sortes « courbe de fonction » et « tableau de variations » (exp sans figure, courbes décrites) | Pas de code dans la vague ; déjà notée par T1 | À ouvrir (figures mathématiques du lycée) |

## Ce qu'on a appris sur la codebase

- Aucun test ne lit les leçons v1 de `tle-a1/` ni `tle-a2/` : leur remplacement ne touche pas la CI.
- Le nom de fichier de « Systèmes d'équations linéaires dans ℝ × ℝ » est `systemes-d-equations-lineaires-dans.json` (ℝ n'est pas alphanumérique, comme ℤ en T1).
