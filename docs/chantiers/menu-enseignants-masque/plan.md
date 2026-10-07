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

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [ ] Bug reproduit **à la main** dans l'application avant toute ligne de code *(pas à la main : constaté sur les captures du levier 3c d'`ecrans-direction-lents`, puis reproduit dans Chrome par le test rouge, capture à l'appui, avant toute ligne de correctif)*
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test *(journal)*
- [x] Test de reproduction écrit **avant** le correctif *(lancé rouge avant de toucher la vue ; commité avec le correctif dans `c731adfa`)*
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié) *(1 échec, 0 erreur : « « Retirer de l'établissement » est masqué par la ligne suivante », ligne 60, après 5 assertions vertes : 3 lignes, Awa Koné au milieu, menu ouvert, entrée trouvée)*
- [x] Correctif appliqué dans la couche de la **cause**, pas du symptôme *(la cause est l'empilement CSS de la colonne d'actions : classes de la vue, `sticky-actions` au lieu de `sticky right-0 bg-white`)*
- [x] Test au vert · suite du contexte borné au vert *(suite complète `bin/rails test` : 3 983 tests, 0 échec, 0 erreur, 8 sauts déjà présents ; couverture 100 % lignes, 100 % branches ; tests système de la direction et `design_system_test.rb` : 48 tests, 0 échec ; RuboCop : 1 419 fichiers, aucune remarque)*
- [x] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours *(retrait depuis la dernière ligne, au bureau et à 390 px, et ⋮ à l'écran à 390 px : verts ; à 390 px, ligne du milieu, l'entrée est au-dessus à 10 %, 50 % et 90 % de sa largeur, capture à l'appui)*
- [x] Données déjà corrompues : réparées, ou dette explicitement notée au journal *(aucune : un clic égaré ne retire personne, voir `memo.md`)*
- [ ] Challenger a rejoué les étapes de reproduction dans l'application *(pas de rôle distinct dans ce chantier : l'auteur a rejoué la reproduction dans Chrome, au bureau et à 390 px ; à faire par le relecteur de la PR)*
- [x] Commit `fix(<contexte>): …` avec la ligne `Chantier:` *(`c731adfa`)*
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés
- [x] Garde de budget système : `teachers_test.rb` réenregistré par `script/ci/record_timings`, + 5,7 s pour un budget de 15 s
