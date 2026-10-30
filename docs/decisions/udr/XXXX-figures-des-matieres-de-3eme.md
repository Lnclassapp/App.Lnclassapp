# UDR-XXXX : Le dessin des figures de SVT, Physique-Chimie, Histoire-Géographie et EDHC
<!-- index
titre: Dessin des figures des matières de 3ème
statut: Accepté
adr-lie: [XXXX](../adr/XXXX-figures-des-matieres-de-3eme.md)
problematique: Six sortes de figures nouvelles doivent se lire au téléphone, sans couleur et sans JavaScript, dans le cahier comme dans une page d'exercice.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-30 |
| **Chantier** | `docs/chantiers/contenus-3e-autres-matieres` |
| **ADR lié** | ADR-XXXX-figures-des-matieres-de-3eme ; complète UDR-0141 §3.3 |
| **Remplacé par** | — |

---

## 1. Contexte

L'élève de 3ème révise sur son téléphone (390 px) : une carte dont les zones ne se distinguent qu'à la teinte, un schéma dont les étiquettes se chevauchent, une frise illisible, et la figure ne sert à rien. Les cinq tokens de couleur des figures (UDR-0141 §3.3) ne suffisent pas à distinguer six catégories d'une carte.

## 2. Décision

Les six sortes nouvelles réutilisent **tel quel** le partial `catalog/figures/_figure`, le contrôleur `figure` et le helper `lib/figures/svg.js` (UDR-0141 §3.3, §3.4) : aucune vue nouvelle, aucun partial nouveau. Ce qui est décidé ici, c'est le dessin de chaque sorte : catégories par **teinte + motif**, étiquettes **numérotées** quand la place manque, mise en page **calculée** (jamais de coordonnées dans la leçon pour une frise, un schéma ou une molécule).

## 3. Règles d'implémentation

**Structure**
- Composant de référence : `app/views/catalog/figures/_figure.html.erb`, inchangé. Chaque module `app/javascript/lib/figures/<kind>.js` exporte `create(canvas, values, { announce, controls })` et rend `{ redraw(values), interactive }`, comme les modules existants.
- Un `svg` racine par figure via `root(width, height)` ; `viewBox` fixe par sorte : `timeline` 640×180, `map` 640×640 (CI, Afrique) ou 640×360 (monde), `diagram` 640×hauteur calculée (≤ 640), `optics` 640×320, `plate` 640×480, `molecule` 640×320.
- Une légende, quand la sorte en a une (`map`, `diagram`, `plate` en `numbers`), est dessinée **dans le SVG**, sous le dessin, une ligne par entrée : pastille (teinte + motif) ou numéro, puis le texte.

**Tokens**
- Couleurs : uniquement `COLOR` de `svg.js` (`ink`, `muted`, `primary`, `accent`, `success`, `grid`, `paper`). Jamais de valeur en dur (test de structure).
- **Catégories 1 à 6** (aires d'une carte, nœuds d'un schéma) : teinte et motif ensemble, dans cet ordre — 1 `primary` plein, 2 `success` plein, 3 `accent` plein, 4 `primary` hachuré à 45°, 5 `success` pointillé, 6 `muted` hachuré croisé. Pleins à `fill-opacity: 0.35` ; motifs par `<pattern>` à l'identifiant unique par figure (`fig-<key>-pat-<n>`). Aire sans catégorie : `paper`, contour `grid`.
- Traits : 1,5 unité (contours, frontières), 2,5 unités (flèches, rayons, liaisons) ; pointes de flèche par `<marker>` à l'identifiant unique par figure.
- Typographie : `label()` de `svg.js` (13 px, halo `paper`, agrandi par `--figure-text` au téléphone). Titres de légende 12 px `muted`.

