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

## Clôture

- Fusionnée dans `Develop` par [#439](https://github.com/Lnclassapp/App.Lnclassapp/pull/439) le 2026-11-02, après intégration de `Develop` (preuve `bin/ci-quiet` pr verte sur `dbbd6a28`).
- Les 2 fichiers refusés de 1ère C/D (« Généralités sur les composés organiques », `duplicate_accepted`) ont été corrigés sur `Develop` (cbf4eaed8) avant la fusion.

## Ce qui reste ouvert

- Lire le journal du premier pré-déploiement de Develop : compte exact des leçons `replaced` et `created`, et durée réelle sur Railway (174 s en local).

## Suite : toutes les leçons refusées sur Develop (2026-11-02)

- Constat (orchestrateur, déploiement `28a2172c`) : 297 leçons « import refusé (completed, 1 erreur(s)) », Thalès inchangée ; en local, base de démo, tout passe.
- Cause probable, vue de l'extérieur en lecture seule : sur Develop, `/niveaux/3eme` répond 200, `/niveaux/tle`, `/niveaux/1ere`, `/niveaux/2nde` (et `terminale`, `premiere`, `seconde`) répondent 404 ; cette page ne répond 404 que si le niveau n'existe pas. Le référentiel de Develop est créé à l'écran (les seeds `catalog` ne tournent qu'en développement, test et PR) : sans niveau Tle ni 1ère, chaque leçon a une seule erreur, `unknown_level`. Les matières (Philosophie, SVT…) et les couples niveau-série peuvent manquer aussi.
- Correction du code : le journal d'une leçon refusée écrit le code, le chemin et les paramètres sûrs de ses 3 premières erreurs (`value`, `keyword`, `rule`, `exception`, `constraint`) ; un `write_failed` porte la classe de l'exception et le nom de la contrainte PostgreSQL. Test d'intégration : Develop dont le niveau s'appelle « Terminale » journalise `unknown_level courses[0].level_name (value: Tle)`.
- La cause elle-même n'est pas corrigée par le code : créer sur Develop les niveaux Tle (A1, A2, C, D), 1ère (A1, A2, C, D), 2nde (A, C) et les matières manquantes est une décision du porteur (écran Référentiel, ou semis du référentiel réservé à Develop). Le déploiement suivant rechargera seul les leçons refusées.

