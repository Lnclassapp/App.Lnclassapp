# État — contenus-depot-dedie

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-14 · **Vague** : 1 · **Où on en est** : Lot A en PR ; Lot B attend la fusion de la PR de validation pédagogique (dépôt de contenus créé, vide)

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| A | session_011uw6y8hZAQ1XKGDPRrNkSH | `feature/contenus-depot-dedie` | voir journal | — | PR prête |
| B | — | — | — | — | attend PR validation pédagogique |
| C | — | — | — | — | après B |

## Décisions

Prises :

- 2026-11-14 · copie figée versionnée au même chemin (ADR) — par la session du chantier
- 2026-11-14 · dépôt `Kamkara007/App.Lnclassapp-contenus` — par le porteur

Ouvertes : `script/docs/a_trancher`, et les sections `## À trancher` des journaux des chantiers de la vague.

## Prochaine action

Quand `.claude/agents/validateur-pedagogique.md` est sur `origin/Develop` : Lot B (recette dans `plan.md`), puis Lot C.

## Prompt de reprise

```
Orchestrateur de contenus-depot-dedie. Lis docs/chantiers/contenus-depot-dedie/etat.md, vérifie sur GitHub les PR qu'il cite, puis : si la PR de validation pédagogique est fusionnée, lance le Lot B de plan.md.
```
