# Journal — Sujets de devoir Thalès, titres numérotés des feuilles, correction en bloc

## Décisions prises en cours de route

- 2026-10-31 : recette de `prepare-interros-cahier` impossible sur Staging (DRENA vides, ADR-0108) ; le contenu des sujets arrive par import, pas par seed.

- 2026-10-31 (Lot B, Touré) : titre de chaque feuille numéroté (« Prépare interros n°N », « Prépare devoirs n°N ») avec le nom de la notion / du sujet en sous-titre `.ps-subject` (« Ma classe » comprise, N = rang parmi les envois de même type) ; correction de la page de résultat en un bloc `#session_correction` « a. … b. … » sous l'exercice ; « Je m'entraîne » (`practice_checks`) inchangé. UDR-0149 §3 amendé (ajout du 2026-10-31).
- 2026-10-31 (Lot D, Touré) : une notion porte **un ou deux exercices**, chacun avec des types de questions mélangés. Forme retenue : la clé `exercise` accepte un objet (tous les fichiers v3 existants, inchangés) ou une liste de 1 à 2 objets ; `essential_exercise_count` refuse 0 et 3 ou plus. Thalès : un 2e exercice par notion (6 questions chacun : QCM, vrai ou faux, complète, calcul, 2 réponses justes, calcul ou QCM). ADR-0116 amendé (et renvoi dans ADR-0113 §4.4).

## Ce qui a dérapé

- Lot C : les maths restaient en LaTeX brut (`$ABC$`, `$$\frac{AD}{AB}=…$$`) dans l'encadré « À retenir » et les propositions des QCM / vrai ou faux, et les figures d'exercice (192 px) étaient illisibles. Livrés par `prepare-interros-cahier` (seuls l'énoncé et les libellés portaient `data-controller="math"`), vus aux captures ; corrigé en posant le déclencheur sur l'encadré, les propositions, l'indice et le bloc « Correction », et en agrandissant la figure.

## Ce qu'on a appris sur la codebase

## Dette laissée derrière

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
