# Journal — Seeds joués deux fois au déploiement, `image_processing` réclamé au démarrage

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-29 | `seeds: false` en production dans `config/database.yml`, commande de pré-déploiement inchangée | Corrige à la cause (le semis implicite de `db:prepare`) sans toucher au réglage Railway ni au code des seeds | Oui — amendement du 2026-09-29 de l'ADR-0052 |
| 2026-09-29 | Processeur de variantes `:disabled` dans tous les environnements, pas de gem `image_processing` | Aucune variante demandée (ADR-0060) ; la gem et libvips alourdiraient l'image pour rien | Non — application de l'ADR-0060, justifiée au memo |
| 2026-09-29 | Test de bout en bout : la commande de `railway.json` jouée en production sur une base vide jetable | Le trou de test venait de ce qu'aucun test ne passait par les tâches Rake ; c'est la reproduction exacte du défaut | Non |

## Ce qui a dérapé

- L'amendement du 2026-09-27 reposait sur une prémisse fausse (« `db:prepare` ne sème qu'une base qu'il crée ») : le défaut n'apparaissait que sur une base existante **vide**, cas du premier déploiement de chaque projet Railway neuf.

## Ce qu'on a appris sur la codebase

- `db:prepare` sème toute base sans `schema_migrations`, si `seeds?` de la configuration est vrai (vrai par défaut pour la base primaire) ; la clé `seeds:` de `database.yml` le règle par environnement. `db:seed` l'ignore.
- `load_defaults 8.1` choisit le processeur `:vips` ; sans `image_processing`, Rails n'échoue pas, il avertit à chaque démarrage.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| — | — | aucun |

## Vérification

2026-09-29 : `bin/rubocop`, suite complète (`CI=1 PARALLEL_WORKERS=2`, 100 % lignes et branches), tests système (`COVERAGE=0`), `bin/brakeman`. `Dockerfile` non modifié ; pas de Docker dans l'environnement de travail.
