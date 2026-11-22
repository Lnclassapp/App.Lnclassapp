# État — hors-connexion-total

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-22 · **Vague** : jour 1 (Lot 0 → A ‖ B ‖ C ‖ D), jour 2 (E) · **Où on en est** : grill arrêté à Q14 par le porteur ; cadrage et plan à jour ; pas de code, en attente du départ

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| 0 | | `feature/hors-connexion-total` | | | à lancer |
| A | | `feature/hors-connexion-total-lot-a` | | | à lancer |
| B | | `feature/hors-connexion-total-lot-b` | | | à lancer |
| C | | `feature/hors-connexion-total-lot-c` | | | à lancer |
| D | | `feature/hors-connexion-total-lot-d` | | | à lancer |
| E | | `feature/hors-connexion-total-2` | | | jour 2 |

## Décisions

Prises :

- 2026-11-22 · tout le catalogue auquel le compte a droit, son niveau d'abord, le reste en Wi-Fi ou sur demande ; élève + enseignant avec écriture (devoirs, archivage, jours de cours) ; enseignant sans téléchargement d'avance ; corrigé de l'entraînement sur l'appareil ; images des leçons gardées ; leçons communes non purgées à la déconnexion ; copie corrigée sur la version reçue (30 jours) ; PWA seulement ; compte désactivé effacé au retour du réseau ; niveau mis à jour même en données mobiles, le reste en Wi-Fi ; un élève n'a qu'un niveau — par le porteur
- 2026-11-22 · Q12, Q13, Q14 sans préférence : options prudentes appliquées, en `## À trancher` du journal — par l'orchestrateur

Ouvertes : `script/docs/a_trancher`, et les sections `## À trancher` des journaux des chantiers de la vague.

## Prochaine action

Au départ du porteur : lancer le Lot 0 (executant-lot, Sonnet), le fusionner dans la branche de chantier, puis A, B, C, D en parallèle.

## Prompt de reprise

```
Orchestrateur de hors-connexion-total. Lis docs/chantiers/hors-connexion-total/etat.md, vérifie sur GitHub les PR qu'il cite, puis : lance le Lot 0, fusionne-le dans feature/hors-connexion-total, puis lance A, B, C, D en parallèle.
```
