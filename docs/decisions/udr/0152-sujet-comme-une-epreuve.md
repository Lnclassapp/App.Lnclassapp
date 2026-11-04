# UDR-0152 : La page de lecture d'une feuille se présente comme une vraie épreuve
<!-- index
titre: Sujet lu comme une épreuve
statut: Accepté
adr-lie: —
problematique: La page de lecture d'une feuille « Prépare interros » ou « Prépare devoirs » montre le sujet dans la mise en page du cahier à remplir, pas dans celle d'une épreuve d'examen.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-04 |
| **Chantier** | `docs/chantiers/sujet-comme-une-epreuve` |
| **ADR lié** | — (ADR-0121 pour les feuilles et les sujets) |
| **Remplacé par** | — |

Amende l'UDR-0151 §3 (« Page de la feuille, lecture ») : la page, son adresse, ses refus et son bouton « Commencer » / « Continuer » ne changent pas ; seule la mise en page du sujet change. La feuille à remplir (UDR-0149 §3) ne change pas.

---

## 1. Contexte

L'élève qui ouvre une case lit le sujet dans la mise en page du cahier à remplir : encadré « À retenir », progression, propositions empilées. Ce n'est pas la feuille qu'il recevra à l'examen. Le pilote a fourni un modèle (BEPC blanc, 2 pages, 4 exercices) : cartouche, titre d'épreuve, exercices titrés avec leurs points, affirmations en tableaux, questions numérotées, mention de pied de page.

## 2. Décision

Les trois pages de lecture (feuille de la leçon, feuille dans la classe pour l'enseignant ou l'équipe, devoir reçu dans « Ma classe ») rendent le sujet en **épreuve**. Choix du pilote (2026-11-04) : le nom de la feuille dans le cartouche (pas « BEPC BLANC »), les points sans durée, des tableaux aussi sur téléphone ajustés à l'écran, un regroupement par type de question, la même épreuve pour l'élève, « Ma classe » et l'enseignant, sans « À retenir » ni « Notions mobilisées ».

## 3. Règles d'implémentation

**Où**
- Un partiel `catalog/courses/sheets/_paper.html.erb`. Ses locals sont ceux de `catalog/courses/sheets/_sheet` ; il lit `kind`, `number`, `material`, `header_left`, `header_right`, `title`, `exercises`, `sheet_id`, `mode`, `targets`, `classrooms`, `heading`, et ignore les autres (`footer`, `reset_label`, `hand_ins`, `return_to`, `subtitle`, `box_label`, `box_text`).
- `catalog/courses/sheets/_sheet` rend `_paper` avec ses locals, et rien d'autre, quand `mode` vaut `:reading`, `:teacher` ou `:team`. Les modes `:student` et `:visitor` (feuille à remplir) sont inchangés.
- Pages concernées, sans changement de leur code : `catalog/prepare_sheets/show`, `classroom/classroom_prepare_sheets/show`, `classroom/student_assigned_sheets/show`. Aucun contrôleur, aucune route ne change.
- `Queries::Catalog::PrepareSheetsQuery::Question` gagne `points` (décimal de la question, 1 par défaut). La somme d'un exercice se calcule dans la vue.

**Structure** (de haut en bas, dans `div.ps-sheet.ps-paper#<sheet_id>`, sans contrôleur `prepare-sheet`)
1. Cartouche `div.ps-header`, identique à celui de la feuille à remplir : à gauche en gras « PRÉPARE DEVOIRS » / « PRÉPARE INTERROS » ; à droite en gras la matière en capitales ; dessous `header_left` et `header_right`.
2. Bloc titre `div.ps-paper-title`, centré :
   - le titre, balise `heading` (`:h1` sur ces pages), classe `ps-paper-heading` : « ÉPREUVE DE MATHÉMATIQUES » (`catalog.courses.sheets.paper.heading`, `material:` en capitales) ;
   - `p.ps-paper-name` : « Prépare devoirs n°1 · <title> » (`numbered_title` existant, puis `title` : notion, sujet, « Toute la leçon » ou « DEVOIR DU … ») ;
   - `p.ps-paper-rubric`, en italique : « Cette épreuve comporte 2 exercices. » (`catalog.courses.sheets.paper.rubric`, `count:` ; one : « Cette épreuve comporte un exercice. »).
