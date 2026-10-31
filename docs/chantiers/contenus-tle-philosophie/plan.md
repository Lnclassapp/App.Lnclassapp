# Plan d'exécution — Les 10 premières leçons de Philosophie de Tle

## Graphe

```
Lot P — consigne Philosophie (prompt-redaction.md, prompt-redaction-lot.md)
  ↓
Lot PH — 10 leçons (un rédacteur par leçon, 3 en parallèle) → contrôle → relecture IA indépendante → contrôle → déclinaison A1, A2, C, D
```

## Lot P — Consigne de rédaction pour la Philosophie

- **Couche**       : documentation
- **Fichiers**     : `docs/contenus/prompt-redaction.md` · `docs/contenus/prompt-redaction-lot.md` · chantier
- **Dépend de**    : —
- **Test associé** : relecture ; le Lot PH s'en sert tel quel.
- **Done quand**   : la ligne Philosophie de « Selon la matière » et la section « Auteurs, doctrines et textes » existent.

## Lot PH — Les 10 leçons

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/tle-{a1,a2,c,d}/philosophie/*.json` (38, dont les 12 v1 remplacés) · `docs/contenus/README.md` · journaux
- **Dépend de**    : Lot P
- **Test associé** : `ruby script/contenus/valider.rb` sur les 38 fichiers ; relecture IA indépendante ; challenger.
- **Done quand**   : les 38 fichiers passent le contrôle sans erreur ni avertissement après relecture.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `docs/contenus/prompt-redaction*.md` | Lot P |
| `docs/contenus/lecons-traitees/tle-*/philosophie/*`, `docs/contenus/README.md` (section Tle Philosophie) | Lot PH |
