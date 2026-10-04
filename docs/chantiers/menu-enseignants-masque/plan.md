# Plan d'exécution — Menu ⋮ des enseignants masqué par la ligne suivante

> Cycle bugfix : un lot, un correctif, un test. Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot 0 — correctif (seul)
```

---

## Lot 0 — La colonne d'actions des enseignants prend `sticky-actions`

- **Couche**       : ui
- **Fichiers**     : `app/views/school_admin/teachers/index.html.erb`
                     `test/system/school_admin/teachers_test.rb`
- **Dépend de**    : —
- **Test associé** : `test/system/school_admin/teachers_test.rb`, « GD-14: the ⋮ menu of a row in the middle is above the next rows, and its « Retirer » opens that teacher's confirmation »
- **Done quand**   : avec trois enseignants, le menu ⋮ de la ligne du milieu ouvert, le centre de « Retirer de l'établissement » est l'entrée elle-même (`document.elementFromPoint`), et un clic y ouvre la confirmation de retrait de cet enseignant

Aucune migration, aucun fichier partagé. Aucune autre occurrence identique à corriger (étendue : [`journal.md`](journal.md)).

---

## Vérification de collision

Un seul lot. Hors chantier : `perf/ecrans-direction-lents` réécrit les lignes de la même vue (levier 3b) ; voir `journal.md`.

## Portes de sortie

- [ ] Symptôme et étapes de reproduction écrits dans `memo.md`
- [ ] Bug reproduit **à la main** dans l'application avant toute ligne de code
- [ ] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [ ] Test de reproduction écrit **avant** le correctif
- [ ] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [ ] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [ ] Test au vert · suite du contexte borné au vert
- [ ] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [ ] Données déjà corrompues : réparées, ou dette explicitement notée au journal
- [ ] Challenger a rejoué les étapes de reproduction dans l'application
- [ ] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [ ] `journal.md` : cause, trou de test comblé, effets de bord écartés
