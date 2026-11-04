# Journal — Develop charge toutes les leçons v3 du dépôt, entières

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-04 | La liste `V3ProgrammeLevels` n'est pas élargie à `3eme` ; Develop ne la lit plus. | L'élargir aurait changé Staging (création des leçons de 3ème absentes). | ADR-0123 §10 |
| 2026-11-04 | Un chargement entier (Develop) s'enregistre sous `chargement-automatique-entiere-<niveau>-<matière>-<fichier>`. | Revue `silent-failure-hunter` : Thalès avait déjà été chargée sur Develop en « exercices et sujets » sous le même nom et avec la même empreinte ; elle serait restée `unchanged`, jamais remplacée entière. Un nom distinct, sans migration, fait recharger une fois tout fichier dont le dernier chargement n'était pas entier. | ADR-0124 §8 |
| 2026-11-04 | Option D d'ADR-0123 (N leçons par démarrage) non appliquée. | 417 leçons en 4 min 03 s en local ; Railway n'a pas coupé jusqu'ici. À appliquer seulement si le pré-déploiement est coupé (décision n° 7 du ticket). | — |

## Ce qui a dérapé

- Premier jet : la règle « Develop identique au dépôt » était vraie dans `mode_for`, mais l'empreinte d'un chargement « exercices et sujets » antérieur l'aurait contournée au premier déploiement pour les leçons à sujets. Trouvé par la revue, pas par les tests : ils partaient tous d'une base sans chargement antérieur. Un test de transition l'attrape désormais (domaine et intégration).
- Conséquence assumée du nom distinct : au premier déploiement, les ~46 leçons du manifeste déjà chargées entières sous l'ancien nom sont rechargées une fois (`replaced`), avec l'effacement consenti de leurs résultats.

## Ce qu'on a appris sur la codebase

- Le ticket annonçait 427 fichiers v3 ; la source en lit 417 au 2026-11-04 (les fichiers de plusieurs leçons ou d'un autre format sont écartés par `RepositoryLessonSource`).
- « Calcul littéral » (3ème) : le fichier a 4 notions, 1 exercice par notion (7 questions pour le premier) et une fiche d'entraînement, plus 4 exercices de leçon ; c'est ce que la base locale porte après chargement. Le « 5 exercices par notion » du ticket ne se retrouve pas dans le fichier actuel.

## Mesures

- Chargement réel `RAILWAY_ENVIRONMENT_NAME=Develop bin/rails contenus:charger`, base de développement locale, référentiel complété par le chargement : 417 leçons examinées, 417 créées, 0 en échec ou incomplète, 4 min 03 s.
- Thalès : 4 sujets, publiée.

## Dette et chantiers de suivi

- Aucun chantier de suivi ouvert.
- À vérifier après le premier déploiement de Develop : journal du pré-déploiement (`created` ou `replaced` pour chaque fichier, 0 en échec), temps réel ; si Railway coupe le pré-déploiement, appliquer l'option D d'ADR-0123 (décision n° 7 du ticket #473).
- À trancher par le pilote : « Calcul littéral » (3ème) a 1 exercice par notion dans le fichier, contre 5 annoncés par le ticket.
- Fusion de `Develop` (#475, Staging complète son référentiel) dans la branche : conflits dans ADR-0123 et `automatic_load_stage_test`, les deux changements gardés.

## Clôture

Clos le 2026-11-04 : PR #477 vers `Develop`, `bin/ci-quiet` vert sur `e491fe5a`. Pas d'ADR ni d'UDR nouveau : amendements d'ADR-0123 (§10) et d'ADR-0124 (§8).
