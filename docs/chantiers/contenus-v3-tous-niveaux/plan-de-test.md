# Plan de test des leçons v3 (Tle et 1ère)

> Programme `contenus-v3-tous-niveaux`, 2026-11-02. Vagues en pause jusqu'à la fin de ce test (décision du porteur).
> 30 leçons choisies parmi 347 fichiers : chaque matière de chaque niveau, chaque groupe de séries (A, C/D), et les leçons les plus chargées en figures et en formules. Une leçon commune à plusieurs séries ne se teste qu'une fois.

## Où tester

| Où | Comptes | Quand |
|---|---|---|
| **Develop** | vos comptes : équipe pour tout voir ; un élève d'une classe du bon niveau et de la bonne série pour la vue élève | dès que la PR du référentiel de Develop est fusionnée et déployée (les leçons y sont alors publiées) |
| **Local** : `bin/tester-pr Develop --demo` (`--telephone` pour le téléphone) | PIN 2468 · élèves de démo : Tle D `0131002101`, Tle A1 `0131001901`, 1ère C `0131001701`, 1ère D `0131001801`, 1ère A1 `0131001601` · équipe `0700000000` (code TOTP affiché) | tout de suite |

Chaque leçon se teste **au téléphone (390 px) et sur ordinateur**.

## Ce qu'on vérifie sur chaque leçon

1. **Fiche** de chaque notion : 4 blocs (À retenir, La méthode, Un exemple corrigé, Le piège à éviter), gras rendu (jamais de `**`).
2. **Figures** : présentes, lisibles, légendes justes.
3. **Formules** : bien rendues ; à 390 px, une formule longue défile dans son cadre, la page ne défile jamais à l'horizontale.
4. **Exercice** de chaque notion (≥ 5 questions) : répondre juste puis faux, la correction explique la méthode.
5. **4 problèmes** et leurs corrigés.
6. **Prépare interros / Je m'entraîne** : « À retenir » en gras, questions jouables.
7. **Fond** : exactitude (chiffres, dates, citations, faits médicaux), niveau adapté à la série, conforme à la progression 2026-2027. Les points déjà relevés sont dans [`journal.md`](journal.md), section « À faire valider par un enseignant ».

## Terminale

| # | Série | Matière | Leçon | Pourquoi celle-ci |
|---|---|---|---|---|
| 1 | D | Mathématiques | Calcul intégral | formules longues (défaut 390 px corrigé) |
| 2 | C | Mathématiques | Barycentre et lignes de niveaux | figures + formules |
| 3 | A1 | Mathématiques | Étude de fonctions polynômes et de fonctions rationnelles | série A, courbes |
| 4 | D | Physique-Chimie | Mouvements dans les champs (g⃗ et E⃗) uniformes | physique, vecteurs |
| 5 | C | Physique-Chimie | Composés carbonylés : aldéhydes et cétones | chimie, formules |
| 6 | D | SVT | Le fonctionnement du tissu nerveux | schémas |
| 7 | C | SVT | La communication nerveuse | leçon propre à C |
| 8 | A1 | SVT | L'activité cérébrale chez l'Homme | série A |
| 9 | A1 | Philosophie | Dieu et la religion | citations à vérifier |
| 10 | D | Philosophie | La dissertation philosophique | méthode |
| 11 | A1 | Français | Groupement de textes théâtraux | textes |
| 12 | — | Histoire-Géographie | Histoire — L'accession de la Côte d'Ivoire à l'indépendance | dates |
| 13 | — | Histoire-Géographie | Géographie — Les fondements du développement économique de la Côte d'Ivoire | chiffres, cartes |

## Première

| # | Série | Matière | Leçon | Pourquoi celle-ci |
|---|---|---|---|---|
| 14 | C | Mathématiques | Barycentre | formules + figures |
| 15 | A1 | Mathématiques | Dénombrement | série A |
| 16 | C | Physique-Chimie | Généralités sur les composés organiques | refusée à l'import puis corrigée |
| 17 | C | Physique-Chimie | Énergie cinétique | formule longue (516 px relevés) |
| 18 | A1 | Physique-Chimie | Énergie cinétique | même leçon allégée pour la série A |
| 19 | A1 | Physique-Chimie | Les alcanes | chimie, série A |
| 20 | D | SVT | La division méiotique | schémas, gras de « À retenir » |
| 21 | D | SVT | Le réflexe inné | schémas |
| 22 | A1 | SVT | Les effets des drogues sur le comportement | faits médicaux |
| 23 | A1 | SVT | La régulation des naissances | faits médicaux |
| 24 | A1 | Philosophie | L'essai de problématisation | méthode |
| 25 | C | Philosophie | La période antique | auteurs, dates |
| 26 | A1 | Français | L'argumentation | gras de « À retenir » |
| 27 | A2 | Français | Les tonalités littéraires | série A2 |
| 28 | C | Français | Les valeurs des temps verbaux | leçon de C/D |
| 29–30 | — | Histoire-Géographie | 2 leçons de la vague P9 | quand elle sera fusionnée |

## Retour

Pour chaque défaut : n° de la leçon, écran (fiche, exercice, problème, Prépare interros), téléphone ou ordinateur, et une capture si possible. Les défauts d'affichage passent en correction ; les défauts de fond reviennent à la vague concernée.
