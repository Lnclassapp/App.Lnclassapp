# UDR-0138 : L'exercice sur feuille — le sujet, la copie, le rendu
<!-- index
titre: Exercice sur feuille et copie à rendre
statut: Accepté
adr-lie: 0112
problematique: L'élève répond une question à la fois sans voir de sujet ; un exercice doit se lire comme une feuille, puis se remplir et se rendre en une fois sur un téléphone.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-28 |
| **Chantier** | `docs/chantiers/refonte-page-lecon` |
| **ADR lié** | ADR-0112, ADR-0113 |
| **Remplacé par** | UDR-0140 sur le nom du bouton et le titre de la confirmation (« Vérifier ma copie », « Vérifier ta copie ? ») |

Remplace l'UDR-0087 §3.1 (page de l'exercice), §3.2 (mode concentré), §3.3 (quitter la séance) et §3.5 (retour après « Valider »). Garde l'UDR-0087 §3.4 (saisie par type), §3.6 (résultat, aux changements du §3.4 ci-dessous près) et §3.8 (tokens).

---

## 1. Contexte

L'élève ouvre un exercice, voit 3 questions en aperçu, puis répond une question à la fois en mode concentré, corrigée aussitôt. Il n'y a pas de sujet commun : une question qui s'appuie sur une figure ou un énoncé doit tout répéter. Il ne peut ni relire une question précédente ni changer une réponse. Le porteur veut « l'exercice comme sur une feuille » : un sujet, les questions numérotées, puis une façon de répondre au téléphone.

## 2. Décision

**Deux écrans et un résultat.**

1. **Le sujet** (`assessment/exercises/show`) : la feuille, telle qu'on la distribuerait en classe. L'énoncé, puis toutes les questions numérotées avec leurs propositions. Rien à remplir. Un bouton : « Faire l'exercice ».
2. **La copie** (`assessment/exercise_sessions/show`) : le sujet repliable en haut, puis toutes les questions avec leurs saisies, un compteur, et « Rendre ma copie » collé en bas.
3. **Le résultat** (`assessment/session_results/show`) : la note, puis la correction de chaque question.

Pourquoi une page avec tout, plutôt qu'une question par écran avec « Suivante » : l'élève relit le sujet et ses réponses d'un défilement, comme sur une feuille ; une seule soumission ; un seul écran à tester. Le mode concentré disparaît : la copie garde l'en-tête de l'application, l'élève peut en sortir, son brouillon est gardé.

## 3. Règles d'implémentation

### 3.1 Le sujet — `assessment/exercises/show`

**Structure**

```
ui_back_link <nom de la leçon>  → course_path(slug, anchor: "notion-<slug>")  (ou "toute-la-lecon")
header
  p.text-sm.text-mute          <titre de la notion>  ou  « Toute la leçon »
  h1.font-display.text-2xl     <titre de l'exercice>
  div.flex.gap-2               ui_badge type (Fixation :info, Évaluation :brand) · ui_badge « 5 questions »
article#exercise-sheet  ui_card padding: :lg  data-controller="math"  aria-labelledby="sheet_title"
  h2#sheet_title.sr-only       « Sujet »
  div                           l'énoncé (statement) : simple_format, `$…$` rendu par KaTeX
  ol.mt-6.space-y-6.list-none   une li par question :
    li#sheet-question-<n>
      p.font-medium             « <n>. » + énoncé
      img                       si la question a une image (mêmes attributs que _question_card aujourd'hui)
      render "assessment/exercises/sheet_kinds/<kind>"
footer (élève)                  action principale, collée en bas au téléphone (sticky bottom-0, pb-safe-action)
aside (enseignant)              bascules d'assignation de ses classes (comme la page de la leçon), pas de « Faire l'exercice »
aside (équipe)                  statut de publication, pas de « Faire l'exercice »
```

**Propositions sur la feuille** (`sheet_kinds/_<kind>`), sans aucune indication de bonne réponse :

