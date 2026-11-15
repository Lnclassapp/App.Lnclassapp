# État — simplification-ecrans-eleve

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-15 · **Vague** : 1 (un seul chantier) · **Où on en est** : chantier terminé ; PR #627 fusionnée dans Develop le 2026-11-15 (commit de fusion `6be8f223`).

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| 0 règles et socle | session du chantier | `feature/simplification-ecrans-eleve` | #627 | `05867d4e` | fait, fusionné |
| A accueil | idem | idem | #627 | idem | fait, fusionné |
| B matière | idem | idem | #627 | idem | fait, fusionné |
| C leçon | idem | idem | #627 | idem | fait, fusionné |
| D skill `ecrans-wave` | idem | idem | #627 | idem | fait, fusionné |
| E conformité aux maquettes | idem | idem | #627 | idem | fait, fusionné |
| F marges de l'accueil à 20 px | idem | idem | #627 | idem | fait, fusionné |
| G fiche de révision sur sa propre page | idem | idem | #627 | idem | fait, fusionné |

## Décisions

Prises :

- 2026-11-14 · maquettes validées, jonction à 159 px, icône de leçon automatique, 3 éléments puis « Voir plus (n) » — par le porteur (`maquettes/README.md`).
- 2026-11-15 · la fiche de révision a sa propre page (`/courses/<slug>/fiche`) ; la leçon s'arrête après « Prépare devoirs » — par le porteur.
- 2026-11-15 · « Entrer en classe » garde son rendu normal, sans gras — par le porteur.

Ouvertes : `script/docs/a_trancher`, et `## À trancher` du `journal.md`.

## Ce qui reste ouvert

- Téléverser `lnclass-design-system-SKILL.md` sur claude.ai (geste du porteur).
- « Prochain exercice » est retiré des écrans, son code est conservé pour l'issue « Réutiliser « Prochain exercice » dans l'activation après l'inscription ».
- Écarts connus aux maquettes : icône de l'interro (presse-papiers), « À faire » limité à 3 lignes (règle 8).
- Numéro de l'UDR « écrans minimalistes, style Wave » à poser par `script/docs/build_index --number` s'il ne l'est pas déjà.

## Prompt de reprise

```
Chantier simplification-ecrans-eleve terminé. Lis docs/chantiers/simplification-ecrans-eleve/etat.md ; il ne reste que les points de « Ce qui reste ouvert ».
```
