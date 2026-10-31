# Journal — Sujets de devoir Thalès, titres numérotés des feuilles, correction en bloc

## Décisions prises en cours de route

- 2026-10-31 : recette de `prepare-interros-cahier` impossible sur Staging (DRENA vides, ADR-0108) ; le contenu des sujets arrive par import, pas par seed.

- 2026-10-31 (Lot B, Touré) : titre de chaque feuille numéroté (« Prépare interros n°N », « Prépare devoirs n°N ») avec le nom de la notion / du sujet en sous-titre `.ps-subject` (« Ma classe » comprise, N = rang parmi les envois de même type) ; correction de la page de résultat en un bloc `#session_correction` « a. … b. … » sous l'exercice ; « Je m'entraîne » (`practice_checks`) inchangé. UDR-0149 §3 amendé (ajout du 2026-10-31).
- 2026-10-31 (Lot D, Touré) : une notion porte **un ou deux exercices**, chacun avec des types de questions mélangés. Forme retenue : la clé `exercise` accepte un objet (tous les fichiers v3 existants, inchangés) ou une liste de 1 à 2 objets ; `essential_exercise_count` refuse 0 et 3 ou plus. Thalès : un 2e exercice par notion (6 questions chacun : QCM, vrai ou faux, complète, calcul, 2 réponses justes, calcul ou QCM). ADR-0116 amendé (et renvoi dans ADR-0113 §4.4).

## Ce qui a dérapé

- Lot C : les maths restaient en LaTeX brut (`$ABC$`, `$$\frac{AD}{AB}=…$$`) dans l'encadré « À retenir » et les propositions des QCM / vrai ou faux, et les figures d'exercice (192 px) étaient illisibles. Livrés par `prepare-interros-cahier` (seuls l'énoncé et les libellés portaient `data-controller="math"`), vus aux captures ; corrigé en posant le déclencheur sur l'encadré, les propositions, l'indice et le bloc « Correction », et en agrandissant la figure.
- Captures interros (lot D) : les exercices de notion citaient la figure interactive, dont la légende affiche ses propres longueurs (AD = 4, AB = 12…) qui contredisent l'énoncé. Corrigé par un schéma fixe `triangle-abc-de`, aussi pour les problèmes 1 et 3 de « Toute la leçon » ; la figure interactive reste sur la fiche de la notion.

## Ce qu'on a appris sur la codebase

- Le contenu ne passe pas par la fusion : il arrive par import, environnement par environnement. Une leçon publiée refuse le réimport.
- La figure `geometry` interactive affiche ses longueurs mesurées : elle illustre une notion, jamais un énoncé chiffré.

## Dette laissée derrière

- Import du fichier Thalès sur `Develop` puis `Staging` (pas en production, décision de Touré) : à faire par l'équipe depuis l'écran Imports.
- Feuille n°4, problème 1 : l'énoncé cite aussi [MN], le schéma ne montre que D et E.
- Cartouche des feuilles : « MATHÉMATIQUES » passe à la ligne à 390 px.

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-31 |
| **PR** | [Lnclassapp/App.Lnclassapp#423](https://github.com/Lnclassapp/App.Lnclassapp/pull/423) vers `Develop` |
| **ADR produits** | ADR-0116 amendé (un ou deux exercices par notion), accord de Kamkara transmis par Touré |
| **UDR produits** | UDR-0149 §3 amendé (feuilles numérotées, correction en bloc) |
