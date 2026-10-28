# Journal — Fiches en blocs

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-13 | Grill repris avec l'algorithme en 5 étapes : une fiche de révision par leçon, 9 blocs, réponse numérique et indice, exercices à correction affichable retirés avec le verrou enseignant, figure fixe intégrée, bascule leçon par leçon | Les maquettes sont des fiches de cours ; seul ce qui sert à réviser est gardé, et le premier retour d'élèves n'attend plus les 213 leçons | À voir au PRD (format d'import v2, remplacement d'une leçon) |
| 2026-10-27 | Lot 0 : format et contrat gelés (voir « Lot 0 » ci-dessous) ; `format` = `lnclass.course-sheet` | Le nom suit celui du schéma, comme `lnclass.course-tree` | Oui, à aligner dans l'ADR à la clôture |
| 2026-10-28 | Lot F (Texte argumentatif, phase 2, repris de Touré par l'orchestrateur) : contrat du kind `argument_highlighter` et choix de contenu (voir « Lot F » ci-dessous) | Le contrat gelé du Lot 0 (`params` : 12 clés, chaînes de 200 caractères) ne porte le texte à analyser qu'en morceaux balisés | Non (contrat de kind, dans le journal) |

### Lot 0 — Socle (2026-10-27)

**Livré** : table `course_sheets`, `Orm::CourseSheet`, `CourseSheet` et `SheetDocument` (domaine, Ruby pur), port gelé `CourseSheetRepositoryPort`, schéma `lnclass.course-sheet.v1.json`, route `GET courses/:course_slug/fiche`, locale, aiguillage `_block`, `course_sheet.css` et polices OFL, exception bornée de `design_tokens_test`.

**Contrat gelé pour les lots A à G**
- Format d'import : `{ format: "lnclass.course-sheet", version: 1, course, theme, pages, glossary }`. Le document stocké est `{ pages, glossary }` (sans l'enveloppe). La chaîne `format` suit le nom du schéma, comme `lnclass.course-tree` ; l'ADR écrit `lnclass.course-sheet` (tiret bas) : à aligner à la clôture.
- Blocs : `paragraph{text}`, `simple{text}`, `box{label, tone?, paragraphs[]}`, `steps{label?, items[]}`, `table{caption?, headers[], rows[][]}`, `figure{kind, caption?, params?}` (kind : `lens_diagrams`), `media{kind, caption?, params?}` (kind : `thales_figure`, `lens_simulator`, `lens_construction`, `argument_highlighter`), `exercise{title, prompt, fields[], hint?, correction?}`, `practice{kind: thales_ratio|bank, title, bank[]?}`, `writing{title, prompt, connectors?, min_words?, min_paragraphs?}`. Champ d'exercice : `{id, input: numeric|choice, label, answer, options[], frozen?}`. Page : `{header?: {eyebrow_left, eyebrow_right, title, intro}, sections[]}`.
- `_block` reçoit le local `block` (Hash à clés chaînes) ; `figure` et `media` rendent `kinds/_<kind>` directement (pas de `blocks/_figure` ni `blocks/_media`), les autres types `blocks/_<type>`. Tous les partials reçoivent `block`.
- `params` d'une figure : au plus 12 clés `[a-z][a-z0-9_]*`, valeurs booléennes, nombres (|x| ≤ 1 000 000) ou chaînes courtes. Chaque lot de kind borne les siens et peut resserrer le schéma en le remontant.
- CSS : `app/assets/stylesheets/course_sheet.css`, servi par Propshaft tel quel (aucun changement de `package.json`), à charger par `stylesheet_link_tag "course_sheet"` dans la vue de la fiche (Lot B). Il importe `course_sheet/thales_figure.css`, `lens.css`, `argument.css` : ces fichiers sont créés par les lots D, E, F (un `@import` non résolu est inoffensif d'ici là).

**Écarts et points ouverts**
- Aucune leçon n'existe en fixture : `test/fixtures/course_sheets.yml` est vide (comme les autres fixtures du dépôt) ; le document de référence est `test/fixtures/files/course_sheets/reference.json`, et `create_course_sheet` (`test/support/factories/course_sheet.rb`) l'écrit sur une leçon créée à la demande.
- `PortContractsTest` (un adaptateur par port) reste rouge jusqu'au Lot A, qui apporte `Repositories::Catalog::CourseSheetRepository`.
- Clé de lexique définie deux fois : un Hash ne peut pas la porter ; le Lot A doit la détecter à la lecture du JSON.
- Les valeurs `--sheet-note*` (teintes du lexique et des explications simples) des thèmes `teal` et `burgundy` sont relevées sur les maquettes Lentilles et Texte argumentatif ; les lots E et F les vérifient au pixel.

### Lot F — Fiche Texte argumentatif (2026-10-28)

**Livré** : `kinds/_argument_highlighter`, `blocks/_writing`, coquilles `argument_highlighter_controller.js` et `writing_controller.js`, logique dans `lib/course_sheet/argument_highlighter.js` et `writing.js` (chargées par `import()`), `course_sheet/argument.css`, `db/seeds/data/course_sheets/texte-argumentatif.json` (thème `burgundy`, leçon `le-texte-argumentatif`), libellés dans `config/locales/catalog/course_sheets_argument.fr.yml` (fichier à part, comme Thalès).

**Contrat du kind `argument_highlighter`** (dans les `params` gelés, rien de plus) : `text_1` … `text_12`, lus dans l'ordre du numéro, chacun une chaîne de 200 caractères au plus ; un passage s'écrit `{T}…{/T}` (T thèse, R thèse adverse, A argument, E exemple, C connecteur), le reste est du texte brut ; un morceau est séparé du suivant par une espace. Les cinq catégories, leurs noms et leurs explications sont des libellés de locale, leurs couleurs du CSS : le fichier ne porte que le texte. `caption` : la mention des œuvres citées. Sans passage lisible, un message remplace la figure. Tout est échappé (aucun HTML, aucun `style`).

**Teintes `--sheet-note*` du thème `burgundy`** : vérifiées sur la maquette, conformes, rien à corriger (note `oklch(0.5 0.1 70)` : bascule, soulignement des mots, bulle, bordure de la barre à 40 % ; note-deep `0.45 0.1 70` : « En clair », titre de la bulle, Indice ; note-bg `0.95 0.03 80`). Ce que la maquette fait de plus que ces jetons (règles et numéros en ocre `0.55 0.12 75`, h1 58 px, h2 28 px, Seyès `110 110 190`, filets `#d8cfc8`, encadrés bordeaux / bleu / ocre) est dans `argument.css`, limité au thème `burgundy`.

**Budget du JS commun** : 60,33 Ko avant, 60,60 Ko après (deux coquilles, +0,27 Ko), plafond 61 Ko inchangé. Marge restante : 0,40 Ko ; le Lot E ajoute deux coquilles du même poids.

**Écarts avec la maquette, dus au contrat gelé** (à voir avec le porteur) :
- Les termes de « À retenir » n'ont pas leur pastille colorée (un encadré ne porte que des paragraphes) : ils sont en gras.
- « Convaincre » et « Persuader » sont deux encadrés l'un sous l'autre, pas deux colonnes ; les exercices 1 à 3 sont l'un sous l'autre, pas en trois colonnes ; l'exemple rédigé n'est pas surligné par phrase.
- Un exercice a au moins un champ : les exercices 1 à 3 (réponse libre dans la maquette) sont des choix, leur correction est celle de la maquette. Le générateur de connecteurs, à choix dans la maquette, est une banque numérique (« tape le numéro de la bonne proposition ») : le type `bank` ne juge que des nombres.
- Le texte d'invite de la zone de rédaction est générique (le bloc `writing` n'a pas de champ pour un texte d'invite) ; aucun lien dans les sources (aucune URL acceptée dans le document).
- Les logiques sont chargées à la demande : un geste avant leur branchement est perdu ; `data-ready` sur la figure et sur la rédaction le dit au test.

**Corrections des revues** : (1) le contrat de `text_n` est tenu à l'import (`SheetDocument`, propre à ce kind) : une fois les passages `{T|R|A|E|C}…{/X}` retirés, toute accolade restante, ou un `text_n` qui n'est pas une chaîne, refuse le fichier. (2) Retour arrière Turbo : le texte d'attente vient de la vue (`data-idle`), les deux coquilles se remettent à zéro sur `turbo:before-cache` (`reset` : `destroy()` rend le DOM comme à la livraison, la saisie de la rédaction est vidée, `data-ready` retiré), `data-ready` n'est posé qu'une fois la logique importée et construite. (3) Rédaction : « au moins 3 connecteurs » n'apparaît que si la liste en compte 3 ou plus ; la liste est lue comme le texte de l'élève (minuscules, `’` et `` ` `` en `'`) ; une locution qui finit par une apostrophe (« parce qu' ») se reconnaît devant une lettre. (4) Coquilles : `try/catch` seulement autour de `import()` ; une erreur du constructeur remonte dans la console (rejet non intercepté).

**Fichiers hors fiche touchés** : `app/assets/stylesheets/course_sheet.css` (la ligne `@import`, collision attendue avec le Lot E), `test/design/design_tokens_test.rb` (la liste des feuilles importées, même collision), `test/integration/catalog/course_sheet_seeds_test.rb` (« sur 1 » devient le nombre exact de fichiers de `db/seeds/data/course_sheets/` : une seconde fiche est semée).

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