| Type | Sur la feuille |
|---|---|
| Vrai / Faux, choix unique, 2 ou 3 correctes | liste `A.`, `B.`, `C.`… ; mention « Plusieurs réponses » pour 2 ou 3 correctes |
| Texte à trous | la phrase, chaque trou en `……………` |
| Nombre | « Réponse : …………… » |
| Remettre dans l'ordre | les étapes **mélangées**, lettrées |
| Relier | deux colonnes, la droite **mélangée** |

L'ordre des propositions, des étapes et de la colonne de droite vient de `Entities::Assessment::AnswerShuffle` avec la graine `exercise.id`, jamais de l'ordre de saisie, qui trahirait l'ordre juste.

**Action principale (élève)**, une seule :

| Situation | Bouton (`ui_button variant: :brand, size: :lg`, pleine largeur sous 700 px) | Sous le bouton |
|---|---|---|
| Jamais fait | « Faire l'exercice » | — |
| Copie ouverte | « Reprendre ma copie » | lien `secondary` « Recommencer » |
| Déjà rendu | « Refaire l'exercice » | « Meilleure note : 14/20 » (`text-success` dès 14/20) |

**Mise en page** : une colonne de 720 px dès 700 px ; au téléphone, `px-gutter`.

### 3.2 La copie — `assessment/exercise_sessions/show`

**Shell** : normal (plus de `content_for :focus`). Titre de l'onglet « Copie · <titre> ».

**Structure**

```
ui_back_link <titre de l'exercice> → exercise_path
div.sticky.top-0.z-10.bg-paper.py-3               barre de la copie
  p#copy-counter  aria-live="polite"               « 0/5 répondues »   (cible counter)
  a href="#copy-statement"                         « Revoir le sujet »  (icône document-text, min-h-tap)
details#copy-statement  open  ui_card  data-controller="math"
  summary                                          « Sujet »
  l'énoncé seul (les questions sont dessous)
form#copy-form  form_with url: exercise_session_copy_path(public_id), scope: :copy, method: :post
                data-controller="assessment--copy"
                data-assessment--copy-key-value="lnclass:copy:<public_id>"
                data-assessment--copy-total-value="<n>"
  div#copy-errors role="alert" tabindex="-1"       (seulement en 422) liens « Question 3 : … » vers #question-3
  ol.space-y-6.list-none
    li#question-<n>  ui_card  data-assessment--copy-target="question"  data-controller="math"
      fieldset  aria-invalid + aria-describedby="question-<n>-error"   (si erreur)
        legend  « Question <n> » (text-xs uppercase text-mute) puis l'énoncé (font-medium)
        img si image
        render "assessment/exercise_sessions/kinds/<kind>", f: <fields_for "answers[<question_id>]">, question:
      p#question-<n>-error.text-warning             (seulement en 422)
  div.sticky.bottom-0.bg-paper.pt-4.pb-safe-action
    ui_button « Rendre ma copie », type: :submit, variant: :brand, size: :lg, full: true,
              data: { action: "assessment--copy#submit", turbo_submits_with: t(".submitting") }
  ui_modal id: "copy-confirm", placement: :sheet sous 700 px (:center au-delà), title: « Rendre ta copie ? »
    p   t(".missing", count:)
    ui_button « Rendre quand même » (brand, type: :submit, form: "copy-form", data-assessment--copy-confirmed)
    ui_button « Continuer ma copie » (secondary) → ferme, focus sur la première question vide
```

**Saisies** : les partials `kinds/_<kind>` de l'UDR-0087 §3.4, inchangés à l'écran. Ils reçoivent un `f` déjà préfixé : `copy[answers][<question_id>][answer_ids][]`, `[response_text]`, `[display_order][]`. Les noms codés en dur (`attempt[answer_ids][]` dans `_choice`) passent par `f`. Les contrôleurs par type (`assessment--numeric`, `--ordering`, `--matching`) s'attachent à chaque question, pas au formulaire. Chaque `id` d'élément de saisie est préfixé par `q<n>-` (plusieurs questions dans la page).

