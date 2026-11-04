# Journal — Leçons v3 en défaut d'affichage

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-02 | Branche partie d'`origin/Develop`, pas du Lot D | Les PR vont vers `Develop` sans embarquer le Lot D ; le test d'affichage est seulement copié en local pour vérifier | Non |
| 2026-11-02 | Trois lots, une PR chacun | Trois causes indépendantes, dans trois fichiers différents | Non |

## Ce qui a dérapé

- Première piste des débordements (formules chimiques en ligne, `.katex { white-space: nowrap }`) fausse : ces formules défilent déjà dans `.sheet-text`. Le MathML caché de KaTeX, autre suspect, ne joue pas non plus. Trouvé en masquant les blocs un à un jusqu'à ce que `scrollWidth` redescende.

## Ce qu'on a appris sur la codebase

### Rapport de root cause — `**` (27 fichiers)

1. Chaîne : `catalog/revision_sheets/_sheet.html.erb` → `Catalog::SheetTextHelper#sheet_text` → `inline`.
2. Cause : `app/helpers/catalog/sheet_text_helper.rb:13`, le texte est **découpé sur les formules avant** d'appliquer le gras.
   - (a) un gras qui contient une formule (« \*\*le nombre positif dont le carré est $a$\*\* ») est coupé en deux morceaux, chacun avec un `**` seul (23 fichiers) ;
   - (b) `MATH = /(\$[^$]+\$)/` ne connaît pas `$$…$$` : après une formule centrée, les `$` se décalent et le texte suivant (« Elle s'exprime en \*\*joules\*\* (J), avec $ ») est pris pour une formule, donc jamais mis en gras (5 fichiers, dont 1 aussi en (a)).
3. Trou de test : `test/helpers/catalog/sheet_text_helper_test.rb` n'a pas de cas « gras autour d'une formule » ni « `$$…$$` suivi de gras ».
4. En une phrase : le balisage en ligne est appliqué à des morceaux découpés par une reconnaissance de formules incomplète.

### Rapport de root cause — débordements (15 fichiers)

1. Chaîne : `catalog/courses/_prepare_sheets` → `catalog/courses/sheets/_exercise` (bloc `.ps-exercise`, `app/assets/stylesheets/prepare_sheet.css`) → propositions `_choice.html.erb`, plateau `assessment/exercise_sessions/kinds/_matching.html.erb`, tableau de données de l'énoncé.
2. Cause : le cadre « une formule défile dans son propre cadre » (`rendu-lecons-v3-390`) n'a été posé que sur `.sheet-text` et `.ps-question-label` (`prepare_sheet.css:219`). Il manque sur :
   - le libellé d'une proposition `.ps-choice-label` (formule en ligne longue, `.katex { white-space: nowrap }`) : amines, alcools, acides carboxyliques, alcanes 1ère C/D ;
   - les colonnes du plateau d'association (`grid grid-cols-2` > `ul`) : alcanes et alcènes 1ère A, alcènes-alcynes 1ère C/D, composées de transformations ;
   - le tableau de données dans `.ps-exercise-main` (élément flex sans `min-width: 0`, son `overflow-x-auto` ne joue pas) : probabilité Tle A2.
3. Trou de test : `test/system/catalog/long_formulas_test.rb` ne met une formule longue que dans l'énoncé, jamais dans une proposition, une association ni un tableau.
4. En une phrase : seuls deux des conteneurs de texte du bloc exercice bornent leur contenu à la largeur de l'écran.

### Rapport de root cause — figure (1 fichier)

1. Chaîne : `figure_controller.js#connect` → `lib/figures/diagram.js` `tree` puis contrôle de hauteur.
2. Cause : contenu, `3eme/edhc/les-institutions-juridictionnelles.json`, figure `organisation-juridictions` : 5 niveaux de libellés jusqu'à 4 lignes dépassent la hauteur de 640 → `diagram : schéma trop haut` ; le contrôleur retombe sur la description seule.
3. Trou de test : `valider.rb` vérifie la forme des paramètres, pas la hauteur calculée du schéma.

## Lot A — vérification

- Rouge d'abord : `sheet_text_helper_test.rb`, 2 échecs (« \*\*le nombre positif … $a*b$\*\* » rendu tel quel ; « \*\*joules\*\* » après `$$…$$` rendu tel quel).
- Correctif : formules mises de côté (`$$…$$` puis `$…$`) avant le gras et l'italique, remises échappées après. Cas symétrique : `$` isolé, formule avec `*` intacte, piège `asterisques` (gras non fermé) toujours rouge.
- Test d'affichage (copie locale du Lot D) sur les 27 leçons : 0 `**` ; seuls restent 2 débordements (Lot B).

## Lots B et C — vérification

- Lot B (#455) : `long_formulas_test.rb`, 4 cas rouges d'abord (591, 566, 582 px ; plateau d'association sans formule rendue), puis verts. Au passage : le plateau d'association de la fiche montrait le LaTeX brut, faute de contrôleur `math`.
- Lot C (#456) : un libellé raccourci (« Tribunaux de 1re instance et de commerce »), l'arbre tient sous la hauteur ; `valider.rb` vert.

## Passage complet

- 2026-11-02, Develop + Lots A, B, C, test d'affichage du Lot D : `LECONS=tout` en 10 parts → **417 leçons, 0 défaut** (contre 41 avant).
- Les 41 rejouées avec le test révisé (c7b2d3f, attente de KaTeX, MathML exclu) : 41 vertes.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Libellés d'un schéma petits à 390 px (viewBox 640 réduit) | Rendu commun à toutes les figures, hors de ce bug | à ouvrir |
| `valider.rb` ne détecte pas un schéma trop haut ou trop large | Il faudrait reproduire en Ruby le calcul de `diagram.js` ; le test d'affichage l'attrape déjà | à ouvrir |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | — |
| **UDR produits** | — |
