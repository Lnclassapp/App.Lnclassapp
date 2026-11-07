# Plan d'exécution — Les leçons de Terminale C préparées comme Thalès

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — Mathématiques (10)    ┐
Lot B — Français (6)          │
Lot C — Philosophie (9)       ├─ indépendants : un rédacteur par leçon, un commit par matière
Lot D — Physique-chimie (10)  │
Lot E — SVT (10)              ┘
Lot F — README des contenus, semis, empreinte (après A–E)
```

Il n'y a pas de Lot 0 : aucune migration, aucune entité, aucun port, aucune route.

## Lots A à E — une matière

- **Couche**       : contenu
- **Fichiers**     : `docs/contenus/lecons-traitees/tle-c/<matière>/*.json`
- **Dépend de**    : —
- **Test associé** : `LECONS=<fichiers> bin/rails test test/system/catalog/lesson_rendering_test.rb` ; script de vérification hors dépôt (format, valider.rb sur la leçon et chaque sujet, contenu d'origine inchangé, sympy et réponses faussées exprès en mathématiques et physique-chimie, extrait de la leçon pour chaque bonne réponse ailleurs)
- **Done quand**   : le script rend 0 erreur sur chaque fichier de la matière, et le fichier commité est celui qui a été vérifié (même empreinte sha256)

## Lot F — clôture

- **Fichiers**     : `docs/contenus/README.md`, `db/seeds/standard/jeu.yml`, `test/db/seeds/standard_activity_test.rb`
- **Dépend de**    : A–E
- **Test associé** : `standard_manifest_test.rb`, `standard_activity_test.rb`
- **Done quand**   : tests verts

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| un fichier de leçon | le lot de sa matière, un seul rédacteur |
| `docs/contenus/README.md`, `db/`, `test/` | Lot F |
