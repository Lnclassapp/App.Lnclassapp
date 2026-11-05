# Plan d'exécution — Les leçons de 3ème préparées comme Thalès

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — Mathématiques (8)   ┐
Lot B — EDHC (10)           │
Lot C — Français (10)       ├─ indépendants : un rédacteur par leçon, un commit par matière
Lot D — Histoire-géo (10)   │
Lot E — Physique-chimie (10)│
Lot F — SVT (10)            ┘
Lot G — documentation des futures leçons, semis, empreinte (après A–F)
```

Il n'y a pas de Lot 0 : aucune migration, aucune entité, aucun port, aucune route.

## Lots A à F — une matière

- **Couche**       : contenu
- **Fichiers**     : `docs/contenus/lecons-traitees/3eme/<matière>/*.json` (sauf Thalès et Calcul littéral)
- **Dépend de**    : —
- **Test associé** : `test/integration/catalog/pilot_lessons_test.rb` (mathématiques) ; `LECONS=<fichiers> bin/rails test test/system/catalog/lesson_rendering_test.rb` ; script de vérification hors dépôt (format, valider.rb sur la leçon et chaque sujet, contenu d'origine inchangé, sympy en mathématiques et physique-chimie, extrait de la fiche pour chaque bonne réponse)
- **Done quand**   : le script rend 0 erreur sur chaque fichier de la matière, et le fichier commité est celui qui a été vérifié (même empreinte sha256)

## Lot G — clôture

- **Fichiers**     : `docs/contenus/prompt-redaction.md`, `docs/contenus/prompt-redaction-lot.md`, `docs/contenus/README.md`, `db/seeds/standard/jeu.yml`, `test/db/seeds/standard_activity_test.rb`
- **Dépend de**    : A–F
- **Test associé** : `standard_manifest_test.rb`, `standard_activity_test.rb`
- **Done quand**   : une nouvelle leçon rédigée avec le prompt porte d'office 2 exercices par notion et 4 sujets ; tests verts

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| un fichier de leçon | le lot de sa matière, un seul rédacteur |
| `docs/contenus/*.md`, `db/`, `test/` | Lot G |
