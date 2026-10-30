# Plan d'exécution — Validation des figures bornée

> Format des lots : [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — coupure au-delà des bornes + recherches en Set/Hash (un seul lot, un seul commit, clôture comprise)
```

Les deux leviers sont mesurés séparément (memo, « Mesures après ») : la coupure seule suffit à la cible ; le passage en `Set`/`Hash` et `rooted?` en un parcours sont demandés par le porteur et gardent un coût linéaire si une borne venait à monter.

---

## Lot A — Validation des figures bornée

- **Couche**       : domaine
- **Fichiers**     : `app/domain/entities/catalog/figure.rb`
                     `test/domain/entities/catalog/figure_test.rb`
                     `docs/chantiers/validation-figures-bornee/bench.rb`
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/catalog/figure_test.rb` (4 tests de garde : `diagram` `tree` en chaîne, `map`, `plate`, `geometry` à 5 000 éléments, < 50 ms ; une liste pile à sa borne garde ses contrôles) · `test/script/contenus/parite_import_test.rb`
- **Done quand**   : les 4 cas à 5 000 éléments passent de 50 ms à > 60 s à moins de 50 ms (médiane de 3, même bench) ; sortie de `valider.rb` identique sur toutes les leçons rangées ; couverture 100 % lignes et branches de `figure.rb`

---

## Contrat d'exécution

1. Bench versionné (`bench.rb`) qui produit la valeur avant.
2. Tests de non-régression fonctionnelle verts avant le premier levier (`figure_test.rb`, `parite_import_test.rb`).
3. Un levier, le bench, le chiffre. Gain nul : on annule le pas.
4. **Le chantier ne se clôt pas sans mesure après** : même machine, même volume, même méthode, 3 exécutions, médiane.

## Portes de sortie

- [x] `memo.md` : métrique nommée, **valeur avant chiffrée**, volume de données précisé, cible chiffrée
- [x] Protocole de mesure écrit et reproductible par quelqu'un d'autre
- [x] Explorer coût rendu : où part réellement le temps (pas une hypothèse)
- [x] ADR écrit si un contrat change — sans objet : aucun port, aucune borne, aucun code d'erreur ne change
- [x] Bench versionné, produisant la valeur avant
- [x] Tests de non-régression fonctionnelle verts **avant** le premier levier
- [x] Un lot = un levier = un chiffre — un lot, deux leviers mesurés séparément
- [x] Chaque levier sans gain mesuré a été **annulé**, pas conservé
- [x] Bench après : même machine, même volume, même méthode, ≥ 3 exécutions, médiane
- [x] Tableau `Mesures` complété (Avant / Cible / Après)
- [ ] **Challenger a relancé le bench lui-même** et obtenu le gain annoncé
- [x] Résultat fonctionnel strictement identique (aucun écran, aucune sortie modifiés)
- [x] Pureté domaine · rubocop · tests · brakeman : au vert
- [x] `journal.md` : leviers abandonnés et pourquoi
