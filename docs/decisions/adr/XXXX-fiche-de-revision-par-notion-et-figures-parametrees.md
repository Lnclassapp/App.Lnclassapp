# ADR-XXXX : La fiche de révision est faite de notions au gabarit fixe et de figures paramétrées, importées au format v3
<!-- index
titre: Fiche de révision par notion et figures paramétrées (format v3)
statut: Accepté
problematique: Un seul support de révision par leçon, produit par l'IA pour des centaines de leçons, sans code propre à une leçon.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-29 |
| **Chantier** | `docs/chantiers/refonte-contenus-maths` |
| **Remplace** | ADR-0110 ; amende ADR-0113 §4.4, ADR-0105 (images des notions) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Fin octobre 2026, une leçon peut porter deux supports de révision : le texte de ses notions (fiches des notions essentielles, Action Text, images téléversées, ADR-0105) et une fiche de cours « cahier » de 3 pages (ADR-0110 : 10 sortes de blocs, glossaire, exercices dans la page, figures interactives). Seules 3 leçons ont une fiche cahier, et chacune de ses figures est du code écrit pour elle (`thales_figure`, `lens_simulator`…) : impossible à produire pour 213 leçons.

Les 213 leçons livrées sont au format v1, dont l'import jette les exercices (ADR-0113). Le porteur décide (memo du chantier) : tout réécrire, mathématiques d'abord, pilote 3e ; un seul support, la **fiche de révision**, au gabarit fixe par notion ; des figures interactives **génériques et paramétrées**, réutilisables dans la fiche et les exercices ; au moins 5 questions par exercice, chacune avec une correction rédigée qui suit la méthode ; base remise à zéro (aucun utilisateur actif) ; réimport refusé sauf pour une leçon encore en brouillon.

## 2. Moteurs de décision

- Production par l'IA à grande échelle : une leçon = un fichier de données, zéro code par leçon.
- Une règle pédagogique vérifiable par la machine (gabarit, nombre de questions, correction présente, exemple qui applique la méthode).
- Garder ce qui marche : la notion reste l'unité des lacunes, des lectures et de la remédiation (ADR-0101, ADR-0113).
- Moins de code : un seul format d'import, un seul support de révision.
- Budget JS commun (ADR-0114) : les figures ne pèsent rien sur les pages qui n'en ont pas.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Garder la fiche cahier (document de blocs, ADR-0110) et y ajouter les exercices | Format riche déjà rendu | 10 sortes de blocs libres : rien ne garantit la méthode ni l'exemple ; la notion disparaît du document, or lacunes et remédiation s'y rattachent |
| B — Notion au gabarit fixe, stockée sur la notion ; figures paramétrées sur la leçon | La structure porte la règle pédagogique ; la notion garde son rôle ; une table en moins | Migration et retraits importants (accepté : base vide) |
| C — Figure codée par leçon | Rendu sur mesure | Écarté par le porteur (memo) |
| D — Figures rendues côté serveur (SVG) | Pas de JS | Pas d'interaction ; deux rendus à maintenir si on ajoute l'interaction |

## 4. Décision

> **Nous importons une leçon au seul format `lnclass.course-tree` v3. Chaque notion porte une fiche au gabarit fixe (À retenir · La méthode · Un exemple corrigé · Le piège à éviter) stockée en `jsonb` sur la notion ; la leçon porte ses figures, chacune d'une sorte prise dans une liste fermée et réglée par des paramètres bornés ; une notion ou un exercice cite une figure par sa clé. La fiche de révision d'une leçon est la suite de ses notions. La fiche cahier, les images de notions, les formats v1/v2, `course-sheet` et `essentials` sont retirés.**

### 4.1 Format v3

