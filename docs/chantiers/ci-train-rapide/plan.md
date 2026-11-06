# Plan d'exécution — Un train plus rapide sur GitHub

Un levier par lot ; A et B touchent les mêmes fichiers de CI, donc B s'empile sur A. C est indépendant (documentation).

## Graphe

```
Lot A — unit en 3 parts      Lot C — fusion sans déploiement (doc)
  ↓
Lot B — lecons en 7 parts, 19 tâches au plus
  ↓
(Lot D — assets partagés : seulement si A + B manquent la cible)
```

---

## Lot A — La suite unitaire en trois parts

- **Couche**       : CI
- **Fichiers**     : `.github/workflows/ci.yml` (tirage `unit:k/3`, `coverage_collate 3`) · `config/ci.rb` (commentaires) · `test/guards/ci_plan_test.rb` (`UNIT_PARTS = 3`) · ADR-0107 §9 · ADR-0064 §8
- **Dépend de**    : —
- **Test associé** : `test/guards/ci_plan_test.rb` (les 3 parts jouent exactement la suite entière ; `coverage` fusionne 3 résultats avec le seuil)
- **Done quand**   : sur GitHub, chaque `unit unit:k/3` < 180 s et `coverage` à 100 % / 100 %, médiane de 3 exécutions.

## Lot B — Les leçons en sept parts, pas de file d'attente

- **Couche**       : CI
- **Fichiers**     : `.github/workflows/ci.yml` (matrice `lecons` 1..7, `LECONS_PART: …/7`) · `test/guards/ci_plan_test.rb` (au plus 19 tâches de test prêtes ensemble sur un run complet) · ADR-0107 §9
- **Dépend de**    : Lot A
- **Test associé** : `test/guards/ci_plan_test.rb`
- **Done quand**   : aucune tâche en file sur un train seul ; horloge < 210 s, médiane de 3 exécutions.

## Lot C — Une fusion dans `main` sans déploiement

- **Couche**       : documentation
- **Fichiers**     : `docs/guide/retour-arriere.md` (§ nouvelle)
- **Dépend de**    : —
- **Done quand**   : le guide dit quoi vérifier après chaque fusion dans `main` et `Staging`, et que les « Recent Deliveries » du webhook GitHub → Railway sont à relire par le porteur.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `.github/workflows/ci.yml` | A puis B (empilés) |
| `test/guards/ci_plan_test.rb` | A puis B (empilés) |
| `docs/decisions/adr/0107-…` | A puis B (empilés) |
| `docs/guide/retour-arriere.md` | C |

## Contrat d'exécution

1. Bench : les durées par tâche de la CI GitHub (avant : runs 41921296454, 41917971824, 41916186112).
2. Non-régression : `bin/ci-quiet` local ; sur GitHub, `coverage` 100 % / 100 % et le même nombre de tests.
3. Un levier par lot, mesuré ; retiré si le gain est nul.

## Portes de sortie

- [x] `memo.md` : métrique nommée, valeur avant chiffrée, volume précisé, cible chiffrée
- [x] Protocole de mesure écrit et reproductible
- [x] Où part réellement le temps : chemin critique et file mesurés
- [x] ADR amendé (ADR-0107 §9)
- [ ] Bench après : ≥ 3 exécutions, médiane
- [ ] Tableau `Mesures après` complété
- [x] Résultat fonctionnel identique (aucun test retiré)
- [ ] `journal.md` : leviers abandonnés et pourquoi
