# Journal — Fiches en blocs

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-13 | Grill repris avec l'algorithme en 5 étapes : une fiche de révision par leçon, 9 blocs, réponse numérique et indice, exercices à correction affichable retirés avec le verrou enseignant, figure fixe intégrée, bascule leçon par leçon | Les maquettes sont des fiches de cours ; seul ce qui sert à réviser est gardé, et le premier retour d'élèves n'attend plus les 213 leçons | À voir au PRD (format d'import v2, remplacement d'une leçon) |
| 2026-10-27 | Lot 0 : format et contrat gelés (voir « Lot 0 » ci-dessous) ; `format` = `lnclass.course-sheet` | Le nom suit celui du schéma, comme `lnclass.course-tree` | Oui, à aligner dans l'ADR à la clôture |

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
