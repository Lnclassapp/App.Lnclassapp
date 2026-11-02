# Plan d'exécution — Les 8 premières leçons de Philosophie de 1ère

## Graphe

```
Lot PH — 8 leçons (un rédacteur par leçon) → contrôle → relecture Opus indépendante → corrections → contrôle → déclinaison A1, A2, C, D
```

## Lot PH — Les 8 leçons

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/1ere-{a1,a2,c,d}/philosophie/*.json` (32, dont les 12 v1 remplacés) · `docs/contenus/README.md` · journaux
- **Dépend de**    : règles Philosophie de `prompt-redaction.md` (vague T6, déjà fusionnée)
- **Test associé** : `ruby script/contenus/valider.rb` sur les 32 fichiers ; relecture Opus indépendante.
- **Done quand**   : les 32 fichiers passent le contrôle sans erreur ni avertissement après relecture.
