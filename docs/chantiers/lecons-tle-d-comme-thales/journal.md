# Journal — Les leçons de Terminale D préparées comme Thalès

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-07 | Les 31 leçons dont la fiche est la même qu'en Tle C reprennent tels quels les ajouts de Tle C, recontrôlés par le script sur le fichier de Tle D | Décision 6 de #484 : une fiche commune n'est traitée qu'une fois | Non |
| 2026-11-07 | Même méthode qu'en Tle C pour les 14 leçons propres : un rédacteur par leçon hors dépôt, script de contrôle, relecture indépendante de chaque question | Les relectures de Tle C avaient trouvé 18 défauts de fond en mathématiques que le script ne voyait pas | Non |
| 2026-11-07 | Le jeu standard charge une leçon de Tle D par matière (manifeste : 16 couples) | `StandardTestSet` exige une ligne par couple qui a du v3 | Non |

## Leçons reprises de Tle C (31, non réécrites)

Ajouts repris du chantier [`lecons-tle-c-comme-thales`](../lecons-tle-c-comme-thales/journal.md#fichiers-communs-avec-dautres-dossiers-non-modifiés-ici), même script, 0 erreur sur chaque fichier de Tle D :

- **Français** (6) : les 6 leçons.
- **Philosophie** (9) : les 9 leçons.
- **Mathématiques** (5) : dérivabilité et étude de fonctions, fonctions logarithmes, limites et continuité, nombres complexes, primitives.
- **Physique-chimie** (8) : acides carboxyliques, cinématique du point, composés carbonylés, fabrication d'un savon, les alcools, mouvement du centre d'inertie, mouvements dans les champs g et E, oscillations mécaniques libres.
- **SVT** (3) : l'infection par le VIH, la transmission d'un caractère héréditaire chez l'homme, le système de défense.

Le correctif d'affichage à 390 px de « composés carbonylés » (formules condensées) vient de Tle C et vaut ici aussi.

## Ce qui a dérapé

- **Relecture partielle** : un relecteur (acides aminés) n'avait relu que les deux questions signalées. Relancé sur les 104 questions, il a trouvé un défaut de plus (une correction qui désignait des propositions par leur rang).
- **Distracteurs qui nomment la bonne molécule** : en amines, deux mauvaises propositions sont des noms non conformes de la même molécule que la bonne réponse. Laissé : la correction explique la règle de la chaîne la plus longue (voir « À trancher »).
- **Contre-exemple hors hypothèses** (calcul intégral) : la correction prenait f = g = 1 alors que l'énoncé fixe ∫f = 8 et ∫g = −4. Le script ne contrôle que les valeurs des réponses, pas les explications ; seule la relecture l'a vu.

- **Débordement à 390 px** (calcul intégral, feuille du sujet 1) : la formule d'intégration par parties écrite en entier dans une étape d'ordering élargissait la page à 453 px. Formules raccourcies (énoncé en $u$, $v$ ; étape réduite au membre de droite) et preuve adaptée.
- **Leçon la plus longue** : la leçon de SVT « maintien de la constance du milieu intérieur » de Tle D (282 150 octets) dépasse « le scrutin électoral » de 3ème ; la clé `longue` de `jeu.yml` la désigne maintenant.

## Ce qu'on a appris sur la codebase

- Rien de neuf : `valider.rb` ne contrôle toujours pas les `subjects` (dette notée en 3ème et en Tle C).

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `valider.rb` ne contrôle pas les sujets | Le chantier ne touche que du contenu | À ouvrir |

## À trancher

- **Lectures graphiques sans tolérance**, **valeurs illustratives**, **textes d'appui de l'oral** : comme en Tle C, option prudente appliquée (laissé tel quel ; un enseignant relit avant publication).
- **Noms non conformes comme distracteurs** (amines, S1.E2.Q3) : option prudente appliquée, laissés car la correction les explique. Option possible : les remplacer par des molécules différentes.

## Avancement

### 14 leçons propres à la Tle D

Preuve : sympy sur chaque question en mathématiques et sur chaque calcul en physique-chimie ; ailleurs, un extrait mot pour mot de la leçon. Chaque réponse faussée exprès est détectée. Aucune figure ajoutée. Relecture indépendante de chaque leçon.

| Leçon | Questions | Vérifications | Réponses faussées détectées | Défauts de fond corrigés (rédaction + relecture) |
|---|---:|---:|---:|---:|
| Maths — Calcul intégral | 110 | 4 191 | 110/110 | 0 + 2 |
| Maths — Fonctions exponentielles et puissances | 112 | 4 687 | 112/112 | 0 + 3 |
| Maths — Nombres complexes et géométrie du plan | 105 | 4 256 | 105/105 | 0 + 2 |
| Maths — Probabilité conditionnelle et variable aléatoire | 110 | 3 808 | 110/110 | 0 + 2 |
| Maths — Suites numériques | 122 | 4 575 | 122/122 | 0 + 3 |
| PC — Les acides aminés | 104 | 4 175 | 82/82 | 0 + 3 |
| PC — Les amines | 126 | 5 117 | 95/95 | 1 + 0 |
| SVT — Le devenir des cellules sexuelles | 104 | 4 283 | 24/24 | 0 + 4 |
| SVT — Le fonctionnement des organes sexuels chez l'homme | 99 | 4 219 | 27/27 | 0 + 3 |
| SVT — Le fonctionnement du tissu nerveux | 112 | 4 565 | 44/44 | 0 + 7 |
| SVT — Le maintien de la constance du milieu intérieur | 119 | 5 091 | 16/16 | 1 + 0 |
| SVT — Le réflexe conditionnel | 115 | 4 886 | 11/11 | 0 + 2 |
| SVT — La reproduction chez les spermaphytes | 105 | 4 414 | 30/30 | 2 + 0 |
| SVT — La transmission de deux caractères héréditaires | 105 | 4 215 | 83/83 | 0 + 0 |
| **Total** | **1 548** | **62 482** | **971/971** | **4 + 31** |

Exemples de défauts de fond trouvés à la relecture : une moyenne « environ 1,03 » au lieu de 1 et un énoncé qui donnait la probabilité demandée (probabilités) ; des limites d'exponentielles non réécrites en exp(u ln a), et ln 3 ≈ 1,10 qui menait à 825 au lieu de 824 (exponentielles) ; « à partir de quel mois » qui admettait plusieurs réponses (suites) ; quatre explications de PPSE/PPSI au calcul faux (tissu nerveux) ; une chaîne latérale R = COOH hypothétique (acides aminés). Les relecteurs ont aussi réécrit une trentaine de corrections qui désignaient une proposition par son rang ou dont la forme était fautive.
