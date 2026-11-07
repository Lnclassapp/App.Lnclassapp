# PRD — Calcul littéral préparé comme Thalès

## 1. Contexte

Le fichier `docs/contenus/lecons-traitees/3eme/mathematiques/calcul-litteral.json` reçoit, sur le modèle de Thalès :
- un deuxième exercice par notion ;
- quatre sujets de devoir de quatre exercices ;
- des figures quand un problème parle d'une aire ou d'un périmètre.

Aucun code ne change.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | faire 2 feuilles « Prépare interros » par notion et 4 feuilles « Prépare devoirs » | — (aucune permission ne change) |
| Teacher | envoyer un des 4 sujets à sa classe | — |

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre « Calcul littéral ».
2. « Prépare interros » propose 8 feuilles, 2 par notion.
3. « Prépare devoirs » propose 4 sujets, « Prépare devoirs n°1 » à « n°4 ».
4. Il fait un sujet et vérifie : la correction de chaque exercice s'affiche en un bloc.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Réponse « complète » écrite autrement (espace, virgule décimale) | Acceptée comme pour les autres leçons |
| Mauvaise réponse à un QCM | Correction qui explique l'erreur typique |

## 4. Critères d'acceptation

```gherkin
Étant donné le fichier calcul-litteral.json importé par la chaîne d'import
Alors chacune des 4 notions porte 2 exercices
Et la leçon porte 4 sujets de 4 exercices chacun
Et chaque figure citée par un exercice existe dans la leçon

Étant donné un élève de 3ème sur la page de Calcul littéral
Quand il ouvre « Prépare devoirs »
Alors il voit 4 sujets, « Prépare devoirs n°1 » à « n°4 »

Étant donné chaque question du fichier
Alors sa bonne réponse est juste et ses mauvaises réponses sont fausses (vérification par calcul)
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine, infrastructure, delivery, UI | — |
| Contenu | `docs/contenus/lecons-traitees/3eme/mathematiques/calcul-litteral.json` |

## 6. Décisions rattachées

- Pas d'ADR : le format (2 exercices par notion, sujets) existe déjà (chantier `sujets-thales-feuilles`).
- Pas d'UDR : aucune vue ne change.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Exercices par notion | 1 | 2 | 2 |
| Sujets de devoir | 0 | 4 × 4 exercices | 4 × 4 exercices (95 questions) |
