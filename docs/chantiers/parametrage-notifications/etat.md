# État — parametrage-notifications

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-25 · **Vague** : 2 terminée, revues faites · **Où on en est** : PR Lnclassapp/App.Lnclassapp#716 prête vers `Develop`, en attente de la preuve des tests système.

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| 0 | executant-lot | `claude/happy-newton-rj5i1c` | #716 | 9156b418 | fusionné dans la branche de chantier |
| A | executant-lot | `feature/parametrage-notifications-lot-a` | #716 | ae4223c3 | fusionné dans la branche de chantier |
| B | executant-lot | `feature/parametrage-notifications-lot-b` | #716 | 3d392093 | fusionné dans la branche de chantier |
| C | executant-lot | `feature/parametrage-notifications-lot-c` | #716 | 73c24907 | fusionné dans la branche de chantier |
| D | executant-lot | `feature/parametrage-notifications-lot-d` | #716 | 0230da26 | fusionné dans la branche de chantier |
| R (revues) | executant-lot | `claude/happy-newton-rj5i1c` | #716 | db9468a0 | fusionné dans la branche de chantier |

## Décisions

Prises :

- 2026-11-25 · aucun envoi sans geste de l'équipe ; 3 motifs automatisables, décochés au départ ; « Prévenir les élèves » à la publication d'une annonce — par le porteur
- 2026-11-25 · 10 notifications au plus par jour et par élève — par le porteur
- 2026-11-25 · nouveau motif « Nouveaux exercices » — par le porteur

Ouvertes : `## À trancher` du journal.

## Prochaine action

`bin/ci-quiet` local (head c330afba) : tout vert sauf les tests système et la garde du budget système, non jouables dans la session cloud (ChromeDriver 147 / Chrome 158). Jouer `bin/system-changed` sur un poste aux versions assorties, enregistrer la durée de `test/system/teams/push_settings_test.rb` dans `script/ci/test_timings.yml`, coller la ligne de preuve dans la PR, puis fusionner. `PUSH_DELIVERY_ENABLED` reste `false`.

## Prompt de reprise

```
Orchestrateur de parametrage-notifications. Lis docs/chantiers/parametrage-notifications/etat.md, vérifie la PR #716, puis : joue bin/system-changed, enregistre la durée du test système des Notifications, colle la ligne de preuve de bin/ci-quiet et fusionne vers Develop.
```
