# Journal — Routage des modèles par rôle

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-19 | Opus pour l'orchestrateur et les trois sous-agents de revue ; Sonnet pour l'exécution ; Haiku pour les vérifications pures | Voir la citation du porteur dans `memo.md` ; les revues de la PR #250 ont trouvé des courses subtiles | Oui, ADR-0104 |
| 2026-10-19 | La règle de référence vit dans `docs/workflows/README.md`, `CLAUDE.md` n'en est que le raccourci | `docs/` fait autorité (`CLAUDE.md`, en-tête) | Oui, ADR-0104 §6 |
| 2026-10-19 | Pas de garde automatique sur le frontmatter | Un mauvais `model:` coûte de l'argent, pas de l'intégrité ; à revoir si la règle dérive | — |

## Ce qui a dérapé

- Rien à ce stade.

## Ce qu'on a appris sur la codebase

- Les trois agents de revue étaient à `model: sonnet` ; aucun agent d'exécution ni de vérification n'existait dans `.claude/agents/`.
- Aucune garde de `test/guards/` ne lit la documentation ou `.claude/agents/`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Mesurer la part des vérifications jouées par Haiku et le coût associé | Pas d'instrument de coût par agent aujourd'hui | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-19 |
| **PR** | à renseigner à l'ouverture |
| **ADR produits** | [ADR-0104](../../decisions/adr/0104-routage-des-modeles-par-role.md) |
| **UDR produits** | — |