```json
{ "format": "lnclass.course-tree", "version": 3,
  "courses": [{
    "name": "Racines carrées", "subtitle": "…", "level_name": "3ème", "material_name": "Mathématiques", "theme": "blue",
    "figures": [{ "key": "carre-aire", "kind": "geometry", "description": "Un carré de côté a et d'aire a².",
                  "params": { "…": "…" }, "controls": [{ "param": "a", "min": 1, "max": 9, "step": 0.5, "label": "côté a" }] }],
    "notions": [{
      "name": "Simplifier une racine carrée",
      "remember": "Pour a ≥ 0 et b ≥ 0 : $\\sqrt{a \\times b} = \\sqrt{a} \\times \\sqrt{b}$.",
      "method": ["Écrire le nombre sous la racine comme produit d'un carré parfait et d'un entier.", "…"],
      "example": { "statement": "Simplifier $\\sqrt{72}$.", "steps": ["$72 = 36 \\times 2$, et 36 est un carré parfait.", "…"] },
      "pitfall": "$\\sqrt{a + b} \\neq \\sqrt{a} + \\sqrt{b}$ : …",
      "figure": "carre-aire",
      "exercise": { "title": "…", "statement": "…", "exercise_type": "fixation", "figure": null, "questions": ["…≥ 5"] }
    }],
    "exercises": ["4 problèmes, même forme qu'exercise"]
  }]
}
```

Règles (toutes contrôlées à l'import, refus de la leçon entière, raison et chemin dans le rapport) :

| Élément | Règle |
|---|---|
| Version | 3 seulement ; v1 et v2 : refus du fichier, raison `format_retired` |
| `theme` | facultatif, `blue`, `teal` ou `burgundy` (habillage cahier, UDR-0137) ; absent → `blue` ; autre valeur : `schema` |
| `notions` | 1 à 12, noms uniques dans la leçon |
| `remember`, `pitfall` | texte non vide, 1 200 caractères au plus |
| `method` | 2 à 8 étapes, 300 caractères au plus chacune |
| `example.steps` | **autant d'étapes que `method`** (l'étape n applique l'étape n), raison `example_steps_mismatch` |
| `exercise` | exactement un par notion, sinon `essential_exercise_count` (absent, `null` ou liste) ; `exercises` : exactement quatre, sinon `lesson_exercise_count` |
| `questions` | **5 à 30** par exercice : moins de 5 (aucune comprise), `too_few_questions` ; plus de 30, `invalid_count` |
| `explanation` | **obligatoire pour toute question**, 20 à 2 000 caractères, espaces réduits : absente ou vide `blank`, moins de 20 `too_short`, plus de 2 000 `too_long` (étend ADR-0115, qui l'exigeait pour `written` et `notebook`) |
| `figures` | 0 à 12 ; `key` unique ; `kind` dans la liste fermée ; `params` selon le schéma de la sorte ; `description` obligatoire (150 à 600 caractères), raison `figure_invalid` avec le paramètre |
| `figure` (notion, exercice) | clé existante dans `figures` de la leçon, sinon `figure_missing` |
| Questions | types et clés d'ADR-0115, inchangés |

**Une règle, une raison, à l'import comme au script (CA-18).** Le schéma JSON ne garde que la forme et les bornes de taille des textes (raison `schema`, et alors l'adaptateur ne lit pas la leçon : le rapport ne contient que ces erreurs). Les règles de comptage et de correction ci-dessus ne sont **pas** dans le schéma : l'adaptateur les vérifie à leur raison propre, au chemin de l'élément. Codes de raison des règles du PRD : `essential_exercise_count` (CA-3), `lesson_exercise_count` (CA-4), `too_few_questions` et `invalid_count` (CA-5), `blank`, `too_short`, `too_long` (CA-6), `example_steps_mismatch` (CA-7), `figure_invalid` (CA-8, forme seule au schéma : tout le reste de la figure est jugé par `Entities::Catalog::Figure`), `figure_missing` (CA-9). `script/contenus/valider.rb` rend, pour tout autre cas, le code que l'import émet (`unknown_level`, `unknown_material`, `invalid_value` pour un type de question, un type d'exercice ou un nom de notion répété, `question_structure`, `figure_invalid` pour une clé de figure répétée…) ; ce que l'import ne contrôle pas (séries, Philosophie, EDHC, fourchettes de propositions) n'est qu'un avertissement. `test/script/contenus/parite_import_test.rb` compare, pour chaque faute, les ensembles [chemin, raison] des deux.

