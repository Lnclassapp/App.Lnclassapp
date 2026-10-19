# Memo — Routage des modèles par rôle

| | |
|---|---|
| **Type de cycle** | refactoring *(processus et outillage des agents, aucun comportement produit)* |
| **Statut** | livré |
| **Ouvert le** | 2026-10-19 |
| **Branche** | `chore/routage-modeles` |
| **Programme** | — |

---

## Le problème

Toutes les tâches confiées aux agents passent par le même modèle, ou par un choix fait au cas par cas. Une vérification pure (jouer `bin/ci-quiet`, relancer un test système, publier un verdict) mobilise le même modèle qu'une revue de sécurité. Les trois sous-agents de revue (`security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`) tournent sur Sonnet alors que leur travail demande du jugement : les revues de la PR #250 ont trouvé des courses subtiles (concurrence, autorisation).

## Pour qui

Le porteur (coût et vitesse) et toute l'équipe qui collabore avec Claude Code sur Lnclass (qualité des revues).

## Décision du porteur (2026-10-19)

> « Il ne sert à rien de démarrer un train pour transporter un sac de maïs de 50 kg : une moto ou un vélo est adapté et rapide. »

| Rôle | Modèle |
|---|---|
| Orchestrateur (session principale) : cadrage, décisions, arbitrage des revues, fusions | **Opus** |
| Sous-agents de revue : `security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer` | **Opus** |
| Agents d'exécution : lots, tests et corrections à partir d'un plan cadré | **Sonnet** |
| Vérifications pures : `bin/ci-quiet`, tests système relancés, verdict | **Haiku** |

Règle : le plus petit modèle qui fait le travail ; monter d'un cran quand la tâche exige du jugement (sécurité, concurrence, architecture, décision métier).

## Pourquoi maintenant

Le chantier `sobriete-tokens` a fixé le coût comme frein à la cadence. Le choix du modèle est le levier restant qui ne coûte rien à appliquer, et la PR #250 vient de montrer où il ne faut pas économiser.

## Ce qui change

- ADR-0104 (la règle et sa raison) ; section dans `docs/workflows/README.md` (la règle qui fait autorité) ; section « Choix du modèle » dans `CLAUDE.md` (raccourci).
- `model: opus` sur les trois agents de revue.
- Deux agents nouveaux : `executant-lot` (Sonnet) et `verificateur-ci` (Haiku).

## Hors périmètre

- Les agents venant de plugins (ECC) : ils gardent leur propre réglage.
- Une garde automatique sur le frontmatter `model:` : la règle est une consigne de coût, pas un risque d'intégrité.

## Preuve

Aucune mesure de coût à ce stade. À regarder après un mois : part des vérifications jouées par Haiku, et nombre de constats de revue trouvés après fusion. Sans amélioration, la règle est revue.
