# Journal — Comptes de test sur Staging

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-05 | Staging reçoit les établissements, classes et comptes du jeu, sans activité simulée | Recette connectée impossible sur Staging (choix du porteur) | oui, ADR-0124 §9 |

## À trancher

> Décisions qu'un agent a laissées ouvertes, ou tranchées par défaut en attendant le porteur. Relevées chaque jour par la boîte de décisions (`docs/workflows/contrat-de-session.md`).

- …

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- Sur Staging, `Rails.env` vaut `production` : `db/seeds.rb` choisit le stade par `AutomaticLoadStage` (`whole_lessons?` = Develop, `create_missing?` = Staging). `standard.rb` réutilise sa branche « develop » (pas de leçons, équipe sous `STANDARD_TEAM_PIN`, sans TOTP) pour Staging.
- `develop_stage_test.rb` affirmait que Staging ne sème rien du jeu (deux tests) : réduits à la production seule ; Staging a son test `staging_stage_test.rb`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | amendement ADR-0124 §9 |
| **UDR produits** | — |
