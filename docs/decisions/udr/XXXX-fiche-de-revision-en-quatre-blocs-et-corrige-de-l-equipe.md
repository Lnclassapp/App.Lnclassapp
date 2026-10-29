# UDR-XXXX : Fiche de révision en quatre blocs par notion, figures paramétrées et corrigé de l'équipe
<!-- index
titre: Fiche de révision en quatre blocs et corrigé de l'équipe
statut: Accepté
adr-lie: XXXX-fiche-de-revision-par-notion-et-figures-parametrees
problematique: Montrer chaque notion d'une leçon de la même façon partout, avec ses figures, et laisser l'équipe relire toutes les corrections avant publication.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-29 |
| **Chantier** | `docs/chantiers/refonte-contenus-maths` |
| **ADR lié** | ADR-XXXX-fiche-de-revision-par-notion-et-figures-parametrees |
| **Remplacé par** | — |

Remplace UDR-0137 (fiche à l'identique des maquettes). Amende UDR-0139 §3.2 (contenu du partial `_revision_sheet`) ; la structure de la page (§3.1), la coupe des 150 mots et le contrôleur `catalog--revision-more` (§3.2, §3.3) restent.

---

## 1. Contexte

L'élève de 3e révise avant une interrogation : il doit retrouver vite ce qu'il faut savoir, la méthode, un exemple qui l'applique et l'erreur à éviter, toujours au même endroit. Aujourd'hui la présentation change d'une leçon à l'autre (texte libre, ou fiche cahier sur 3 leçons seulement).

L'équipe relit une leçon importée en brouillon avant de la publier ; les corrections rédigées ne sont visibles qu'en faisant chaque exercice. Relire 7 exercices de 5 questions par leçon ainsi est impraticable.

## 2. Décision

- **Une notion = une carte au gabarit fixe**, dans l'ordre de la leçon : À retenir · La méthode · Un exemple corrigé · Le piège à éviter. Les intitulés ne changent jamais : l'élève apprend où regarder.
- **L'exemple corrigé montre le numéro de l'étape qu'il applique** (pastille « 1 », « 2 »…), du même style que les numéros de la méthode : le lien entre la règle et son application se voit.
- **La figure se place entre La méthode et l'exemple** : on voit la situation avant de la résoudre. Elle est interactive quand le fichier déclare des curseurs ; sinon fixe.
- **Corrigé de l'équipe sur une page à part** (`/teams/courses/:slug/answer-key`), pas dans la page de la leçon : l'élève et l'enseignant ne doivent jamais recevoir les bonnes réponses dans le HTML, et une page imprimable se relit d'une traite. Accès par l'action « Corrigé » du menu ⋮ de la leçon.
- **Pas de lexique en bulle, pas d'explication simplifiée, pas d'exercice dans la fiche** : retirés avec la fiche cahier.

## 3. Règles d'implémentation

### 3.1 Partial `catalog/courses/_revision_sheet` (remplace UDR-0139 §3.2, tableau des cas)

| Cas | Rendu |
|---|---|
| La leçon a au moins une notion publiée (ou l'acteur est de l'équipe) | `div.space-y-6[data-controller="math"]` ; pour chaque notion, dans l'ordre : `render "catalog/courses/notion_card", notion:, figures: revision.figures` |
| Aucune notion à montrer | `ui_empty_state title: t(".revision_empty"), icon: "document-text"` ; pas de « Voir plus » |

La coupe des 150 mots (UDR-0139 §3.2) s'applique **par bloc** de carte, dans l'ordre de lecture : À retenir, chaque étape de méthode, l'énoncé de l'exemple, chaque étape de l'exemple, le piège ; une formule `$…$` compte un mot ; une figure compte zéro. Une carte entièrement après la coupe porte la cible `rest` sur l'`article` entier ; sinon chaque bloc après la coupe la porte.

### 3.2 Partial `catalog/courses/_notion_card`

```
article.notion-card  ui_card padding: :lg   id="notion-<slug>"   aria-labelledby="notion-<slug>-title"
  h3#notion-<slug>-title   font-display text-lg font-medium   — nom de la notion
  section (aria-label t(".remember"))      rounded-xl bg-success-soft p-4
    p.text-xs.font-semibold.uppercase.tracking-wide.text-success   « À retenir »
    div.prose-sheet      remember (balisage restreint)
  section (aria-label t(".method"))        mt-5
    p.text-xs.font-semibold.uppercase.tracking-wide.text-brand-strong   « La méthode »
    ol.space-y-2         une li.flex.gap-3 par étape :
      span.step-badge (aria-hidden)   numéro   — 28×28 px, rounded-full, bg-brand-soft, text-brand-strong, font-semibold
      span                             « Étape n : » en sr-only, puis le texte
  [figure]  render "catalog/figures/figure", figure:   mt-5   (si la notion cite une figure)
  section (aria-label t(".example"))       mt-5 rounded-xl border border-line p-4
    p.text-xs.font-semibold.uppercase.tracking-wide.text-mute   « Un exemple corrigé »
    p.font-medium        énoncé de l'exemple
    ol.mt-3.space-y-2    une li.flex.gap-3 par étape : span.step-badge (même numéro que la méthode) + texte
  section (aria-label t(".pitfall"))       mt-5 rounded-xl bg-warning-soft p-4
    p.text-xs.font-semibold.uppercase.tracking-wide.text-warning   « Le piège à éviter »
    div.prose-sheet      pitfall
```

- Les libellés viennent de `catalog.courses.notion_card.{remember,method,example,pitfall,step}` (fr).
- `.step-badge` et `.prose-sheet` (taille `text-base`, interligne 1.6, `strong` en `text-ink`) sont définis une fois dans `application.tailwind.css` (`@layer components`), avec les tokens ci-dessus. Aucune couleur en dur.
- Texte : helper `restricted_markup(text)` (échappe, puis `$…$` → `span.math` lu par le contrôleur `math` existant, `**…**` → `strong`, `*…*` → `em`). Jamais `raw` ni `html_safe` sur la donnée.
- 390 px : la carte occupe toute la largeur, `padding: :lg` devient `p-4` sous `sm` (comportement de `ui_card`). Ordinateur : largeur de lecture `max-w-3xl` pour la section.

### 3.3 Partial `catalog/figures/_figure`

```erb
<%= tag.figure class: "figure-frame rounded-xl border border-line bg-paper p-3",
      data: { controller: "figure", figure_kind_value: figure.kind, figure_params_value: figure.params.to_json,
              figure_controls_value: figure.controls.to_json } do %>
  <div data-figure-target="canvas" class="aspect-[4/3] w-full" role="img" aria-label="<%= figure.description %>"></div>
  <div data-figure-target="controls" class="mt-3 space-y-3"></div>
  <figcaption data-figure-target="fallback" class="text-sm text-mute"><%= figure.description %></figcaption>
<% end %>
```

- Contrôleur `app/javascript/controllers/figure_controller.js` : `static values = { kind: String, params: Object, controls: Array }` ; `connect()` charge `import(\`../lib/figures/${kind}.js\`)` parmi les seules sortes de l'ADR (table blanche dans le contrôleur), dessine dans `canvas`, crée un curseur par contrôle, puis masque `fallback` (`hidden`) et le remplace par une légende `sr-only` (la description reste lue).
- **Curseur** : `label` visible (texte du contrôle + valeur courante), `input[type=range]` pleine largeur, hauteur de cible 48 px, `aria-valuetext` avec l'unité. Chaque changement redessine et met à jour les mesures affichées ; une région `aria-live="polite"` annonce la mesure principale au relâchement.
- **Point déplaçable** (`geometry`) : poignée de 48×48 px de cible, au doigt et à la souris (`pointer` events), au clavier (flèches, pas de 0,5) après focus ; contour de focus `outline-brand`.
- États : **chargement** — `canvas` vide, `fallback` visible (pas de spinner : la description est le contenu) ; **succès** — figure dessinée, `fallback` masqué ; **erreur** (module introuvable, paramètre hors bornes au contrôle client) — rien n'est dessiné, `fallback` reste visible, `console.warn` ; **vide** — sans objet (pas de figure, pas de partial).
- Sans JavaScript : la description seule.
- Couleurs des tracés : variables CSS lues par `getComputedStyle` (`--color-ink`, `--color-brand`, `--color-success`, `--color-warning-dot`, `--color-line`), jamais de valeur en dur dans les modules.

### 3.4 Figure d'un exercice

Dans la page de l'exercice et la feuille de devoir (UDR-0140), quand l'exercice a une `figure_key` : `render "catalog/figures/figure"` juste sous le sujet, mêmes règles qu'en §3.3.

### 3.5 Page `teams/answer_keys/show` (corrigé de l'équipe)

- Route `GET /teams/courses/:slug/answer-key` → `Teams::AnswerKeysController#show` ; `ManageContentPolicy` ; tout autre acteur : 404. Page pleine, pas de Turbo Frame.
- Structure :

```
ui_back_link « Leçon » → page de la leçon
ui_page_header title: « Corrigé — <leçon> »   subtitle: statut (badge du statut de contenu existant)
p.text-mute  « <n> exercices · <q> questions »
pour chaque exercice, dans l'ordre de « Prépare interros » :
  section  ui_card padding: :md   id="exercise-<public_id>"   aria-labelledby
    p.text-xs.uppercase.text-mute   intertitre : nom de la notion, ou « Toute la leçon — problème n »
    h2.font-display.text-lg   titre de l'exercice
    div.prose-sheet           sujet ; puis figure (§3.3) si citée
    ol.mt-4.space-y-5         une li par question :
      p.font-medium           « Question n · <points> pt » puis l'énoncé
      ul                      propositions ; bonne(s) proposition(s) : icône check-circle text-success + texte « Bonne réponse » en sr-only ; les autres : text-mute
                              (numeric : valeur attendue et unité ; written/notebook : corrigé type)
      div.rounded-lg.bg-mist.p-3   « Correction » + explanation (balisage restreint)
```

- Aucun bouton d'édition (ADR-0113 §4.6). Impression : `print:` masque la navigation, une section par page au plus (`print:break-inside-avoid`).
- États : **vide** — leçon sans exercice : `ui_empty_state title: t(".empty")` ; **erreur** — leçon inconnue : 404 ; **chargement** — sans objet (rendu serveur) ; **succès** — ci-dessus.
- Menu ⋮ de la leçon (`catalog/courses/_role_actions`) : l'entrée « Importer des notions » est **retirée** ; une entrée « Corrigé » (`icon: "clipboard-document-check"`, lien plein, sans `frame`) est ajoutée avant les transitions.

### 3.6 Accessibilité

- Cibles tactiles ≥ 48×48 px (curseurs, poignées, entrées de menu).
- Les numéros d'étape décoratifs sont `aria-hidden` ; le texte lu est « Étape n : … ».
- Contraste des étiquettes sur fond doux : `text-success` sur `bg-success-soft`, `text-warning` sur `bg-warning-soft` (≥ 4,5:1 avec les tokens actuels).
- Ordre de tabulation : curseurs dans l'ordre du fichier, puis poignées, puis la suite de la page.

## 4. Conséquences

- Plus aucune vue ni feuille de style propre à une leçon ; `course_sheet.css` et `catalog/course_sheets/*` disparaissent.
- Toute nouvelle sorte de figure se rend dans le même cadre `figure-frame` : pas de figure plein écran ni de modale.
- La page de la leçon n'expose jamais de bonne réponse ; la correction reste celle de la copie (ADR-0115).
- Captures exigées à la livraison : page de la leçon (carte de notion, figure avec curseur) à 390 px et sur ordinateur, corrigé de l'équipe, menu ⋮ ouvert.
