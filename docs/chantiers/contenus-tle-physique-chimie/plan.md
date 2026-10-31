# Plan d'exécution — Les leçons de Physique-Chimie de Tle C et D

> Format des lots : [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot). Aucun code : pas de Lot 0.

## Graphe

```
Lot R1 — 6 leçons (rédacteurs en parallèle)   ┐ en parallèle
Lot R2 — 6 leçons                              ┘
  ↓
Lot V — relecture indépendante, corrections, déclinaison par série, README, journaux
```

| # | Leçon | Rang C | Rang D | Décor dominant | Thème | Lot |
|---|---|---|---|---|---|---|
| 1 | Cinématique du point | 1 | 1 | route et gbaka | blue | R1 |
| 2 | Les alcools | 2 | 2 | vin de palme, distillation | teal | R1 |
| 3 | Mouvement du centre d'inertie d'un solide | 3 | 3 | port d'Abidjan | burgundy | R1 |
| 4 | Composés carbonylés : aldéhydes et cétones | 4 | 4 | laboratoire, parfums | blue | R1 |
| 5 | Interaction gravitationnelle | 5 | — | satellites, télévision | teal | R1 |
| 6 | Mouvements dans les champs g⃗ et E⃗ uniformes | 6 | 6 | football, oscilloscope | burgundy | R1 |
| 7 | Acides carboxyliques et dérivés | 7 | 7 | vinaigre, marché | blue | R2 |
| 8 | Fabrication d'un savon | 8 | 9 | savonnerie, karité | teal | R2 |
| 9 | Oscillations mécaniques libres | 9 | 8 | atelier, amortisseurs | burgundy | R2 |
| 10 | Champ magnétique | 10 | — | atelier d'électricité | blue | R2 |
| 11 | Les amines | — | 5 | poisson, colorants | teal | R2 |
| 12 | Les acides α-aminés | — | 10 | arachide, protéines | burgundy | R2 |

## Lot R1 — Leçons 1 à 6

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/tle-c/physique-chimie/` (leçons 1 à 6) · chantier
- **Dépend de**    : —
- **Test associé** : `ruby script/contenus/valider.rb` sans erreur ni avertissement ; contrôle de l'entraînement (mêmes assertions que les tests « Je m'entraîne » de 3e).
- **Done quand**   : 6 fichiers v3 qui passent.

## Lot R2 — Leçons 7 à 12

- **Couche**       : contenus
- **Fichiers**     : `tle-c/physique-chimie/` (7 à 10) · `tle-d/physique-chimie/` (11, 12)
- **Dépend de**    : —
- **Test associé** : idem R1.
- **Done quand**   : 6 fichiers v3 qui passent.

## Lot V — Validation, déclinaison, rangement

- **Couche**       : contenus · documentation
- **Fichiers**     : les 20 fichiers · `docs/contenus/README.md` · journaux du chantier et du programme
- **Dépend de**    : R1, R2
- **Test associé** : relecture par un sous-agent distinct de l'auteur, qui refait chaque calcul ; contrôles relancés.
- **Done quand**   : 20 fichiers qui passent ; points enseignant au journal du programme.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `tle-c/physique-chimie/*` leçons 1–6 | R1 puis V |
| `tle-c/physique-chimie/*` 7–10, `tle-d/physique-chimie/{les-amines,les-acides-a-amines}.json` | R2 puis V |
| `tle-d/physique-chimie/*` déclinaisons, README, journaux | V |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait
- [x] `prd.md` : critères en Gherkin
- [x] ADR : sans objet (aucun contrat nouveau)
- [x] UDR : sans objet (aucune vue)
- [x] `plan.md` : 4 champs par lot, collision remplie
- [ ] 20 fichiers qui passent `valider.rb` sans avertissement
- [ ] Relecture indépendante faite, corrections reportées
- [ ] PR prête vers `Develop` avec la ligne de preuve `bin/ci-quiet`
- [ ] `journal.md` clos
