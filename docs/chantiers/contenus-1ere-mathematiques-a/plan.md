# Plan d'exécution — Les 7 leçons de Mathématiques de 1ère A

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot R1 — Équations, Dénombrement, Généralités, Dérivabilité   ┐ un rédacteur Sonnet par leçon, 2 en parallèle au plus
Lot R2 — Suites, Statistique, Systèmes                        ┘
  ↓
Lot V — relecture Opus (un relecteur par leçon), corrections, contrôles, README, journaux
```

Pas de Lot 0 : aucun contrat, aucune table, aucune route.

## Lot R1 / R2 — Rédaction

- **Couche** : contenus
- **Fichiers** : `1ere-a/mathematiques/` (R1 : `equations-et-inequations`, `denombrement`, `generalites-sur-les-fonctions`, `derivabilite-et-etude-de-fonctions` ; R2 : `suites-numeriques`, `statistique`, `systemes-d-equations-dans`) ; suppression des 6 v1 de `1ere-a1/` et `1ere-a2/`
- **Dépend de** : —
- **Test associé** : `valider.rb` et `controle-entrainement.rb` sans erreur ni avertissement.
- **Done quand** : 7 fichiers v3 aux intitulés exacts.

## Lot V — Relecture et livraison

- **Couche** : contenus
- **Fichiers** : les 7 leçons · `docs/contenus/README.md` (section 1ère) · journaux du chantier et du programme
- **Dépend de** : R1, R2
- **Test associé** : relecture Opus qui refait chaque calcul ; contrôles relancés ; `bin/ci-quiet` (verificateur-ci).
- **Done quand** : 7 fichiers sans erreur ni avertissement, points enseignant au journal du programme.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `lecons-traitees/1ere-a/mathematiques/*` | R1, R2 (un rédacteur par leçon), puis V |
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
