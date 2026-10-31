# Plan d'exécution — Les 10 premières leçons de Mathématiques de Tle C et de Tle D

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot R1 — 6 leçons communes (12 fichiers) ┐ un rédacteur par leçon, 6 en parallèle au plus
Lot R2 — 8 leçons propres à C ou D       ┘
  ↓
Lot V — relecture indépendante (un relecteur par leçon, distinct de l'auteur, refait chaque calcul), corrections, contrôles, README, journaux
```

Pas de Lot 0 : aucun contrat, aucune table, aucune route.

## Lot R1 — Leçons communes à C et D

- **Couche**       : contenus
- **Fichiers**     : `tle-c/mathematiques/` et `tle-d/mathematiques/` : `limites-et-continuite`, `derivabilite-et-etude-de-fonctions`, `primitives`, `fonctions-logarithmes`, `nombres-complexes` ; `tle-c/…/fonctions-exponentielles-et-fonctions-puissances`, `tle-d/…/fonctions-exponentielles-et-puissances`
- **Dépend de**    : —
- **Test associé** : `valider.rb` et contrôle de l'entraînement sans erreur ni avertissement.
- **Done quand**   : 12 fichiers v3 aux intitulés exacts, versions C et D aux mêmes notions, problèmes 3 et 4 au niveau de la série.

## Lot R2 — Leçons propres à une série

- **Couche**       : contenus
- **Fichiers**     : C : `barycentre-et-lignes-de-niveaux`, `divisibilite-dans`, `geometrie-analytique-de-l-espace`, `coniques` ; D : `probabilite-conditionnelle-et-variable-aleatoire`, `suites-numeriques`, `calcul-integral`, `nombres-complexes-et-geometrie-du-plan`
- **Dépend de**    : —
- **Test associé** : idem R1.
- **Done quand**   : 8 fichiers v3.

## Lot V — Relecture et livraison

- **Couche**       : contenus
- **Fichiers**     : les 20 leçons · `docs/contenus/README.md` (section Tle) · journaux du chantier et du programme
- **Dépend de**    : R1, R2
- **Test associé** : relecture indépendante (Opus) qui refait chaque calcul ; contrôles relancés après correction.
- **Done quand**   : 20 fichiers sans erreur ni avertissement, points enseignant au journal du programme.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `lecons-traitees/tle-{c,d}/mathematiques/*` | R1, R2 (un rédacteur par leçon), puis V |
| `docs/contenus/README.md`, journaux | V |

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
- [x] Un rôle distinct a relu chaque leçon
- [x] `bin/ci-quiet` au vert
- [x] PR unique vers `Develop`
- [x] `journal.md` clos
