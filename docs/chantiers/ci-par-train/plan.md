# Plan — ci-par-train

Un seul lot, à la demande du porteur (règles posées puis appliquées tout de suite).

| Lot | Levier | Fichiers | Done quand |
|---|---|---|---|
| A | Niveau doc, verdict par empreinte, périmètre pr, train sur `Develop` | `script/ci/scope.rb`, `bin/ci-quiet`, `test/config/ci_scope_test.rb`, ADR-0107, règles (`CLAUDE.md`, `docs/workflows/README.md`, agents) | Sur les 28 dernières PR, ≤ 5 suites complètes au lieu de 28 : **3** |

## Portes de sortie

- [x] `memo.md` : métrique nommée, valeur avant relevée, volume précisé, cible chiffrée
- [x] Protocole écrit et reproductible (`journal.md`)
- [x] ADR écrit (ADR-0107)
- [x] Un lot = un levier = un chiffre
- [x] Tableau `Mesures` complété (Avant / Cible / Après)
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert (preuve train de cette PR)
