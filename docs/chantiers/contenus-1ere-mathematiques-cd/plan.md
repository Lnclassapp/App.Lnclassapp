# Plan d'exécution — Les 10 premières leçons de Mathématiques de 1ère C et de 1ère D

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot R1 — leçons communes à C et D (7 leçons, 14 fichiers)     ┐ un rédacteur Sonnet par leçon, 3 en parallèle au plus
Lot R2 — leçons propres à C ou D (6 leçons, 6 fichiers)       ┘
  ↓
Lot V — relecture Opus (un relecteur par leçon), corrections, contrôles, README, journaux
```

Pas de Lot 0 : aucun contrat, aucune table, aucune route.

## Lot R1 — Leçons communes à C et D

- **Couche**       : contenus
- **Fichiers**     : `1ere-c/` et `1ere-d/mathematiques/` : `angles-orientes-et-trigonometrie`, `generalites-sur-les-fonctions`, `barycentre`, `limites-et-continuite`, `denombrement`, `extension-de-la-notion-de-limite`, `derivation`
- **Dépend de**    : —
- **Test associé** : `valider.rb` et contrôle de l'entraînement sans erreur ni avertissement.
- **Done quand**   : 14 fichiers v3 aux intitulés exacts, versions C et D aux mêmes notions, problèmes 3 et 4 au niveau de la série.

## Lot R2 — Leçons propres à une série

- **Couche**       : contenus
- **Fichiers**     : C : `equations-et-inequations-dans`, `composees-de-transformations-du-plan`, `orthogonalite-de-l-espace` ; D : `equations-et-inequations-du-second-degre-dans`, `etude-et-representation-graphique-d-une-fonction`, `probabilite`
- **Dépend de**    : —
- **Test associé** : idem R1.
- **Done quand**   : 6 fichiers v3.

## Lot V — Relecture et livraison

- **Couche**       : contenus
- **Fichiers**     : les 20 leçons · `docs/contenus/README.md` (section 1ère) · journaux du chantier et du programme
- **Dépend de**    : R1, R2
- **Test associé** : relecture indépendante (Opus) qui refait chaque calcul ; contrôles relancés après correction ; `bin/ci-quiet` (verificateur-ci).
- **Done quand**   : 20 fichiers sans erreur ni avertissement, points enseignant au journal du programme.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `lecons-traitees/1ere-{c,d}/mathematiques/*` | R1, R2 (un rédacteur par leçon), puis V |
| `docs/contenus/README.md`, journaux | V |

## Portes de sortie

- [x] `memo.md` complet, `Hors périmètre` non vide
- [x] Grill fait
- [x] `prd.md` : critères en Gherkin
- [x] ADR / UDR / Lot 0 / en-tête HITL — sans objet
- [ ] Un rôle distinct a relu chaque leçon
- [ ] `bin/ci-quiet` au vert
- [ ] PR unique vers `Develop`
- [ ] `journal.md` clos
