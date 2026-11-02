# Plan d'exécution — Les 7 leçons de Français de Terminale (A1, A2, C, D)

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — 7 leçons écrites en Tle A1, déclinées en A2, C, D   (3 sous-agents au plus en même temps)
  ↓ chaque leçon : rédaction → contrôles → relecture indépendante → corrections → contrôles → déclinaison
Clôture — README des contenus, journaux, PR (dans le même commit, une seule PR)
```

Pas de Lot 0 : aucun contrat, aucune table, aucune route.

---

## Lot A — Les 7 leçons de Français de Tle

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/tle-{a1,a2,c,d}/francais/*.json` (26, dont 12 v1 remplacés) · dossier du chantier · `docs/contenus/README.md` (section Tle) · journal du programme
- **Dépend de**    : —
- **Test associé** : `ruby script/contenus/valider.rb` ; contrôle de l'entraînement (`NotionPractice.errors_for`, règles du test 3e, par `bin/rails runner`) ; relecture indépendante (Opus) ; `bin/ci-quiet` (niveau doc).
- **Done quand**   : les 26 fichiers passent les deux contrôles sans erreur ni avertissement après relecture, et chaque fichier hors A1 ne diffère de celui de A1 que par `series_name` et le rang du `subtitle`.

| Leçon | Fichier | A1 | A2 | C | D | Thème |
|---|---|---:|---:|---:|---:|---|
| Œuvre narrative | `oeuvre-narrative.json` | 1 | 1 | 1 | 1 | blue |
| Préparation à l'oral du Baccalauréat | `preparation-a-l-oral-du-baccalaureat.json` | 2 | 2 | 3 | 3 | teal |
| La dissertation littéraire | `la-dissertation-litteraire.json` | 3 | 3 | 2 | 2 | burgundy |
| Le commentaire composé | `le-commentaire-compose.json` | 4 | 4 | 4 | 4 | blue |
| Groupement de textes théâtraux | `groupement-de-textes-theatraux.json` | 5 | 5 | 5 | 5 | teal |
| Œuvre poétique | `oeuvre-poetique.json` | 6 | 6 | — | — | burgundy |
| Résumé du texte argumentatif | `resume-du-texte-argumentatif.json` | 7 | 7 | 6 | 6 | blue |

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `docs/contenus/lecons-traitees/tle-*/francais/*` | Lot A (un rédacteur par fichier A1) |
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
