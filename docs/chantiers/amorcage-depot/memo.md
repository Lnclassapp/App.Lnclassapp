# Memo — Amorçage du dépôt (V0)

| | |
|---|---|
| **Type de cycle** | feature (sans UI métier) |
| **Statut** | en cours |
| **Ouvert le** | 2026-09-25 |
| **Branche** | `feature/amorcage-depot` |
| **Programme** | `refonte-application` — vague V0 ([feuille de route §2](../refonte-application/feuille-de-route.md#2-phase-0--amorçage-du-dépôt)) |

---

## Le problème

Le nouveau dépôt naît d'un `rails new` : aucun garde-fou mécanique. Sans eux, la première ligne de code métier écrite par un agent entre sans pureté du domaine, sans couverture, sans CSP, et la production tourne en HTTP sur un disque éphémère.

## Ce que livre le chantier

Les sept garde-fous de la feuille de route §2, chacun avec sa preuve dans [`journal.md`](journal.md) :

1. socle documentaire versionné ;
2. `bin/setup` active le hook pre-commit, de façon idempotente ;
3. pre-commit : pureté du domaine, en-tête HITL, `# :nocov:`, rubocop ;
4. une seule CI (`config/ci.rb`), lancée par `bin/ci` en local et par GitHub, couverture 100 % lignes et branches, tests système Chrome headless, budget de poids ;
5. branches protégées (commandes pour l'orchestrateur) ;
6. configuration de production (HTTPS, hôtes, CSP, filtres de logs, stockage, i18n, navigateurs, worker) ;
7. un test système « page d'accueil ».

## Décisions consommées

ADR-0010, 0024, 0049, 0051, 0052. ADR-0047 (stockage) est attendu : le service `:amazon` est préparé, pas activé.

## Hors périmètre

Vues, JavaScript et CSS (chantier `design-baseline`), authentification de l'espace équipe (Lot 0 de la V1), test de mutation (ADR-0024 : à brancher avec le premier code de domaine).
