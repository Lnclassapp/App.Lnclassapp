# Plan d'exécution — Les 9 leçons de SVT de 1ère A1 et A2

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — 9 leçons de 1ère A1, déclinées en 1ère A2   (3 sous-agents au plus en même temps ; auteurs Sonnet, relecteurs Opus)
  ↓ chaque leçon : rédaction → contrôles → relecture indépendante (Opus) → corrections → contrôles → déclinaison A2
Clôture — README des contenus, journaux, PR (une seule PR)
```

Pas de Lot 0 : aucun contrat, aucune table, aucune route.

---

## Lot A — Les 9 leçons de 1ère A1 et A2

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/1ere-a1/svt/*.json` et `1ere-a2/svt/*.json` (18, dont 6 v1 remplacés) · dossier du chantier · `docs/contenus/README.md` (section 1ère) · journal du programme
- **Dépend de**    : —
- **Test associé** : `ruby script/contenus/valider.rb` ; contrôle de l'entraînement (`NotionPractice.errors_for`, règles du test 3e) ; relecture indépendante (Opus) ; `bin/ci-quiet` (niveau doc).
- **Done quand**   : les 18 fichiers passent les deux contrôles sans erreur ni avertissement après relecture, et chaque fichier A2 ne diffère du A1 que par `series_name`.

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `docs/contenus/lecons-traitees/1ere-a1/svt/*`, `1ere-a2/svt/*` | Lot A (un rédacteur par fichier A1) |
| README des contenus, journal du programme | Lot A, à la clôture |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait
- [x] `prd.md` : critères d'acceptation en Gherkin
- [x] ADR / UDR / Lot 0 — sans objet
- [ ] Contrôles et `bin/ci-quiet` au vert
- [ ] PR unique vers `Develop`
- [ ] `journal.md` clos
