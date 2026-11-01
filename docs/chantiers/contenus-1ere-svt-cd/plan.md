# Plan d'exécution — Les 10 premières leçons de SVT de 1ère C et D

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot C — 10 leçons de 1ère C (dont 4 communes)      rédaction : 3 sous-agents au plus en parallèle
Lot D — 6 leçons propres à D + 4 déclinaisons       (D1, D3, D4 adaptées de C1, C3, C6 après leur relecture)
  chaque leçon : rédaction → contrôles → relecture indépendante (Opus) → corrections → contrôles
Clôture — README des contenus, journaux, PR
```

Pas de Lot 0 : aucun contrat, aucune table, aucune route.

## Lot C — Les 10 leçons de 1ère C
- **Couche** : contenus
- **Fichiers** : `docs/contenus/lecons-traitees/1ere-c/svt/*.json` (10, dont 3 v1 remplacés)
- **Dépend de** : —
- **Test associé** : `ruby script/contenus/valider.rb` ; contrôle de l'entraînement (`NotionPractice.errors_for`) ; relecture indépendante (Opus)
- **Done quand** : les 10 fichiers passent les deux contrôles sans erreur ni avertissement après relecture.

## Lot D — Les 10 leçons de 1ère D
- **Couche** : contenus
- **Fichiers** : `docs/contenus/lecons-traitees/1ere-d/svt/*.json` (10, dont 3 v1 remplacés)
- **Dépend de** : Lot C (4 déclinaisons, 3 adaptations)
- **Test associé** : idem Lot C ; les déclinaisons ne diffèrent que par `series_name` et `subtitle`.
- **Done quand** : idem Lot C.

## Clôture
- **Fichiers** : `docs/contenus/README.md` (section 1ère) · `docs/chantiers/contenus-v3-tous-niveaux/journal.md` · journal du chantier
- **Test associé** : `bin/ci-quiet` (niveau doc)

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `lecons-traitees/1ere-c/svt/*` | Lot C |
| `lecons-traitees/1ere-d/svt/*` | Lot D |
| README des contenus, journal du programme | Clôture |

## Portes de sortie
- [x] memo, prd, plan complets · [ ] lots livrés · [ ] `bin/ci-quiet` vert · [ ] PR vers `Develop` · [ ] journal clos
