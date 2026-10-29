# UDR-XXXX : Fiche de révision en quatre blocs par notion, sur l'habillage cahier, et corrigé de l'équipe
<!-- index
titre: Fiche de révision en quatre blocs et corrigé de l'équipe
statut: Accepté
adr-lie: XXXX-fiche-de-revision-par-notion-et-figures-parametrees
problematique: Montrer chaque notion d'une leçon de la même façon partout, sur le cahier, avec ses figures, et laisser l'équipe relire toutes les corrections avant publication.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-29 |
| **Chantier** | `docs/chantiers/refonte-contenus-maths` |
| **ADR lié** | ADR-XXXX-fiche-de-revision-par-notion-et-figures-parametrees |
| **Remplacé par** | — |

Amende UDR-0137 (habillage cahier gardé, contenu ramené au gabarit) et UDR-0139 §3.2 (contenu du partial `_revision_sheet`). La structure de la page (UDR-0139 §3.1), la coupe des 150 mots et le contrôleur `catalog--revision-more` (§3.2, §3.3) restent.

---

## 1. Contexte

L'élève de 3e révise avant une interrogation : il doit retrouver vite ce qu'il faut savoir, la méthode, un exemple qui l'applique et l'erreur à éviter, toujours au même endroit. Aujourd'hui la présentation change d'une leçon à l'autre (texte libre, ou fiche cahier sur 3 leçons seulement, aux blocs libres).

L'équipe relit une leçon importée en brouillon avant de la publier ; les corrections rédigées ne sont visibles qu'en faisant chaque exercice. Relire 7 exercices de 5 questions par leçon ainsi est impraticable.

## 2. Décision

- **L'habillage cahier reste (porteur, 2026-10-29)** : feuille `course_sheet.css`, papier Seyès et marge, titres en Kalam, texte en Source Serif 4, 3 thèmes (`blue`, `teal`, `burgundy`), encadrés `.sheet-box`. L'exception d'UDR-0137 §2 aux règles de `design_tokens_test.rb` est maintenue pour ces fichiers.
- **Ce qui change, c'est le contenu** : la fiche n'est plus un document de blocs libres mais **une page de cahier par leçon, une section par notion**, au gabarit fixe : À retenir · La méthode · Un exemple corrigé · Le piège à éviter. Les intitulés ne changent jamais : l'élève apprend où regarder.
- **L'exemple corrigé montre le numéro de l'étape qu'il applique**, du même style que les numéros de la méthode : le lien entre la règle et son application se voit.
- **La figure se place entre La méthode et l'exemple** : on voit la situation avant de la résoudre. Interactive quand le fichier déclare des curseurs ; sinon fixe.
- **Retirés du cahier** : lexique en bulle, bascule « explication simple », exercices et « Je m'entraîne » dans la page, rédaction libre (ils n'ont plus de données).
- **Corrigé de l'équipe sur une page à part** (`/teams/courses/:slug/answer-key`), aux styles de l'application (c'est un outil d'équipe, pas un cahier) : l'élève et l'enseignant ne reçoivent jamais les bonnes réponses dans le HTML, et une page imprimable se relit d'une traite. Accès par l'action « Corrigé » du menu ⋮ de la leçon.

## 3. Règles d'implémentation

### 3.1 Partial `catalog/courses/_revision_sheet` (remplace UDR-0139 §3.2, tableau des cas)

| Cas | Rendu |
|---|---|
| Au moins une notion à montrer (publiée, ou toutes pour l'équipe) | feuille `course_sheet` chargée (`content_for :head`, comme aujourd'hui) ; `render "catalog/revision_sheets/sheet", sheet: revision.sheet, cut: revision.cut` |
| Aucune notion à montrer | `ui_empty_state title: t(".revision_empty"), icon: "document-text"` ; pas de « Voir plus » |

La coupe des 150 mots (UDR-0139 §3.2) compte, dans l'ordre de lecture : À retenir, chaque étape de méthode, l'énoncé de l'exemple, chaque étape de l'exemple, le piège ; une formule `$…$` compte un mot ; une figure compte zéro. Les cibles `rest` se posent par bloc (`.sheet-box`, `.sheet-card`, `figure`), ou sur la `section` entière quand elle est toute après la coupe.

### 3.2 Partial `catalog/revision_sheets/_sheet` (remplace `catalog/course_sheets/_sheet`)

