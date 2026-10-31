# Plan d'exécution — Les leçons de Mathématiques de Tle A1 et de Tle A2

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot R1 — 6 leçons communes (12 fichiers)     ┐ un rédacteur par leçon, 3 en parallèle au plus
Lot R2 — 3 leçons propres à une série         ┘
  ↓
Lot V — relecture indépendante (relecteurs distincts des auteurs, calculs refaits), corrections, contrôles, README, journaux
```

Pas de Lot 0 : aucun contrat, aucune table, aucune route.

## Lot R1 — Leçons communes à A1 et A2

- **Couche**       : contenus
- **Fichiers**     : `tle-a1/mathematiques/` et `tle-a2/mathematiques/` : `etude-de-fonctions-polynomes-et-de-fonctions-rationnelles`, `fonction-logarithme-neperien`, `fonction-exponentielle-neperienne`, `statistique-a-deux-variables`, `suites-numeriques`, `systemes-d-equations-lineaires-dans-r-r`
- **Dépend de**    : —
- **Test associé** : `valider.rb` et contrôle de l'entraînement sans erreur ni avertissement.
- **Done quand**   : 12 fichiers v3 aux intitulés exacts, versions A1 et A2 aux mêmes notions, A2 sans appui sur les leçons absentes de sa progression.

## Lot R2 — Leçons propres à une série

- **Couche**       : contenus
- **Fichiers**     : A1 : `probabilite-et-variable-aleatoire`, `primitives-et-calcul-integral` ; A2 : `probabilite`
- **Dépend de**    : —
- **Test associé** : idem R1.
- **Done quand**   : 3 fichiers v3.

## Lot V — Relecture et livraison

- **Couche**       : contenus
- **Fichiers**     : les 15 leçons · `docs/contenus/README.md` (section Tle) · journaux du chantier et du programme
- **Dépend de**    : R1, R2
- **Test associé** : relecture indépendante (Opus) qui refait chaque calcul ; contrôles relancés après correction.
- **Done quand**   : 15 fichiers sans erreur ni avertissement, points enseignant au journal du programme.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `lecons-traitees/tle-{a1,a2}/mathematiques/*` | R1, R2 (un rédacteur par leçon), puis V |
| `docs/contenus/README.md`, journaux | V |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît — sans objet
- [x] UDR écrite pour **chaque** vue créée ou modifiée — sans objet
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle — sans objet
- [ ] Chaque critère d'acceptation a son test (contrôles, relecture)
- [x] En-tête HITL sur chaque fichier créé dans `app/` — sans objet
- [ ] Un rôle distinct a relu chaque leçon
- [ ] `bin/ci-quiet` au vert
- [ ] PR unique vers `Develop`
- [ ] `journal.md` clos
