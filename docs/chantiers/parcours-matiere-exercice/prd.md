# PRD — Parcours matière → exercice

## 1. Contexte

De la grille des matières à la feuille d'un exercice, l'élève fait 4 clics et lit 461 mots sur la leçon avant le premier lien d'exercice ([memo](memo.md)). Une carte « Prochain exercice » en tête de la matière et de la leçon ouvre directement la feuille : 2 clics depuis la grille.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | voir la carte dans la vue d'une de ses matières et sur une leçon de son niveau ; démarrer ou reprendre l'exercice proposé | voir un exercice d'un autre niveau, d'une leçon ou d'une notion non publiée, ou archivé |
| Teacher, Team | — (aucun changement) | voir la carte |

Règles : `ReadsOwnLevel` / `ReadOwnLevelPolicy` pour la page ; le POST de démarrage passe par `Assessment::ExerciseSessionsController#create`, inchangé (refus hors niveau).

## 3. Parcours utilisateur

### Chemin nominal

1. Accueil : l'élève touche « Mathématiques » dans la grille.
2. Vue de la matière : la carte « Prochain exercice » montre le premier exercice à faire ; il touche « Commencer l'exercice ».
3. La feuille de l'exercice s'ouvre (session démarrée).

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Une session est en cours dans la matière | « Reprendre à la question N », lien vers la session |
| Des exercices sont terminés | la carte propose celui qui suit le dernier terminé, dans l'ordre du programme ; à défaut le premier non terminé |
| Tout est terminé, ou aucun exercice | pas de carte |
| L'élève ouvre une leçon | la même carte, limitée à la leçon, avec « Tous les exercices » vers `#prepare-interros` |
| Enseignant, équipe | pas de carte |
| Recherche dans la matière | la carte reste, hors du frame |

## 4. Critères d'acceptation

```gherkin
CA-1 Étant donné un élève de 3ème sans activité
Quand il ouvre Mathématiques depuis sa grille
Alors la carte « Prochain exercice » propose le premier exercice de la leçon 1
Et « Commencer l'exercice » ouvre la feuille de cet exercice (2 clics depuis la grille)

CA-2 Étant donné une session en cours sur un exercice de la matière
Quand l'élève ouvre la matière
Alors la carte dit « Reprendre à la question N » et mène à cette session

CA-3 Étant donné le premier exercice terminé
Alors la carte propose l'exercice suivant dans l'ordre du programme

CA-4 Étant donné tous les exercices de la matière terminés
Alors aucune carte n'est rendue

CA-5 Étant donné une leçon ouverte par l'élève
Alors la carte de la leçon est sous l'en-tête, avant la fiche de révision, et ne propose qu'un exercice de cette leçon

CA-6 Un exercice brouillon, archivé, d'une notion non publiée, d'une leçon non publiée ou d'un autre niveau n'est jamais proposé

CA-7 Un enseignant qui ouvre la matière ou la leçon ne voit pas de carte

CA-8 Mesure : grille → feuille ≤ 2 clics ; ≤ 50 mots et 0 px de défilement avant la cible sur chaque écran intermédiaire, à 390 px et 1 280 px
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | — (lecture seule) |
| Infrastructure | `Queries::Catalog::NextExerciseQuery` |
| Delivery | `Catalog::CoursesController` : `next_exercise_for(material_slug)` (vue matière), `@next_exercise` (leçon), élève seulement |
| UI | `catalog/courses/_next_exercise`, appelé par `index` (2 blocs) et `show` ; locales `catalog.courses.next_exercise.*` |

## 6. Décisions rattachées

- UDR-XXXX-parcours-matiere-exercice-raccourcis

## 7. Mesures

Même machine, même volume (memo), même méthode (`mesure_parcours.js`), élèves de 3ème sans activité.

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Clics grille → feuille (390 · 1 280 px) | 4 · 4 | ≤ 2 | à mesurer |
| Mots avant la cible, matière (390 · 1 280) | 8 · 18 | ≤ 50 | à mesurer |
| Mots avant la cible, leçon (390 · 1 280) | 461 · 461 | ≤ 50 | à mesurer |
| Défilement avant la cible, leçon (390 · 1 280) | 1 623 · 1 007 px | 0 | à mesurer |