```
div.sheet-screen  data-sheet-theme=<theme>  data-seyes="true"  data-embedded="true"  data-controller="math"
  article.sheet-page
    header.sheet-header
      span.sheet-eyebrow       gauche : « <matière> · <niveau> » ; droite : « Fiche de révision »
      h3.sheet-h               nom de la leçon (Kalam)
      p.sheet-intro            sous-titre de la leçon (si présent)
    div.sheet-page-body
      pour chaque notion, numéro n :
        section.sheet-section   id="notion-<slug>"   aria-labelledby="notion-<slug>-title"
          h4.sheet-h#notion-<slug>-title   « n. <nom de la notion> »
          div.sheet-box[data-tone="remember"]
            span.sheet-box-label   « À retenir »
            div.sheet-text         remember
          div.sheet-box[data-tone="method"]
            span.sheet-box-label   « La méthode »
            ol.sheet-steps         une li par étape (numérotation du cahier) ; « Étape n : » en sr-only
          [figure]  render "catalog/figures/figure", figure:      (si la notion cite une figure)
          div.sheet-card
            p.sheet-card-title     « Un exemple corrigé »
            p.sheet-text           énoncé de l'exemple
            ol.sheet-steps[data-applies="method"]   une li par étape, même numérotation que la méthode
          div.sheet-box[data-tone="pitfall"]
            span.sheet-box-label   « Le piège à éviter »
            div.sheet-text         pitfall
    footer.sheet-page-footer   « <nom de la leçon> »
```

- **Une seule page de cahier** par leçon, quelle que soit la longueur ; la coupe des 150 mots fait le reste.
- **Nouveau ton `pitfall`** dans `course_sheet.css` : même gabarit que `remember` et `method`, couleur dérivée des jetons de thème existants (`--sheet-error` pour l'étiquette et le filet, fond à 8 % de cette couleur). Aucun autre ajout à la feuille, hors `.sheet-figure` (§3.3) et les retraits de §4.
- Libellés : `catalog.revision_sheets.sheet.{eyebrow,remember,method,example,pitfall,step}` (fr).
- Texte : helper `sheet_text(text)` existant, **sans** l'argument `glossary` (le lexique `[[…]]` n'est plus accepté). Jamais `raw` ni `html_safe` sur la donnée.
- Thème : `theme` du fichier de la leçon ; absent → `blue`.
- 390 px et ordinateur : comportement actuel de `.sheet-screen[data-embedded]` (page pleine largeur sur téléphone, largeur du cahier sur ordinateur), inchangé.

### 3.3 Partial `catalog/figures/_figure`

```erb
<%= tag.figure class: "sheet-figure",
      data: { controller: "figure", figure_kind_value: figure.kind, figure_params_value: figure.params.to_json,
              figure_controls_value: figure.controls.to_json } do %>
  <div data-figure-target="canvas" class="sheet-figure-canvas" role="img" aria-label="<%= figure.description %>"></div>
  <div data-figure-target="controls" class="sheet-fields"></div>
  <figcaption data-figure-target="fallback" class="sheet-muted"><%= figure.description %></figcaption>
<% end %>
```

- Dans la fiche, la figure prend les classes du cahier (`.sheet-figure` existe : cadre, fond `--sheet-card`). Dans une page d'exercice ou le corrigé (hors cahier), le même partial reçoit `frame: :app` et rend `figure.rounded-xl.border.border-line.bg-paper.p-3`, canvas `aspect-[4/3] w-full`.
- Contrôleur `app/javascript/controllers/figure_controller.js` : `static values = { kind: String, params: Object, controls: Array }` ; `connect()` charge `import(\`../lib/figures/${kind}.js\`)` parmi les seules sortes de l'ADR (liste blanche dans le contrôleur), dessine dans `canvas`, crée un curseur par contrôle, puis masque `fallback` et le remplace par une légende `sr-only` (la description reste lue).
- **Curseur** : libellé visible (texte du contrôle + valeur courante), `input[type=range]` pleine largeur, cible de 48 px de haut, `aria-valuetext` avec l'unité. Chaque changement redessine et met à jour les mesures ; une région `aria-live="polite"` annonce la mesure principale au relâchement.
- **Point déplaçable** (`geometry`) : poignée de 48×48 px de cible, au doigt et à la souris (`pointer` events), au clavier (flèches, pas de 0,5) après focus ; contour de focus visible.
- Couleurs des tracés : variables CSS lues par `getComputedStyle` (dans le cahier : `--sheet-ink`, `--sheet-primary`, `--sheet-accent`, `--sheet-success` ; hors cahier : `--color-ink`, `--color-brand`, `--color-success`, `--color-line`), jamais de valeur en dur dans les modules.
- États : **chargement** — canvas vide, description visible (pas de spinner : la description est le contenu) ; **succès** — figure dessinée, description masquée ; **erreur** (module introuvable, paramètre hors bornes au contrôle client) — rien n'est dessiné, la description reste, `console.warn` ; **vide** — sans objet (pas de figure, pas de partial). Sans JavaScript : la description seule.