3. Rien d'autre avant les exercices : ni « À retenir », ni « Notions mobilisées », ni progression, ni sous-titre.
4. Chaque exercice : `section.ps-paper-exercise#sheet-exercise-<public_id>` avec `aria-labelledby="sheet-exercise-<public_id>-title"` et `data-controller="math"`.
   - Titre `h2.ps-paper-exercise-title#sheet-exercise-<public_id>-title` : `<span class="ps-paper-exercise-number">Exercice 1</span>` (gras, souligné), puis ` (6 points)` (`catalog.courses.sheets.paper.points`, `count:` = somme des `points` des questions ; décimale avec une virgule et sans zéro inutile : « 2,5 », « 6 » ; one : « (1 point) » ; rien quand l'exercice n'a pas de question). Équipe : après le titre, la mention « Brouillon » existante si l'exercice est en brouillon.
   - Énoncé : texte, blocs et figure rendus comme aujourd'hui en lecture (`sheet_text`, `statement_blocks`, figure). Dès 700 px, la figure flotte à droite de l'énoncé (largeur 40 % au plus) ; en dessous de 700 px, elle vient sous l'énoncé, pleine largeur.
   - Questions, dans l'ordre, regroupées par **suite** de questions consécutives de même genre :
     - **vrai ou faux** (`kind == :true_false`) : `p.ps-paper-instruction` « Pour chacune des affirmations ci-dessous, indique V si elle est vraie ou F si elle est fausse. », puis `table.ps-paper-table.ps-paper-table--tf` ; en-tête `th scope="col"` « N° », « Affirmation » ; une ligne par question : `th scope="row"` la lettre (« a »), `td` l'image éventuelle puis l'énoncé ;
     - **QCM** (`kind == :mcq`) : `p.ps-paper-instruction` « Pour chacune des affirmations ci-dessous, une seule réponse est exacte : trouve-la. » (si une question de la suite attend plusieurs réponses : « Pour chacune des affirmations ci-dessous, trouve la ou les réponses exactes. »), puis `table.ps-paper-table.ps-paper-table--mcq` ; en-tête « N° », « Affirmation », puis une colonne par lettre de proposition jusqu'au plus grand nombre de propositions de la suite (« A », « B », « C », « D ») ; chaque proposition (`sheet_text`) dans la colonne de sa lettre, `td` vide au-delà ; un QCM qui attend 2 ou 3 réponses ajoute, sous son énoncé et dans la même cellule, `span.ps-instruction` « Coche 2 réponses. » (clé existante `choose_count`) ;
     - **toute autre question** : `ol.ps-paper-list` (sans puces natives), un `li` par question : `b` « f. » puis l'image éventuelle, l'énoncé, et l'unité d'un calcul en fin de ligne (« …… cm ») ; les éléments d'une question à ordonner ou à relier rendus comme aujourd'hui en lecture, sans cadre ni champ ;
     - les lettres sont celles de la feuille à remplir (`question.number`) ; une suite qui reprend après une autre garde ses lettres (a, b dans un tableau, c dans la liste, d, e dans un nouveau tableau).
   - Enseignant (`mode == :teacher`) : `_teacher_bar` sous l'exercice, comme aujourd'hui (mêmes locals, mêmes bascules et mêmes limites).
5. Pied `p.ps-paper-footer`, centré, petite taille, filet au-dessus : « Sujet d'entraînement rédigé par Lnclass. Ce n'est pas un sujet officiel. » (`catalog.courses.sheets.paper.footer`).
6. Sous la feuille, pour l'élève : « Commencer … » / « Continuer … » (`.ps-start`), inchangé, rendu par la page et non par le partiel.

