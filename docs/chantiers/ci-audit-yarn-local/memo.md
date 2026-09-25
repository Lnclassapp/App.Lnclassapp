# Memo — L'audit Yarn ralentit chaque `bin/ci` local

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | livré |
| **Ouvert le** | 2026-09-25 |
| **Branche** | `perf/ci-audit-yarn-local` |

## Le problème

`bin/ci` dure environ 9 minutes en local. L'étape « Security: Yarn vulnerability audit » en prend presque un tiers, et ce temps est surtout de l'attente réseau. Or son résultat ne change que si les dépendances JavaScript changent. Pendant la boucle pédagogique, trois agents lancent `bin/ci` plusieurs fois par lot, sur une machine de 4 cœurs.

## Mesure avant

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---|---|---|
| Durée de `yarn npm audit --all --recursive` | Poste local (4 cœurs), `package.json` et `yarn.lock` identiques à `origin/Develop` | 2 min 40 s | < 1 s quand les dépendances n'ont pas changé | `time` sur l'étape seule |
| Durée totale de `bin/ci` | Branche `feature/boucle-pedagogique` (0a, 0b, 0d, 0e) | 8 min 46 s | environ 6 min | sortie de `bin/ci` |

## Hors périmètre

- La CI GitHub : l'audit y reste lancé à chaque fois, parce que `CI=true`.
- Les tests unitaires et système, qui restent complets.
- La saturation de la machine par plusieurs `bin/ci` en parallèle : elle est traitée par l'organisation du travail des agents, pas par le code.
