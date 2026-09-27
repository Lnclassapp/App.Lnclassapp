# Memo — Les gardes tournent deux fois dans `bin/ci`

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | livré |
| **Ouvert le** | 2026-09-26 |
| **Branche** | `perf/ci-gardes-en-double` |

## Le problème

`bin/ci` (et donc la CI GitHub, qui lance le même `config/ci.rb`) lance deux gardes en Ruby pur, sans démarrer Rails, dans leurs propres étapes : « Guard: Domain purity » (`test/domain/domain_purity_test.rb`) et « Guard: HITL headers » (`test/guards/repository_rules_test.rb`). L'étape « Tests: Rails » lance ensuite `bin/rails test`, dont le motif par défaut (`test/**/*_test.rb`) reprend ces deux fichiers : les 6 tests des gardes tournent une seconde fois.

## Mesure avant

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---|---|---|
| Tests des gardes dans « Tests: Rails » | `Develop` (7623dc53) | 6 | 0 | `bin/rails test -v`, lignes `DomainPurityTest#` et `RepositoryRulesTest#` |
| Durée des deux gardes | Conteneur local | 0,2 s | — | `time` sur les deux fichiers |

Le gain de temps est négligeable. L'intérêt est la clarté : chaque contrôle de `bin/ci` tourne une fois, à l'endroit où il est nommé.

## Hors périmètre

- `bin/rails test` lancé seul, en local : il garde les deux gardes. Un développeur qui ne lance que la suite les voit toujours.
- Le pre-commit, qui lance la garde de pureté sur les fichiers stagés : c'est un retour rapide avant la CI, pas un doublon dans la CI.
- Les tests système, déjà exclus de `bin/rails test`.