Texte en ligne : balisage restreint d'ADR-0110 (`$…$`, `**gras**`, `*italique*`), sans HTML ni lexique `[[…]]`. Le rendu échappe tout, puis transforme ces seules marques.

### 4.2 Sortes de figures (liste fermée, extensible par ADR)

| `kind` | Couvre (3e) | Paramètres (bornés par le schéma) |
|---|---|---|
| `geometry` | Thalès, triangle rectangle, angles inscrits | `points` (≤ 12, coordonnées −20..20), `segments`, `lines`, `circles`, `angles` (marques), `labels` (longueurs), `constraints` (point sur droite, sur cercle) |
| `coordinate_plane` | Vecteurs, équations, fonctions affines | bornes des axes, `points`, `vectors`, `lines` (y = ax + b), `segments` |
| `number_line` | Inéquations, intervalles, racines | bornes, graduation, `points`, `intervals` (ouvert/fermé) |
| `stat_chart` | Statistique | `chart` (`bars`, `histogram`, `pie`), `series` (≤ 20 valeurs), `labels` |
| `solid` | Pyramides et cônes | `shape` (`pyramid`, `cone`), dimensions, `base` (carrée, rectangulaire, triangulaire), perspective cavalière |

`controls` (0 à 4) rend la figure interactive : chaque contrôle est un curseur sur un paramètre numérique. `controls[].param` désigne une **clé numérique de premier niveau** de `params` (ex. `solid.height`, `number_line.min`) ; seules les clés que la sorte déclare réglables dans `FigureKinds` (type nombre) sont acceptées, le rendu ignorant les autres (porteur, 2026-10-29). En `geometry`, aucune clé n'est numérique : l'interaction passe par les points `draggable`, sans curseur. Une figure sans contrôle est fixe.

**Formes des éléments** (contrat lu par les modules de rendu et écrit dans le prompt de rédaction) :

