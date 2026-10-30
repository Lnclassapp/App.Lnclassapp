# Plan d'exécution — Les 10 premières leçons de Physique-Chimie de 3ème

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Contrat des sortes : ADR-XXXX-figures-des-matieres-de-3eme §4.2 ; dessin : UDR-XXXX-figures-des-matieres-de-3eme §3.

## Graphe

```
Lot O — module optics      ┐
Lot M — module molecule    ├ en parallèle, tout de suite (fichiers propres à la vague)
Lot R — 10 leçons          ┘ (un rédacteur par leçon, 6 en parallèle au plus)
  ↓  fusion de la vague 2 (HG) dans Develop, puis fusion de Develop ici
Lot D — domaine, liste blanche, consigne
  ↓  fusion de la vague 3 (SVT) dans Develop, puis fusion de Develop ici
Lot P — planches de PC
  ↓
Lot V — contrôle des 10 leçons, relecture IA indépendante (Opus, refait chaque calcul), corrections
```

Pas de Lot 0 : les ports et le contrat sont ceux de l'ADR accepté. **Coordination** : tant que la PR de la vague 2 n'est pas fusionnée, aucun lot ne touche `figure_kinds.rb`, `figure.rb`, `figure_catalogs.rb`, `figure_controller.js`, `figures_structure_test.rb`, `prompt-redaction.md`.

### Contrats de rendu (Lots O et M)

Chaque module exporte `create(canvas, values, { announce, controls })` et rend `{ redraw(values), interactive: false, destroy() }`, comme `coordinate_plane.js` ; il revérifie bornes et listes fermées et lève une `Error` sinon (le contrôleur passe en `error`).