**Comportement par sorte**
- `timeline` : axe horizontal gradué tous les `step`, années en chiffres (`fixed`), `unit` en suffixe de l'axe (« jour », « mois ») ; `periods` en bandes au-dessus de l'axe (catégories 1 à 6 en boucle) avec libellé centré, tronqué à la bande avec `…` ; `events` en repères verticaux sous l'axe, libellés **en quinconce** sur deux rangs pour éviter les chevauchements, puis numérotés avec renvoi dans une légende si deux libellés se chevauchent encore. Curseurs `start`/`end` : zoom de la frise.
- `map` : fond projeté (`lib/figures/maps/<base>.js`), aires selon leur catégorie, lieux en points de 5 unités avec étiquette (le `label` de la leçon sinon le nom du fond), `routes` en flèches courbes (quadratique, flèche à l'arrivée). Étiquettes qui se chevauchent : remplacées par des numéros et renvoyées dans la légende. Ligne d'attribution du fond en 10 px `muted` sous la légende quand la source l'exige.
- `diagram` : `flow` (rangées successives dans `direction`), `tree` (racine en haut ou à gauche, enfants répartis), `cycle` (nœuds sur un cercle, flèches dans le sens horaire). Nœud = rectangle arrondi (rayon 8), texte sur 3 lignes au plus (césure aux espaces), largeur ≤ 180 unités ; au-delà, texte tronqué avec `…` et texte complet dans un `<title>`. Libellé d'arête au milieu de la flèche, sur halo.
- `optics` : axe optique (`grid`, tirets), lentille (double flèche vers l'extérieur si convergente, vers l'intérieur si divergente), foyers F et F' marqués, objet AB en flèche `primary`, trois rayons particuliers `accent` (prolongements virtuels en tirets), image A'B' en flèche `success` (tirets si virtuelle). Mesures sous le dessin : OA', grandissement γ, nature de l'image (« réelle, renversée, agrandie »…), recalculées à chaque curseur et annoncées par `announce` au relâchement. Mode `eye` : œil réduit (cristallin + rétine), point de convergence avant, sur ou après la rétine selon `defect`, et la lentille correctrice devant l'œil si `correction` ≠ `none`.
- `plate` : dessin fixe de la planche, traits `ink`, parties `highlight` remplies `primary` à 0,35 ; chaque `labels[]` relie sa partie à son étiquette par un trait de rappel, étiquettes réparties à gauche et à droite du dessin. `numbering: "numbers"` : numéros à la place des noms et **pas** de légende (l'élève doit légender) ; `names` : le `text` de la leçon, sinon le nom de la partie.
- `molecule` : atomes en lettres (symbole), liaisons en traits simples, doubles ou triples, mise en page en grille (`custom`) ou calculée en chaîne horizontale (`alkane`) ; `semi_developed` écrit CH₃–CH₂–… ; `raw` écrit la formule brute (CₙH₂ₙ₊₂) en grand. Curseur `carbons` : la chaîne et le nom (« propane ») se mettent à jour et sont annoncés.

**États obligatoires** (ceux d'UDR-0141 §3.3, sans changement)
- **Vide** : sans objet (pas de figure, pas de partial).
- **Chargement** : canvas vide, `description` visible (`data-figure-state="loading"`).
- **Erreur** : sorte inconnue, module ou fond introuvable, identifiant hors liste fermée → rien n'est dessiné, `description` visible, `console.warn`, `data-figure-state="error"`.
- **Succès** : figure dessinée, `description` passée en `sr-only`, `data-figure-state="ready"`.

**Accessibilité**
- Canvas `role="img"` et `aria-label` = `description` (partial existant) ; les légendes et mesures sont aussi du texte SVG lisible.
- Aucune information portée par la seule couleur : catégories teinte + motif, image virtuelle en tirets, parties surlignées aussi nommées dans la légende.
- Curseurs : ceux d'UDR-0141 §3.3 (48 px, `aria-valuetext` avec l'unité, `aria-live="polite"` au relâchement).
- À 390 px : aucune étiquette coupée ni chevauchée (numérotation de repli), texte ≥ 13 px effectifs.

## 4. Conséquences

- Toute sorte future suit ces règles : catégories teinte + motif, numérotation de repli, mise en page calculée.
- Interdit : une couleur propre à une sorte, une image matricielle dans une figure, un texte de figure qui ne passe pas par `label()` ou `textContent`.
