# Journal — Develop charge seul les leçons v3 du programme

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-02 | La sélection est faite dans le domaine (`AutomaticLoadStage#mode_for`) ; la source rend toutes les leçons v3 avec leur dossier et la présence de sujets. | Testable sans fichiers ; la règle « Develop seul » vit dans une entité. | Oui (§4.2) |
| 2026-11-02 | `ImportCourseTree` : `replace: :draft \| :exercises \| :lesson` à la place du booléen `replace_exercises`, valeur inconnue refusée. | Trois modes exclusifs ; `:draft` par défaut garde l'écran Imports intact. | Oui (§4.4) |
| 2026-11-02 | Le remplacement entier efface aussi le texte de cours v1 (`action_text_rich_texts`, `content`). | Le v3 n'a pas de texte de cours : l'ancien serait resté affiché. | Oui (§4.4) |
| 2026-11-02 | Les tests d'intégration réduisent le dépôt à deux fichiers (Thalès + une leçon Tle C). | Sinon chaque test Develop importerait 264 fichiers. | Non |

## Revues (security-reviewer, silent-failure-hunter)

| Constat | Suite |
|---|---|
| Activation par le seul nom `Develop` (sécurité 1) | Écarté : une variable à poser a été refusée par le porteur (ADR-0122 option A) ; risque écrit dans l'ADR. |
| Job d'Imports en `:draft` non testé (sécurité 2) | Corrigé : test du `replace_mode` du job. |
| Texte de cours v1 effacé sans ses pièces jointes (sécurité 3) | Corrigé : détruit par Action Text. |
| Fichier de plusieurs leçons (sécurité 4) | Corrigé : écarté avec avertissement. |
| Leçon voisine intacte non prouvée (sécurité 5) | Corrigé : test. |
| Fichiers non chargés invisibles (silencieux 1) | Corrigé : une ligne par démarrage, décompte par dossier. |
| Refus sans cause au journal (silencieux 2) | Corrigé : statut et nombre d'erreurs journalisés. |
| Leçon du programme à sujets en mode exercices (silencieux 3) | Écarté : exigence du porteur ; aucune aujourd'hui ; écrit dans l'ADR §4.2. |
| `LessonFile` à valeurs par défaut (silencieux 4) | Corrigé : mots-clés obligatoires. |
| `replaced` / `created` perdu si publication ratée (silencieux 5) | Corrigé : journalisé avant la publication. |
| Titre sans nom de fichier, décompte rake (silencieux 6, 7) | Écartés : faibles. |
| Exception de lecture d'un fichier arrête tout (silencieux 8) | Corrigé : rattrapée fichier par fichier. |

## Mesures

Base de développement locale, `RAILWAY_ENVIRONMENT_NAME=Develop bin/rails contenus:charger`, 264 fichiers examinés :

| Passage | Durée | Résultat |
|---|---:|---|
| Premier (base sans leçon) | 174 s | 261 `created`, 1 `loaded` (Thalès), 2 `refused` |
| Rien de changé | 11 s | 262 `unchanged`, 2 `refused` |
| Tout changé (leçons publiées) | 191 s | 261 `replaced`, 1 `loaded`, 2 `refused` |

Estimation pour Develop : 84 des 263 fichiers v3 du programme ont eu une version v1 dans le dépôt (candidates au remplacement si leur titre n'a pas changé), 179 sont nés v3 (créées). Le décompte exact sera dans le journal du premier pré-déploiement.

## Ce qui a dérapé

- Ruby 3.4.9 absent du conteneur : installé par `rbenv install` (≈ 5 min).

## Ce qui reste ouvert

- 2 fichiers refusés par l'import (`1ere-c` et `1ere-d`, physique-chimie, « Généralités sur les composés organiques » : `question_structure` / `duplicate_accepted`, notion 6, question 3) : à corriger par la vague P3.