**Contrôleur `app/javascript/controllers/assessment/copy_controller.js`**

- `static targets = ["question", "counter"]`, `static values = { key: String, total: Number, counter: String, missingOne: String, missingOther: String }`.
- `connect()` : relit `localStorage[key]` (dans `try`/`catch`) et remet chaque valeur dans son champ, puis déclenche `change` pour que les contrôleurs par type se recalent ; met à jour le compteur.
- `input` / `change` sur le formulaire : écrit `{ "<name>": [valeurs] }`, pour les seuls champs `copy[answers]…`, dans `localStorage[key]` ; met à jour le compteur. Une question compte « répondue » quand sa saisie est complète au sens de l'UDR-0087 §3.4 (ordre : toujours).
- `submit(event)` : si des questions sont vides et que l'envoi ne vient pas de « Rendre quand même » → `preventDefault`, remplit le texte, ouvre `#copy-confirm`.
- `turbo:submit-end` : `event.detail.success` → `localStorage.removeItem(key)`. Échec réseau (`fetchResponse` absent) → toast `t(".offline")`, bouton réactivé.
- Le brouillon ne contient que les champs de réponse : des indices d'affichage, jamais un identifiant ni une correction.
- Risque accepté : après une déconnexion, le brouillon reste dans le navigateur. Sa clé est propre à la session (`lnclass:copy:<public_id>`) : un autre élève sur le même appareil n'y lit que des choix, jamais une correction.

**Sans JavaScript** : le formulaire s'envoie tel quel, sans confirmation ; les questions vides comptent fausses ; pas de brouillon ; « Revoir le sujet » est une ancre ; `details` reste ouvert ; ordre et relier se saisissent par `select` (UDR-0087 §3.4).

**Mise en page** : une colonne de 720 px dès 700 px. Au téléphone, `px-gutter`, cartes pleine largeur, barre de la copie et bouton collés.

### 3.3 Réponses du serveur

| Cas | Réponse | Écran |
|---|---|---|
| Rendu accepté | 303 → `exercise_session_result_path` | résultat |
| Copie déjà rendue | 303 → résultat existant | résultat |
| Réponse illisible | 422, `show` re-rendu avec les valeurs postées | `#copy-errors` reçoit le focus ; chaque question en cause a son message ; rien n'est noté |
| Exercice archivé, copie abandonnée | 303 → page de la leçon, flash alert « Cet exercice a été retiré. » | le brouillon est effacé (`submit-end` en succès) |
| Copie d'un autre élève | 403 (page d'erreur générique) | — |

### 3.4 Le résultat — `assessment/session_results/show`

UDR-0087 §3.6, avec ces changements :

- **Correction** : toutes les questions, dans l'ordre, en `ol` de `ui_card`. Pour chacune : numéro et énoncé, puis un badge de verdict — « Juste » (`:success`, `check-circle`), « Faux » (`:warning`, `x-circle`), « Sans réponse » (`:neutral`, `minus-circle`) ; puis « Ton choix » (absent si « Sans réponse ») ; puis l'explication si elle existe. La bonne réponse ne s'affiche que si `RevealAnswersPolicy` l'autorise (inchangé).
- **Notion à revoir** (exercice de notion, sous le seuil) : le partial `_gap_outcome` garde sa place ; son lien mène à `course_path(slug, anchor: "notion-<slug>")` avec le libellé « Refaire l'exercice ».
- **Actions** : « Refaire l'exercice » (`brand`, caché à 20/20), « Retour à la leçon » (`secondary`, vers `#notion-<slug>` ou `#toute-la-lecon`).
- **Exercice de toute la leçon** : jamais de bloc « Notion à revoir ».

### 3.5 Tokens

Ceux de l'UDR-0087 §3.8, sans ajout. `text-warning` pour une erreur, jamais de rouge. Cibles ≥ 48 px (`min-h-tap`, `size-tap`).

