# Plan d'exécution — Les leçons de Physique-Chimie de 1ère C et D

> Format des lots : [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot). Aucun code : pas de Lot 0.

## Graphe

```
Lot R1 — leçons 1 à 6    ┐
Lot R2 — leçons 7 à 12   ┘ (rédacteurs Sonnet, 3 à la fois)
  ↓
Lot V — relecture Opus par leçon, corrections, déclinaison par série, README, journaux
```

| # | Leçon (Rang C / Rang D) | Décor dominant | Thème | Lot |
|---|---|---|---|---|
| 1 | Travail et puissance (translation) (C1 / D1, intitulés différents) | chantier, grue, port d'Abidjan | blue | R1 |
| 2 | Généralités sur les composés organiques (C2 / D2) | cuisine, huile, savon | teal | R1 |
| 3 | Travail et puissance, rotation (C3 / —) | moulin à manioc, moteur de moto | burgundy | R1 |
| 4 | Hydrocarbures saturés : les alcanes (C4 / D3) | gaz butane, cuisine | blue | R1 |
| 5 | Énergie cinétique (C5 / D4) | route, gbaka, football | teal | R1 |
| 6 | Hydrocarbures insaturés : alcènes et alcynes (C6 / D5) | fruits mûrs, soudure | burgundy | R1 |
| 7 | Le benzène (C7 / D7) | laboratoire, solvants | blue | R2 |
| 8 | Énergie potentielle (C8 / —) | ressort, trampoline, barrage | teal | R2 |
| 9 | Énergie potentielle de pesanteur (— / D6) | cocotier, chute d'eau | burgundy | R2 |
| 10 | Pétrole et gaz naturels (C9 / D8) | raffinerie de Vridi, gaz de Baleine | blue | R2 |
| 11 | Énergie mécanique (C10 / D9) | toboggan, balançoire, pendule | teal | R2 |
| 12 | Quelques composés oxygénés (— / D10) | alcool, vinaigre, marché | burgundy | R2 |

Acquis communs : une leçon commune n'emploie que les leçons précédentes **des deux séries** (Énergie cinétique : pas de rotation ; Énergie mécanique : pesanteur seulement).

## Lot R1 — Leçons 1 à 6

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/1ere-c/physique-chimie/` (leçons 1 à 6)
- **Dépend de**    : —
- **Test associé** : `ruby script/contenus/valider.rb` sans erreur ni avertissement ; contrôle de l'entraînement (script de session).
- **Done quand**   : 6 fichiers v3 qui passent.

## Lot R2 — Leçons 7 à 12

- **Couche**       : contenus
- **Fichiers**     : `1ere-c/physique-chimie/` (7, 8, 10, 11) · `1ere-d/physique-chimie/` (9, 12)
- **Dépend de**    : —
- **Test associé** : idem R1.
- **Done quand**   : 6 fichiers v3 qui passent.

## Lot V — Validation, déclinaison, rangement

- **Couche**       : contenus · documentation
- **Fichiers**     : les 20 fichiers · `docs/contenus/README.md` · journaux du chantier et du programme
- **Dépend de**    : R1, R2
- **Test associé** : relecture Opus distincte de l'auteur, qui refait chaque calcul ; contrôles relancés.
- **Done quand**   : 20 fichiers qui passent ; points enseignant au journal du programme.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `1ere-c/physique-chimie/*` leçons 1–6 | R1 puis V |
| `1ere-c/physique-chimie/*` 7, 8, 10, 11 ; `1ere-d/…/{energie-potentielle-de-pesanteur,quelques-composes-oxygenes}.json` | R2 puis V |
| `1ere-d/physique-chimie/*` déclinaisons, README, journaux | V |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait
- [x] `prd.md` : critères en Gherkin
- [x] ADR : sans objet · UDR : sans objet
- [x] `plan.md` : 4 champs par lot, collision remplie
- [x] 20 fichiers qui passent `valider.rb` sans avertissement
- [x] Relecture indépendante faite, corrections reportées
- [ ] PR prête vers `Develop` avec la ligne de preuve `bin/ci-quiet`
- [ ] `journal.md` clos
