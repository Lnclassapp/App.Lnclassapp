# État — contenus-depot-dedie

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-14 · **Vague** : 1 · **Où on en est** : Lot A fusionné (#597) ; Lot B fait (dépôt de contenus peuplé, historique conservé) ; Lot C en PR

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| A | session_011uw6y8hZAQ1XKGDPRrNkSH | `feature/contenus-depot-dedie` | #597 | — | Fusionné |
| B | session_011uw6y7ydmchvQpQZBWaziC | `main` de `Lnclassapp/App.Lnclassapp-contenus` | — | `eced0ac` | Done (`valider.yml` attend le secret `APP_READ_TOKEN`) |
| C | session_011uw6y7ydmchvQpQZBWaziC | `feature/contenus-depot-dedie-migration` | voir journal | — | PR prête |

## Décisions

Prises :

- 2026-11-14 · copie figée versionnée au même chemin (ADR) — par la session du chantier
- 2026-11-14 · dépôt `Lnclassapp/App.Lnclassapp-contenus`, public — par le porteur

Ouvertes : `script/docs/a_trancher`, et les sections `## À trancher` des journaux des chantiers de la vague.

## Prochaine action

Fusionner la PR du Lot C ; le porteur pose `APP_READ_TOKEN` dans le dépôt de contenus, puis une PR d'essai y vérifie `valider.yml`. Ensuite : portes de sortie de `plan.md`, clôture du journal.

## Prompt de reprise

```
Orchestrateur de contenus-depot-dedie. Lis docs/chantiers/contenus-depot-dedie/etat.md, vérifie sur GitHub les PR qu'il cite, puis : si la PR du Lot C est fusionnée et APP_READ_TOKEN posé, fais vérifier valider.yml sur une PR d'essai du dépôt de contenus et clos le chantier.
```
