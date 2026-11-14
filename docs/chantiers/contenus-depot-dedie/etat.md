# État — contenus-depot-dedie

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-14 · **Vague** : 1 · **Où on en est** : Lots A, B et C livrés (#597, dépôt de contenus `main`, #602) ; reste la vérification de `valider.yml` une fois `APP_READ_TOKEN` posé

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| A | session_011uw6y8hZAQ1XKGDPRrNkSH | `feature/contenus-depot-dedie` | #597 | — | Fusionné |
| B | session_011uw6y7ydmchvQpQZBWaziC | `main` de `Lnclassapp/App.Lnclassapp-contenus` | contenus#1 (report de #603) | `1b69fc1` | Fusionné (`valider.yml` attend le secret `APP_READ_TOKEN`) |
| C | session_011uw6y7ydmchvQpQZBWaziC | `feature/contenus-depot-dedie-migration` | #602 | `0ad7a085` | Fusionné |

## Décisions

Prises :

- 2026-11-14 · copie figée versionnée au même chemin (ADR) — par la session du chantier
- 2026-11-14 · dépôt `Lnclassapp/App.Lnclassapp-contenus`, public — par le porteur

Ouvertes : `script/docs/a_trancher`, et les sections `## À trancher` des journaux des chantiers de la vague.

## Prochaine action

Le porteur pose `APP_READ_TOKEN` dans le dépôt de contenus ; relancer `valider.yml` sur `main` (workflow_dispatch) puis cocher les portes de sortie de `plan.md` et clore le journal.

## Prompt de reprise

```
Orchestrateur de contenus-depot-dedie. Lis docs/chantiers/contenus-depot-dedie/etat.md, vérifie sur GitHub les PR qu'il cite, puis : si la PR du Lot C est fusionnée et APP_READ_TOKEN posé, fais vérifier valider.yml sur une PR d'essai du dépôt de contenus et clos le chantier.
```