**Jamais sur l'épreuve** : `input`, `select`, `textarea`, `fieldset`, `form` (sauf ceux de `_teacher_bar`), « Vérifier ma réponse », « Indice » ou son texte, statut ou marque de copie, verdict, correction, « Recommencer ».

**Tokens** (`app/assets/stylesheets/prepare_sheet.css`, aucun style en ligne)
- `.ps-paper` : la feuille blanche existante (`.ps-sheet`), police des feuilles, texte `#000`.
- `.ps-paper-heading` : 22 px, gras, capitales, centré, marge basse 4 px ; `.ps-paper-name` 15 px gras ; `.ps-paper-rubric` 14 px italique.
- `.ps-paper-exercise` : marge haute 24 px ; `.ps-paper-exercise-title` 17 px, poids normal ; `.ps-paper-exercise-number` gras et souligné.
- `.ps-paper-instruction` : italique, marge 8 px 0.
- `.ps-paper-table` : `width: 100%`, `table-layout: fixed`, `border-collapse: collapse` ; chaque `th`/`td` : bordure 1 px `#000`, `padding: 6px 8px`, `vertical-align: top`, `overflow-wrap: anywhere` ; en-tête fond `#eee`, gras, centré ; colonne N° `width: 2.5em`, centrée ; colonnes de lettres de largeur égale (`width: 4.5em`) centrées ; colonne Affirmation : le reste.
- `.ps-paper-list` : `list-style: none`, `padding-left: 0`, chaque `li` marge 6 px 0.
- `.ps-paper-footer` : 12 px, centré, `border-top: 1px solid #000`, marge haute 24 px, `padding-top: 8px`.
- Sous 480 px : tableaux 13 px, `padding: 4px`, colonne N° `2em`. Le tableau de QCM devient une grille par ligne (rôles ARIA `table`, `rowgroup`, `row`, `columnheader`, `rowheader`, `cell` posés dans le HTML pour garder le tableau aux lecteurs d'écran) : le N° à gauche sur toute la hauteur, l'affirmation sur toute la largeur, puis les propositions **deux par deux**, chacune précédée de sa lettre en gras (« A. », `data-letter`) ; les en-têtes « A B C D » restent pour les lecteurs d'écran seulement ; une case sans proposition disparaît. Ajout du 2026-11-04 (challenger) : quatre colonnes de lettres à 390 px coupaient les mots (« prop|riété ») et les formules. Une formule plus large que sa case défile dans la case (`.ps-paper-choice`, `katex` en `inline-block`), jamais la page. Dans une proposition (ordinateur), un mot se coupe par un trait d'union (`hyphens: auto`), jamais au milieu.

**États**
- Succès : l'épreuve ci-dessus.
- Vide : une feuille sans exercice n'est pas rendue (inchangé) ; un exercice sans question : son titre sans points, son énoncé, rien d'autre.
- Erreur : feuille inconnue, inchangé (303 vers la page hôte, « Cette feuille n'existe plus. »).
- Chargement : page serveur, aucun.

**Accessibilité**
- Un seul `h1` par page (le titre d'épreuve), un `h2` par exercice.
- Chaque tableau a une `caption` visuellement masquée (`sr-only`) : « Exercice 1, affirmations a à e » (`catalog.courses.sheets.paper.caption`, `number:`, `first:`, `last:`).
- Formules : `data-controller="math"` sur chaque exercice.
- Aucun élément focalisable sur l'épreuve, sauf les contrôles de `_teacher_bar` et le bouton « Commencer » sous la feuille.

**Mesure de conformité** : à 390 px, `document.documentElement.scrollWidth <= 390` sur les 8 feuilles de « Propriétés de Thalès dans un triangle », sur la page de l'enseignant et sur un devoir de « Ma classe ».

## 4. Conséquences

- L'élève lit la forme de l'examen avant de s'entraîner ; la feuille à remplir reste l'outil de travail, avec ses aides.
- Interdit : une aide (indice, « À retenir », correction) sur la page de lecture.
- Le jour où un sujet porte une durée ou un titre d'examen, le cartouche les accueille sans changer le reste.