- **`optics`** (viewBox 640×320). Mode `lens` : OA = −`object_distance`, f' = +`focal` (convergente) ou −`focal` (divergente), 1/OA' = 1/f' + 1/OA, γ = OA'/OA ; si |1/f' + 1/OA| < 1e-9, image à l'infini. Échelle commune choisie pour que objet, foyers et image (bornée au cadre) tiennent. Dessin : axe `grid` en tirets, lentille (doubles flèches vers l'extérieur / l'intérieur), F et F' étiquetés, O, objet AB `primary`, 3 rayons particuliers `accent` (par le centre ; parallèle puis par F' ; par F puis parallèle), prolongements virtuels en tirets, image A'B' `success` (tirets si virtuelle). Mesures en texte SVG sous le dessin : « OA' = 6 cm », « γ = −0,5 », nature (« réelle, renversée, réduite » / « virtuelle, droite, agrandie » / « image à l'infini »). `announce` reçoit la même ligne au `redraw`. Attributs de test : `data-ray` (3), `data-focus` (F, F'), `data-image`, `data-virtual` sur l'image virtuelle, `data-measure`. Mode `eye` : œil réduit (cristallin = lentille, rétine = arc), faisceau parallèle venant de l'infini ; point de convergence avant (`myopia`), sur (`none`), après (`hyperopia`) la rétine ; avec `correction` (lentille devant l'œil) la convergence se déplace : divergente recule, convergente avance (myope corrigé par divergente → sur la rétine ; hypermétrope par convergente → sur la rétine ; mauvaise correction → plus loin de la rétine). Attribut `data-convergence` = `before` | `on` | `after`, texte de mesure (« L'image se forme avant la rétine : œil myope »).
- **`molecule`** (viewBox 640×320). Mode `alkane` : `carbons` 1..10, nom (méthane, éthane, propane, butane, pentane, hexane, heptane, octane, nonane, décane), formule brute CₙH₂ₙ₊₂ en chiffres indices Unicode. `developed` : chaîne horizontale de C, 3 H par C terminal, 2 par C intérieur (méthane : 4 H en croix), liaisons simples ; `semi_developed` : texte CH₃–CH₂–…–CH₃ (méthane CH₄) ; `raw` : formule brute en grand. Nom et formule brute toujours écrits sous le dessin et annoncés au `redraw`. Mode `custom` : atomes sur une grille 13×13 (x, y 0..12), symbole, liaisons 1 à 3 traits parallèles ; refuse élément hors liste, identifiant dupliqué, liaison vers un atome absent, valence dépassée. Attributs de test : `data-atom` (= élément), `data-bond` (= ordre), `data-name`, `data-formula`.

### Planches de PC (Lot P) — liste fermée des parties

| Planche | Parties |
|---|---|
| `dynamometer` | `ring`, `tube`, `spring`, `scale`, `pointer`, `hook`, `load` |
| `electrolyser` | `generator`, `vessel`, `electrolyte`, `anode`, `cathode`, `oxygen_tube`, `hydrogen_tube`, `oxygen`, `hydrogen` |
| `eudiometer` | `tube`, `scale`, `electrodes`, `spark`, `gas_mixture`, `water`, `trough` |

Libellés français dans le module de dessin (anneau, tube, ressort, graduation, index, crochet, corps suspendu ; générateur, cuve, électrolyte (eau + soude), anode, cathode, tube de dioxygène, tube de dihydrogène, dioxygène, dihydrogène ; tube gradué, graduation, électrodes, étincelle, mélange gazeux, eau, cuve à eau). Le volume de dihydrogène est le double de celui de dioxygène sur le dessin de l'électrolyseur.

---

## Lot O — Tracé optique

- **Couche**       : UI (module de rendu)
- **Fichiers**     : `app/javascript/lib/figures/optics.js` · `test/system/catalog/figure_optics_test.rb`
- **Dépend de**    : —
- **Test associé** : scénarios « Tracé optique » du PRD (convergente 4/12/2 → OA' = 6, γ = −0,5 ; curseur à 2 → virtuelle, OA' = −4, γ = 2, tirets, annonce ; foyer → infini ; divergente → OA' = −3, γ = 0,25 ; œil myope avant / corrigé sur ; hypermétrope après / corrigé sur ; valeur hors bornes → `error`).
- **Done quand**   : le test passe avec le patch local temporaire de la liste blanche (voir consignes) ; il sera vert sans patch après le Lot D.

## Lot M — Molécule

- **Couche**       : UI (module de rendu)
- **Fichiers**     : `app/javascript/lib/figures/molecule.js` · `test/system/catalog/figure_molecule_test.rb`
- **Dépend de**    : —
- **Test associé** : scénarios « Molécules » du PRD côté rendu (propane développé : 3 C, 8 H, 10 liaisons, « propane », C₃H₈ ; curseur 1 → méthane CH₄, 10 → décane C₁₀H₂₂, annonce ; semi-développée, brute ; eau custom ; liaison double dessinée en 2 traits ; valence dépassée → `error`).
- **Done quand**   : idem Lot O.

Consignes O et M : tant que le Lot D n'est pas fait, `Entities::Catalog::Figure` et le contrôleur refusent la sorte. Pour vérifier, patch local **non commité** : ajouter la sorte à `KINDS`/`RANGE_PARAMS` du contrôleur et à `FigureKinds` (copie des paramètres de l'ADR), lancer le test, puis `git checkout --` ces fichiers avant le commit. Le commit ne contient que les deux fichiers du lot. En-tête HITL de 3 lignes. Aucune couleur en dur, aucun `innerHTML`, aucune URL (règles de `figures_structure_test.rb`).

## Lot R — Les 10 leçons

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/3eme/physique-chimie/*.json` (10, dont les 4 v1 remplacés)
- **Dépend de**    : — (formes des figures : ADR §4.2 et contrats ci-dessus)
- **Test associé** : `ruby script/contenus/valider.rb` (sans erreur hors « sorte inconnue » pour `optics`, `molecule`, `plate`, `stat_chart` `line` avant le Lot D) ; relecture au Lot V.
- **Done quand**   : 10 fichiers v3 aux intitulés exacts de la progression ; figures selon l'inventaire ADR §4.1 ; g = 10 N/kg sauf mention ; unités SI ; aucun `*` ni `**` dans une question.

## Lot D — Domaine, liste blanche, consigne

- **Couche**       : domaine · UI · contenus
- **Fichiers**     : `app/domain/entities/catalog/figure_kinds.rb` · `app/domain/entities/catalog/figure.rb` · `app/javascript/controllers/figure_controller.js` · `test/javascript/figures_structure_test.rb` · tests de domaine de `Figure`/`FigureKinds` · test de parité import ↔ `valider.rb` · `docs/contenus/prompt-redaction.md`
- **Dépend de**    : fusion de la vague 2 ; Lots O et M
- **Test associé** : chaque incohérence `optics` et `molecule` du PRD rend `figure_invalid` au même chemin à l'import et au script ; liste blanche et réglables égaux à `FigureKinds` ; tests système O et M verts sans patch.
- **Done quand**   : 100 % lignes et branches sur le code Ruby touché ; sections `optics` et `molecule` dans la consigne.
- **Reprises**     : (4) le contrôleur annonce au relâchement la dernière mesure dite par la figure, à défaut le libellé du curseur, et `molecule.js` perd son `setTimeout` de 350 ms ; tests système O et M adaptés. (5) `optics.js` à 390 px : A et A' étiquetés, marge de 70 à gauche et à droite (`SPAN_X` 250).

## Lot P — Planches de PC

- **Couche**       : domaine · UI
- **Fichiers**     : liste fermée des planches (`figure_catalogs.rb`) · `app/javascript/lib/figures/plates/{dynamometer,electrolyser,eudiometer}.js` · tests de parité et système des planches · section planches de PC de la consigne
- **Dépend de**    : fusion de la vague 3 (module `plate` et sa forme de module de planche)
- **Test associé** : scénarios « Planches de Physique-Chimie » du PRD.
- **Done quand**   : parties identiques domaine ↔ module ; les 3 planches `ready` ; partie inconnue refusée des deux côtés.

## Lot V — Validation des leçons

- **Couche**       : contenus
- **Fichiers**     : les 10 leçons
- **Dépend de**    : Lots R, D, P
- **Test associé** : `valider.rb` sans erreur ni avertissement ; relecture IA indépendante (Opus) qui refait chaque calcul ; contrôle relancé après corrections.
- **Done quand**   : les 10 fichiers passent, captures des figures à 390 px et sur ordinateur envoyées au porteur.

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `lib/figures/optics.js`, `test/system/catalog/figure_optics_test.rb` | Lot O |
| `lib/figures/molecule.js`, `test/system/catalog/figure_molecule_test.rb` | Lot M |
| `docs/contenus/lecons-traitees/3eme/physique-chimie/*` | Lot R puis Lot V |
| `figure_kinds.rb`, `figure.rb`, `figure_controller.js`, `figures_structure_test.rb`, `prompt-redaction.md` | Lot D (après la vague 2) |
| `figure_catalogs.rb`, `lib/figures/plates/{dynamometer,electrolyser,eudiometer}.js` | Lot P (après la vague 3) |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît (ADR-XXXX-figures-des-matieres-de-3eme, accepté)
- [x] UDR écrite pour **chaque** vue créée ou modifiée (UDR-XXXX-figures-des-matieres-de-3eme, acceptée ; aucune vue nouvelle)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle (sans objet : contrat de l'ADR)
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [x] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [x] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)