| `kind` | Liste | Forme d'un élément |
|---|---|---|
| `geometry` | `points` | `{"id","x","y","label"?,"draggable"?}` |
| | `segments`, `lines` | `["A","B"]` |
| | `circles` | `{"center","r"}` |
| | `angles` | `{"vertex","from","to","mark"}` (`right` ou `arc`) |
| | `labels` | `{"from","to","text"}` : `text` est posé au milieu du segment, décalé perpendiculairement, du côté opposé aux noms de ses extrémités ; la longueur de chaque segment étiqueté et le rapport des étiquettes deux à deux (1re sur 2e, 3e sur 4e…) sont recalculés en direct |
| | `constraints` | `{"point","on":"AB"}` : le point reste sur le segment dont « AB » colle les deux identifiants |
| | `constraints` (point dérivé) | `{"point":"E","on":"AC","parallel_to":"BC","through":"D"}` : E est l'intersection de (AC) et de la parallèle à (BC) passant par D, recalculée quand D bouge (Thalès : AD/AB = AE/AC). La contrainte est écrite après celle de D ; deux droites parallèles laissent E où il est. E n'est jamais `draggable` |
| `coordinate_plane` | `points` · `vectors` · `lines` · `segments` | `{"id","x","y"}` · `{"label","dx","dy","ox","oy"}` · `{"a","b"}` (y = ax + b) · `{"x1","y1","x2","y2"}` |
| `number_line` | `points` · `intervals` | `{"value","label"}` · `{"from","to","from_open","to_open"}` (un bout absent va à l'infini) |
| `stat_chart` | `series` · `labels` | nombres · textes, dans le même ordre |
| `solid` | dimensions seules | `pyramid` : `base`, `height`, `side` ou `width`+`depth` ; `cone` : `radius`, `height` |

Une sorte nouvelle (un niveau suivant en aura besoin) = une ligne de cette table, un schéma, un module de rendu : un amendement de cet ADR, jamais une figure d'une leçon.

Rendu : un seul, côté navigateur, en SVG, par le contrôleur Stimulus `figure`, qui charge par `import()` le module de la sorte (`app/javascript/lib/figures/<kind>.js`) : rien dans le JS commun. Sans JavaScript, la `description` est affichée. Les mesures affichées (longueurs, rapports) sont recalculées en direct.

### 4.3 Stockage

- `essentials.sheet` (`jsonb`, non nul) : `{remember, method[], example{statement, steps[]}, pitfall, figure_key}`. Le texte riche `content` des notions est supprimé.
- `courses.figures` (`jsonb`, non nul, `[]` par défaut) : la liste des figures de la leçon ; `courses.sheet_theme` (`string`, non nul, `blue` par défaut, contrainte sur les 3 thèmes). Le texte riche de la leçon n'est plus importé (colonne laissée, plus affichée).
- `exercises.figure_key` (`string`, nul) : la figure citée par l'exercice ; rendue sous le sujet.
- Supprimés : `course_sheets`, `essential_images` ; les kinds `course_sheet` et `essentials` de `import_reports`.

### 4.4 Réimport (amende ADR-0113 §4.4)

Clé d'identité inchangée (nom normalisé + niveau + matière + série).

- Leçon existante **publiée ou archivée** : refus de la leçon, raison `lesson_already_published`.
- Leçon existante **en brouillon** (elle et tout son contenu n'ont jamais été publiés) : remplacée entière dans une transaction — exercices, questions, réponses, séances et tentatives sur ces exercices, notions et leurs lectures, puis réécriture. La leçon garde son `id` et son `slug`.

Le remplacement partiel v2 (notions gardées, exercices archivés) disparaît.

### 4.5 Retraits

Use cases `ImportCourseSheet`, `ImportEssentials`, `UploadEssentialImage`, `ReadEssentialImage` ; entité `CourseSheet`, `SheetDocument` ; ports et repositories de fiche cahier et d'images de notions ; jobs d'import correspondants et `PurgeOrphanEssentialImagesJob` ; schémas `lnclass.course-tree.v1/v2`, `lnclass.course-sheet.v1` ; vues `catalog/course_sheets/*` (remplacées par `catalog/revision_sheets/*`, même habillage), `catalog/essentials/_body_image` ; contrôleurs Stimulus `course_sheet/*` et `lib/course_sheet/*` ; dans `course_sheet.css`, les seules classes du lexique, de l'explication simple et des exercices dans la page (UDR-XXXX §4). **L'habillage cahier reste** : feuille `course_sheet.css`, polices Kalam et Source Serif 4, Seyès, 3 thèmes, encadrés (porteur, 2026-10-29) ; routes d'images de notions et `courses/:course_slug/fiche` (la redirection vers `#fiche-de-revision` reste, servie par le contrôleur de la leçon) ; données de démarrage `db/seeds/data/course_sheets/` et `db/seeds/demo/fiches_de_cours.rb` (remplacées par une leçon v3 de démonstration). Les images de **questions** (ADR-0105) restent.

### Menace écrite d'abord (fichier importé)

| Menace | Parade |
|---|---|
| Script injecté par un texte (XSS), y compris dans `description`, `label` d'un contrôle | Aucun HTML ; échappement puis balisage restreint ; les modules de figures créent leurs nœuds SVG par `createElementNS` et `textContent`, jamais `innerHTML` |
| Paramètre de figure hors bornes (boucle, figure illisible, mémoire) | Chaque sorte déclare ses paramètres et bornes dans le schéma JSON ; listes bornées ; refus sinon. Le module revérifie les bornes avant de dessiner et n'affiche que la description en cas d'écart |
| Fichier énorme ou profond | Limites d'`ImportKind` inchangées (50 Mo l'envoi) ; 1 Mo par leçon ; profondeur et longueurs bornées par le schéma |
| Lien sortant, ressource distante | Aucune URL acceptée dans une leçon v3 |
| Remplacement d'une leçon publiée par erreur | Refus si la leçon ou l'un de ses contenus a été publié ; la vérification et l'écriture sont dans la même transaction, leçon verrouillée (`FOR UPDATE`) |
| Fichier en partie valide | Refus de la leçon entière, rapport par élément |

## 5. Conséquences

### 🟢 Positives

- Une leçon est un fichier de données que l'IA écrit et que la machine contrôle ; aucune figure n'est plus du code de leçon.
- Le gabarit porte la pédagogie : l'élève retrouve partout les mêmes 4 blocs, et l'exemple applique la méthode étape par étape.
- Une figure sert dans la fiche et dans un exercice sans être recopiée.
- Lacunes, lectures, remédiation, devoirs : inchangés, la notion reste l'unité.
- Moins de code : un format d'import au lieu de quatre, une sorte de fiche au lieu de deux.

### 🔴 Coûts consentis

- Le cahier garde son habillage mais perd ses blocs libres (lexique en bulle, explications simples, tableaux, exercices dans la page, rédaction libre) ; Thalès et les lentilles perdent leurs figures sur mesure jusqu'à leur réécriture en sortes génériques.
- Cinq modules de rendu SVG à écrire et maintenir ; une sorte manquante bloque une leçon jusqu'à l'amendement de cet ADR.
- Sans JavaScript, l'élève ne voit qu'une description, pas la figure.
- La qualité de la méthode reste une affaire de relecture : la machine vérifie la forme (étapes, présence des corrections), pas la justesse.
- Toutes les matières sont vides après la remise à zéro, jusqu'à leurs propres chantiers ; leurs leçons v1 ne s'importent plus.
- Le réimport d'un brouillon efface les séances de l'équipe sur cette leçon.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/catalog/notion_sheet.rb — Ruby pur
module Entities
  module Catalog
    NotionSheet = Data.define(:remember, :method_steps, :example_statement, :example_steps, :pitfall, :figure_key) do
      METHOD_STEPS = (2..8)

      def self.errors_for(raw)
        errors = []
        steps = Array(raw["method"])
        errors << [ "method", "invalid_count" ] unless METHOD_STEPS.cover?(steps.size)
        errors << [ "example.steps", "example_steps_mismatch" ] unless Array(raw.dig("example", "steps")).size == steps.size
        errors
      end
    end
  end
end
```

```ruby
# app/domain/entities/catalog/import_kind.rb
COURSE_TREE_VERSION = 3
# course_tree : legacy_versions [] ; les versions 1 et 2 sont refusées avec :format_retired.
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/use_cases/catalog/import_course_tree_test.rb` : CA-1 à CA-11 du PRD, une règle par test.
- `test/domain/entities/catalog/notion_sheet_test.rb`, `figure_test.rb` : gabarit, bornes par sorte, sorte inconnue.
- `test/infrastructure/repositories/catalog/content_tree_writer_test.rb` : remplacement du brouillon en transaction, refus d'une leçon publiée (CA-10, CA-11).
- `script/contenus/valider.rb` et son test : mêmes raisons que l'import (CA-18).
- Test de structure : aucun fichier `app/javascript/lib/figures/*.js` hors des sortes listées en §4.2 ; aucune occurrence de `innerHTML` sous `app/javascript/lib/figures/`.
- Les tables `course_sheets` et `essential_images` absentes de `db/schema.rb` (test de schéma).
