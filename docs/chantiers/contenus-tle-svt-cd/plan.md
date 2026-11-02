# Plan d'exécution — Les 10 premières leçons de SVT de Terminale C et D

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot C — 10 leçons de Tle C (dont les 3 communes)   ┐ rédaction : 6 rédacteurs au plus en parallèle
Lot D — 7 leçons propres à Tle D + 3 déclinaisons  ┘ (les déclinaisons attendent la relecture des leçons communes)
  ↓ chaque leçon : rédaction → contrôles → relecture indépendante → corrections → contrôles
Clôture — README des contenus, journaux, PR
```

Pas de Lot 0 : aucun contrat, aucune table, aucune route.

---

## Lot C — Les 10 leçons de Tle C

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/tle-c/svt/*.json` (10, dont 3 v1 remplacés) · dossier du chantier
- **Dépend de**    : —
- **Test associé** : `ruby script/contenus/valider.rb` ; contrôle de l'entraînement (`NotionPractice.errors_for`, règles du test 3e) ; relecture indépendante (Opus).
- **Done quand**   : les 10 fichiers passent les deux contrôles sans erreur ni avertissement après relecture.

## Lot D — Les 10 leçons de Tle D

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/tle-d/svt/*.json` (10, dont 3 v1 remplacés)
- **Dépend de**    : Lot C pour les 3 déclinaisons (rangs 4, 7, 8)
- **Test associé** : idem Lot C ; les déclinaisons ne diffèrent que par `series_name` et `subtitle`.
- **Done quand**   : les 10 fichiers passent les deux contrôles sans erreur ni avertissement après relecture.

## Clôture

- **Fichiers**     : `docs/contenus/README.md` (section Tle) · `docs/chantiers/contenus-v3-tous-niveaux/journal.md` (fin de vague, points enseignant) · journal du chantier
- **Test associé** : `bin/ci-quiet` (niveau doc).

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `docs/contenus/lecons-traitees/tle-c/svt/*` | Lot C |
| `docs/contenus/lecons-traitees/tle-d/svt/*` | Lot D |
| README des contenus, journal du programme | Clôture |

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
- [x] Pureté domaine · rubocop · tests · brakeman : au vert (`bin/ci-quiet`)
- [x] PR vers `Develop`, référençant chantier + ADR + UDR (deux PR, C puis D, consigne de l'orchestrateur)
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)
