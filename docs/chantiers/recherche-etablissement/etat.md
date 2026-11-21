# État — recherche-etablissement

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-21 · **Vague** : retours terrain Tiassalé (D3) · **Où on en est** : PR #665 prête vers `Develop` ; bin/ci-quiet vert sauf Brakeman (Ruby 3.4.9 signalé par Brakeman 8.1.1, PR Ruby à part)

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| A | session unique | `feature/recherche-etablissement` | #665 | ligne de preuve `bin/ci-quiet` dans la PR | PR prête |

## Décisions

Prises :

- 2026-11-20 · un seul champ de recherche à la place de DRENA puis établissement (D3) — par le porteur

Ouvertes : `script/docs/a_trancher`, et `journal.md` § À trancher (direction, DRENA déduite, résumé « Changer », vouvoiement).

## Prochaine action

Montée de Ruby sur `Develop` (hors chantier), rebase, `bin/ci-quiet` et ligne de preuve verte dans #665 ; recette sur téléphone (`bin/tester-pr <PR> --telephone`), puis fusion vers `Develop` ; si `entree-eleve-unifiee` fusionne avant, rebase.

## Prompt de reprise

```
Orchestrateur de recherche-etablissement. Lis docs/chantiers/recherche-etablissement/etat.md, vérifie sur GitHub la PR de la branche feature/recherche-etablissement, puis fusionne-la si elle est verte et recettée.
```
