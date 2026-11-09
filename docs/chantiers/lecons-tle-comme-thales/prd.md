# PRD — Les leçons de Terminale (Histoire-Géographie) préparées comme Thalès

## 1. Contexte

Les 10 fichiers v3 de Tle, repris de `docs/contenus/a-reprendre/` vers `docs/contenus/lecons-traitees/tle/`, reçoivent, sur le modèle de Thalès et des leçons de 3ème (#494) :
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

1. L'élève de Terminale (toutes séries) ouvre une leçon.
2. « Prépare interros » propose 2 feuilles par notion.
3. « Prépare devoirs » propose « Prépare devoirs n°1 » à « n°4 ».

## 4. Critères d'acceptation

```gherkin
Étant donné un fichier v3 du dossier tle
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
| Contenu | les 10 fichiers v3 de `tle` ; `docs/contenus/README.md` |
| Semis et test | `db/seeds/standard/jeu.yml` (1 couple `tle/histoire-geographie`), `test/db/seeds/standard_manifest_test.rb` (nombre de couples), `test/db/seeds/standard_activity_test.rb` (empreinte) |

## 6. Décisions rattachées

- Pas d'ADR ni d'UDR : le format et l'écran existent (chantier `sujets-thales-feuilles`, ADR-0116).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Leçons de Tle (HG) à sujets | 0 | 10 | — |
