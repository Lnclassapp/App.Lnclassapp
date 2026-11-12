# PRD — Les trois premières leçons de 1ère et de 2nde, comme Thalès

## 1. Contexte

Les 3 premières leçons de la progression DPFC 2026-2027 de chaque série et matière de 1ère et de 2nde reviennent dans `docs/contenus/lecons-traitees/` au format complet (règle de retour de `docs/contenus/a-reprendre/README.md`) :
- 1ère (Français, Mathématiques, Physique-Chimie, SVT, Philosophie, Histoire-Géographie) : un 2e exercice par notion et 4 sujets de devoir, le reste inchangé ;
- 2nde (Français, Mathématiques, Physique-Chimie, SVT, Histoire-Géographie) : réécriture complète en v3.

Aucun code ne change.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | faire 2 feuilles « Prépare interros » par notion et 4 feuilles « Prépare devoirs » | — (aucune permission ne change) |
| Teacher | envoyer un des 4 sujets à sa classe | — |

## 3. Parcours utilisateur

1. L'élève de 1ère ou de 2nde ouvre une des 3 premières leçons de sa matière.
2. « Prépare interros » propose 2 feuilles par notion ; « Prépare devoirs » propose « n°1 » à « n°4 ».

## 4. Critères d'acceptation

```gherkin
Étant donné un fichier rangé par ce chantier dans lecons-traitees
Alors chacune de ses notions porte 2 exercices, le second de 6 questions d'au moins 4 types
Et la leçon porte 4 problèmes et 4 sujets de 4 exercices de 5 ou 6 questions
Et valider.rb ne rend aucune erreur, ni sur la leçon ni sur chaque sujet mis à la place des problèmes

Étant donné un fichier de 1ère
Alors tout ce qui précédait (cours, fiches, 1er exercice, problèmes, practice) est identique au fichier d'origine

Étant donné la page de la leçon, à 390 px et sur ordinateur
Alors aucune page ne défile en largeur ni ne montre de LaTeX brut (tâche lecons de la CI)

Étant donné le jeu standard
Alors chaque couple niveau-série et matière nouveau a sa leçon 1 dans db/seeds/standard/jeu.yml
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine, infrastructure, delivery, UI | — |
| Contenu | 63 fichiers de 1ère, 27 de 2nde ; `docs/contenus/README.md`, `a-reprendre/README.md` |
| Semis et test | `db/seeds/standard/jeu.yml`, tests du manifeste si besoin |

## 6. Décisions rattachées

- Pas d'ADR ni d'UDR : le format et l'écran existent (ADR-0116).