### 3.4 Figure d'un exercice

Dans la page de l'exercice et la feuille de devoir (UDR-0140), quand l'exercice a une `figure_key` : `render "catalog/figures/figure", figure:, frame: :app` juste sous le sujet.

### 3.5 Page `teams/answer_keys/show` (corrigé de l'équipe, styles de l'application)

- Route `GET /teams/courses/:slug/answer-key` → `Teams::AnswerKeysController#show` ; `ManageContentPolicy` ; tout autre acteur : 404. Page pleine, pas de Turbo Frame.

```
ui_back_link « Leçon » → page de la leçon
ui_page_header title: « Corrigé — <leçon> »   à droite : badge du statut de contenu existant
p.text-mute  « <n> exercices · <q> questions »
pour chaque exercice, dans l'ordre de « Prépare interros » :
  section  ui_card padding: :md   id="exercise-<public_id>"   aria-labelledby
    p.text-xs.uppercase.text-mute   nom de la notion, ou « Toute la leçon — problème n »
    h2.font-display.text-lg          titre de l'exercice
    div                               sujet (balisage restreint, data-controller="math") ; figure (§3.4) si citée
    ol.mt-4.space-y-5                 une li par question :
      p.font-medium     « Question n · <points> pt » puis l'énoncé
      ul                propositions : bonne(s) avec icône check-circle text-success + « Bonne réponse » en sr-only ; autres text-mute
                        (numeric : valeur attendue et unité ; written / notebook : corrigé type)
      div.rounded-lg.bg-mist.p-3   « Correction » puis explanation
```

- Aucun bouton d'édition (ADR-0113 §4.6). Impression : `print:` masque la navigation, `print:break-inside-avoid` par exercice.
- États : **vide** — leçon sans exercice : `ui_empty_state title: t(".empty")` ; **erreur** — leçon inconnue ou acteur non autorisé : 404 ; **chargement** — sans objet (rendu serveur) ; **succès** — ci-dessus.
- Menu ⋮ de la leçon (`catalog/courses/_role_actions`) : l'entrée « Importer des notions » est **retirée** ; une entrée « Corrigé » (`icon: "clipboard-document-check"`, lien plein, sans `frame`) est ajoutée avant les transitions.

### 3.6 Accessibilité

- Cibles tactiles ≥ 48×48 px (curseurs, poignées, entrées de menu).
- Le numéro d'étape du cahier est décoratif ; le texte lu est « Étape n : … ».
- Contraste du ton `pitfall` vérifié sur les 3 thèmes (≥ 4,5:1 pour l'étiquette).
- Ordre de tabulation : curseurs dans l'ordre du fichier, puis poignées, puis la suite de la page.

## 4. Conséquences

- **Retirés de `course_sheet.css`** et des vues : `.sheet-bubble*`, `.sheet-word`, `.sheet-simple*`, `.sheet-toggle`, `.sheet-toolbar*`, `.sheet-field*`/`.sheet-input`/`.sheet-feedback`/`.sheet-score`/`.sheet-hint`/`.sheet-correction` (exercices dans la page), `.sheet-table` ; dossiers `catalog/course_sheets/` (remplacé par `catalog/revision_sheets/`) et `controllers/course_sheet/`. Gardés : jetons, polices, thèmes, Seyès, `.sheet-screen`, `.sheet-page*`, `.sheet-header`, `.sheet-eyebrow`, `.sheet-h`, `.sheet-intro`, `.sheet-section`, `.sheet-box*`, `.sheet-steps`, `.sheet-card*`, `.sheet-text`, `.sheet-muted`, `.sheet-figure`, `.sheet-fields`, `.sheet-rule*`.
- Toute nouvelle sorte de figure se rend dans le même cadre : pas de figure plein écran ni de modale.
- La page de la leçon n'expose jamais de bonne réponse ; la correction reste celle de la copie (ADR-0115).
- Captures exigées à la livraison : fiche de révision (une notion complète, figure avec curseur) à 390 px et sur ordinateur, dans 2 thèmes ; corrigé de l'équipe ; menu ⋮ ouvert.
