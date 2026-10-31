# Plan d'exécution — Les 10 premières leçons d'Histoire-Géographie de Tle

## Graphe

```
Lot HG — 10 leçons (un rédacteur par leçon, 3 en parallèle) → contrôle → relecture IA indépendante → contrôle → rangement
```

## Lot HG — Les 10 leçons

- **Couche**       : contenus (+ test d'intégration du contenu, démo)
- **Fichiers**     : `docs/contenus/lecons-traitees/tle/histoire-geographie/*.json` (10) · retrait de `docs/contenus/lecons-traitees/tle-{a1,a2,c,d}/histoire-geographie/*.json` (12 v1) · `test/integration/contenus/tle_histoire_geographie_je_m_entraine_test.rb` · `db/seeds/demo/saint_michel.rb` · `docs/contenus/README.md` · journaux
- **Dépend de**    : —
- **Test associé** : `ruby script/contenus/valider.rb` sur les 10 fichiers ; test « Je m'entraîne » ; relecture IA indépendante.
- **Done quand**   : les 10 fichiers passent le contrôle et le test sans erreur ni avertissement après relecture.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `docs/contenus/lecons-traitees/tle*/histoire-geographie/*`, `docs/contenus/README.md` (section Tle HG) | Lot HG |
