# Plan d'exécution — Les 11 leçons de Français de Première (A, C, D)

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — 11 leçons écrites (A ; la dernière en C), déclinées en C et D   (3 sous-agents au plus en même temps)
  ↓ chaque leçon : rédaction (Sonnet) → contrôles → relecture indépendante (Opus) → corrections → contrôles → déclinaison
Clôture — README des contenus, journaux, PR (même commit, une seule PR)
```

Pas de Lot 0 : aucun contrat, aucune table, aucune route.

## Lot A — Les 11 leçons de Français de 1ère

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/1ere-{a,c,d}/francais/*.json` (v1 de `1ere-a1/`, `1ere-a2/`, `1ere-c/`, `1ere-d/` remplacés) · dossier du chantier · `docs/contenus/README.md` (section 1ère) · journal du programme
- **Dépend de**    : —
- **Test associé** : `ruby script/contenus/valider.rb` ; contrôle de l'entraînement (`NotionPractice.errors_for`, règles du test 3e, par `bin/rails runner`) ; relecture indépendante (Opus) ; `bin/ci-quiet`.
- **Done quand**   : tous les fichiers passent les deux contrôles sans erreur ni avertissement après relecture, et chaque fichier hors A ne diffère de celui de A que par `series_name` et le rang du `subtitle`.

| Leçon | Fichier | A | C | D | Thème |
|---|---|---:|---:|---:|---|
| Œuvre poétique | `oeuvre-poetique.json` | 1 | 1 | 1 | blue |
| Lecture des consignes et élaboration de plan | `lecture-des-consignes-et-elaboration-de-plan.json` | 2 | 3 | 3 | teal |
| Le commentaire composé | `le-commentaire-compose.json` | 3 | 2 | 2 | burgundy |
| Le rythme dans le texte | `le-rythme-dans-le-texte.json` | 4 | 4 | 4 | blue |
| La focalisation | `la-focalisation.json` | 5 | 7 | 7 | teal |
| Groupement de textes romanesques | `groupement-de-textes-romanesques.json` | 6 | — | — | burgundy |
| Les tonalités littéraires | `les-tonalites-litteraires.json` | 7 | 5 | 5 | blue |
| Résumé du texte argumentatif | `resume-du-texte-argumentatif.json` | 8 | 6 | 6 | teal |
| L'argumentation | `l-argumentation.json` | 9 | 8 | 8 | burgundy |
| L'implicite | `l-implicite.json` | 10 | 9 | 9 | blue |
| Les valeurs des temps verbaux | `les-valeurs-des-temps-verbaux.json` | — | 10 | 10 | teal |

Total : 10 fichiers en A, 10 en C, 10 en D = 30 (la feuille de route comptait 11 leçons distinctes).

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `docs/contenus/lecons-traitees/1ere-{a,c,d}/francais/*`, `1ere-a1/francais/*`, `1ere-a2/francais/*` | Lot A |
| README des contenus, journal du programme | Lot A, à la clôture |

## Portes de sortie

- [x] `memo.md` complet, `Hors périmètre` non vide
- [x] Grill fait
- [x] `prd.md` : critères d'acceptation en Gherkin
- [x] ADR / UDR / Lot 0 : sans objet
- [x] Contrôles au vert · `bin/ci-quiet` (ligne de preuve dans la PR)
- [x] PR unique vers `Develop`
- [x] `journal.md` clos
