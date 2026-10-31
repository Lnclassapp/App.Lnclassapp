# Plan d'exécution — Les 7 leçons de SVT de Terminale A1 et A2

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — 7 leçons de Tle A1, déclinées en Tle A2   (3 sous-agents au plus en même temps)
  ↓ chaque leçon : rédaction → contrôles → relecture indépendante → corrections → contrôles → déclinaison A2
Clôture — README des contenus, journaux, PR (dans le même commit, une seule PR)
```

Pas de Lot 0 : aucun contrat, aucune table, aucune route.

---

## Lot A — Les 7 leçons de Tle A1 et A2

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/tle-a1/svt/*.json` et `tle-a2/svt/*.json` (14, dont 6 v1 remplacés) · dossier du chantier · `docs/contenus/README.md` (section Tle) · journal du programme
- **Dépend de**    : —
- **Test associé** : `ruby script/contenus/valider.rb` ; contrôle de l'entraînement (`NotionPractice.errors_for`, règles du test 3e) ; relecture indépendante (Opus) ; `bin/ci-quiet` (niveau doc).
- **Done quand**   : les 14 fichiers passent les deux contrôles sans erreur ni avertissement après relecture, et chaque fichier A2 ne diffère du A1 que par `series_name`.

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `docs/contenus/lecons-traitees/tle-a1/svt/*`, `tle-a2/svt/*` | Lot A (un rédacteur par fichier A1) |
| README des contenus, journal du programme | Lot A, à la clôture |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît — sans objet
- [x] UDR écrite pour **chaque** vue créée ou modifiée — sans objet
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle — sans objet
- [x] Chaque critère d'acceptation a son test (contrôles, relecture)
- [x] En-tête HITL sur chaque fichier créé dans `app/` — sans objet
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)