### 3.6 États obligatoires

| État | Sujet | Copie | Résultat |
|---|---|---|---|
| Vide | exercice sans question : impossible à publier ; pour l'équipe, `ui_empty_state` « Cet exercice n'a pas encore de questions. » | — | — |
| Chargement | — | bouton « Envoi… » désactivé (`turbo_submits_with`) | — |
| Erreur | — | 422 : résumé et message par question ; réseau : toast, brouillon gardé ; archivé : redirection et flash | — |
| Succès | la feuille et son bouton | toutes les questions, compteur juste | note, correction, notion à revoir éventuelle |

### 3.7 Accessibilité

- Une question = un `fieldset` et sa `legend` ; l'image a son `alt`.
- Compteur en `aria-live="polite"` ; résumé d'erreurs en `role="alert"`, focus à l'arrivée.
- `ui_modal` : focus piégé, `Échap` = « Continuer ma copie ».
- Le verdict n'est jamais porté par la couleur seule (texte et icône).

### 3.8 Textes (valeurs imposées)

| Clé | Valeur |
|---|---|
| `assessment.exercises.show.sheet_title` | « Sujet » |
| `assessment.exercises.show.start` | « Faire l'exercice » |
| `assessment.exercises.show.resume` | « Reprendre ma copie » |
| `assessment.exercises.show.restart` | « Recommencer » |
| `assessment.exercises.show.redo` | « Refaire l'exercice » |
| `assessment.exercises.show.best` | « Meilleure note : %{grade}/20 » |
| `assessment.exercises.show.lesson_wide` | « Toute la leçon » |
| `assessment.exercises.show.several_answers` | « Plusieurs réponses » |
| `assessment.exercises.show.no_questions` | « Cet exercice n'a pas encore de questions. » |
| `assessment.exercise_sessions.show.page_title` | « Copie · %{title} » |
| `assessment.exercise_sessions.show.counter` | « %{answered}/%{total} répondues » |
| `assessment.exercise_sessions.show.statement` | « Sujet » |
| `assessment.exercise_sessions.show.review_statement` | « Revoir le sujet » |
| `assessment.exercise_sessions.show.question` | « Question %{number} » |
| `assessment.exercise_sessions.show.submit` | « Rendre ma copie » |
| `assessment.exercise_sessions.show.submitting` | « Envoi… » |
| `assessment.exercise_sessions.show.confirm_title` | « Rendre ta copie ? » |
| `assessment.exercise_sessions.show.missing` | one « 1 question sans réponse comptera fausse. » · other « %{count} questions sans réponse compteront fausses. » |
| `assessment.exercise_sessions.show.confirm` | « Rendre quand même » |
| `assessment.exercise_sessions.show.keep_going` | « Continuer ma copie » |
| `assessment.exercise_sessions.show.offline` | « Copie non envoyée : vérifie ta connexion. Tes réponses sont gardées. » |
| `assessment.exercise_copies.create.archived` | « Cet exercice a été retiré. » |
| `assessment.session_results.show.correct` | « Juste » |
| `assessment.session_results.show.wrong` | « Faux » |
| `assessment.session_results.show.unanswered` | « Sans réponse » |
| `assessment.session_results.show.back_to_lesson` | « Retour à la leçon » |

## 4. Conséquences

- Sont retirés : `_question_card`, `_feedback_card`, `_progress_bar`, `_quit_dialog`, `_quit_resume`, les partials `kinds/*_feedback`, les contrôleurs `assessment--answer`, `assessment--next-question`, `assessment--verdict`, et `_questions_preview` (remplacé par la feuille complète).
- Le mode concentré (`content_for :focus`) n'a plus d'usage pour l'exercice ; le shell le garde tant qu'un autre écran s'en sert.
- Toute nouvelle saisie de question doit accepter un `f` préfixé et se rendre plusieurs fois dans la même page.
