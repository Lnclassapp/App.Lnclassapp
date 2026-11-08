# Plan d'exécution — Les leçons de Terminale A2 préparées comme Thalès

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — 28 leçons de même fiche qu'en Tle A1 : ajouts repris, recontrôlés ┐
Lot B — exponentielle, logarithme (relus pour A2), probabilité (rédigée)  ├─ indépendants
Lot C — README, retour hors de a-reprendre/, semis, empreinte (après A–B) ┘
```

Pas de Lot 0 : aucune migration, aucune entité, aucun port, aucune route.

## Lots A et B — contenu

- **Fichiers**     : `docs/contenus/lecons-traitees/tle-a2/<matière>/*.json` (et leur retrait de `a-reprendre/`)
- **Test associé** : script de vérification hors dépôt (le même qu'en Tle C) ; `bin/preuve-vague docs/contenus/lecons-traitees/tle-a2`
- **Done quand**   : 0 erreur sur chaque fichier, fichier commité identique au fichier vérifié (sha256), affichage vert à 390 px et sur ordinateur

## Lot C — clôture

- **Fichiers**     : `docs/contenus/README.md`, `docs/contenus/a-reprendre/README.md`, `db/seeds/standard/jeu.yml`, `test/db/seeds/standard_manifest_test.rb`, `test/db/seeds/standard_activity_test.rb`
- **Test associé** : `test/db/seeds/`
- **Done quand**   : tests verts, `bin/ci-quiet` niveau pr vert
