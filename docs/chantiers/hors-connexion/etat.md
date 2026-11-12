# État — hors-connexion

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-12 · **Vague** : jour 1 (Lot 0 → A ‖ B ‖ C) · **Où on en est** : cadrage écrit, lots en exécution

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| 0 | | `feature/hors-connexion` | | | en cours |
| A | | `feature/hors-connexion-lot-a` | | | à lancer |
| B | | `feature/hors-connexion-lot-b` | | | à lancer |
| C | | `feature/hors-connexion-lot-c` | | | à lancer |
| D | | `feature/hors-connexion-2` | | | jour 2 |

## Décisions

Prises :

- 2026-11-12 · élève et enseignant, élève d'abord ; corrigé sur le téléphone ; PWA ; pages déjà ouvertes seulement — par le porteur

Ouvertes : `script/docs/a_trancher`, et les sections `## À trancher` des journaux des chantiers de la vague.

## Prochaine action

Fusionner le Lot 0, puis A, B, C dans l'ordre de leur PR ; lancer le Lot D le jour 2.

## Prompt de reprise

```
Orchestrateur de hors-connexion. Lis docs/chantiers/hors-connexion/etat.md, vérifie sur GitHub les PR qu'il cite, puis : fusionne les PR prêtes dans l'ordre 0, A, B, C et lance le Lot D depuis Develop.
```
