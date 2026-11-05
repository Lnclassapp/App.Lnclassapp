# PRD — Les leçons de 3ème préparées comme Thalès

## 1. Contexte

Les 58 fichiers v3 de `docs/contenus/lecons-traitees/3eme/` qui n'ont pas encore de sujets reçoivent, sur le modèle de Thalès et de Calcul littéral :
- un deuxième exercice par notion (`fixation`, 6 questions de types mêlés) ;
- quatre sujets de devoir de quatre exercices (`evaluation`, 5 ou 6 questions) ;
- des figures quand elles aident, avec les sortes existantes.

Aucun code ne change.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | faire 2 feuilles « Prépare interros » par notion et 4 feuilles « Prépare devoirs » | — (aucune permission ne change) |
| Teacher | envoyer un des 4 sujets à sa classe | — |

## 3. Parcours utilisateur

1. L'élève ouvre une leçon de 3ème.
2. « Prépare interros » propose 2 feuilles par notion.
3. « Prépare devoirs » propose « Prépare devoirs n°1 » à « n°4 ».

## 4. Critères d'acceptation

```gherkin
Étant donné un fichier v3 du dossier 3eme
Alors chacune de ses notions porte 2 exercices, le premier inchangé
Et la leçon porte 4 sujets de 4 exercices de 5 ou 6 questions
Et chaque figure citée existe dans la leçon et respecte figure_kinds.rb

Étant donné la page de la leçon, à 390 px et sur ordinateur
Alors « Prépare interros » montre 2 exercices par notion
Et « Prépare devoirs » montre « Prépare devoirs n°1 » à « n°4 »
Et aucune page ne défile en largeur ni ne montre de LaTeX brut

Étant donné le script de vérification
Alors il passe sur chaque fichier avec 0 erreur
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine, infrastructure, delivery, UI | — |
| Contenu | les 58 fichiers v3 de 3ème sans sujets ; `prompt-redaction.md`, `prompt-redaction-lot.md`, `docs/contenus/README.md` |
| Semis et test | `db/seeds/standard/jeu.yml` (clé `longue`), `test/db/seeds/standard_activity_test.rb` (empreinte), si besoin |

## 6. Décisions rattachées

- Pas d'ADR ni d'UDR : le format et l'écran existent (chantier `sujets-thales-feuilles`, ADR-0116).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Leçons de 3ème à sujets | 2 | 60 | — |
