# UDR-0147 : « Je m'entraîne » dans la fiche de révision, questions à plusieurs cases et indice
<!-- index
titre: Je m'entraîne dans la fiche, cases multiples et indice
statut: Accepté
adr-lie: 0119-entrainement-de-notion-corrige-sans-trace, 0120-questions-a-plusieurs-cases-et-indice
problematique: L'élève lit la méthode et l'exemple corrigé d'une notion mais ne peut pas s'y essayer sur place, et les exercices ne savent ni demander plusieurs valeurs dans une phrase ni donner un indice.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-30 |
| **Chantier** | `docs/chantiers/je-m-entraine-dans-la-fiche` |
| **ADR lié** | ADR-0119, ADR-0120 |
| **Remplacé par** | — |

Amende l'UDR-0141 : le §2 (« Retirés du cahier : … exercices et « Je m'entraîne » dans la page ») ne vaut plus pour « Je m'entraîne », et le §3.2 gagne un 5e bloc entre l'exemple et le piège. Amende aussi l'UDR-0141 §3.1 / UDR-0139 §3.2 (coupe des 150 mots : le nouveau bloc compte zéro mot), l'UDR-0087 §3.4 et l'UDR-0140 §3 (saisie d'un texte à trous, d'une liste ou d'un chiffré à plusieurs cases), et l'UDR-0145 (carte d'une question dans la copie : bouton « Indice »). Le reste de l'UDR-0141 tient : habillage cahier, gabarit, figures, corrigé de l'équipe.

---

## 1. Contexte

L'élève lit la méthode puis un exemple corrigé, et doit ensuite quitter sa lecture pour s'essayer : l'exercice est dans « Prépare interros », plus bas, noté et compté. Le porteur veut qu'il s'exerce **là où il vient de comprendre**, avec la correction sur place, autant qu'il veut et sans que rien ne compte (grills 1 et 2).

Les maquettes demandent aussi deux valeurs dans une même phrase (« AN (cm) = … MN (cm) = … ») et un indice. Le porteur veut ces deux possibilités dans tous les exercices, notés compris (grills 7 à 11).

## 2. Décision

- **Un 5e bloc, « Je m'entraîne »**, entre « Un exemple corrigé » et « Le piège à éviter », seulement quand la notion a un exercice d'entraînement. L'ordre devient : 1. À retenir · 2. La méthode · (figure) · 3. Un exemple corrigé · 4. Je m'entraîne · 5. Le piège à éviter. Le libellé ne change jamais d'une notion à l'autre.
- **Le bloc est une carte du cahier (`.sheet-card`, ton `practice`)**, pas un encadré : c'est un travail à faire, comme l'exemple est un travail fait. Les cases s'écrivent **dans la phrase**, à l'endroit des `___`, comme sur la maquette et comme sur la copie papier.
- **« Vérifier » renvoie le verdict dans un Turbo Frame propre à la notion** : la page ne se recharge pas, la position de lecture est gardée, et sans JavaScript le formulaire ouvre une page de résultat. Aucun contrôleur Stimulus nouveau : le plafond de 61 Ko (ADR-0114) ne bouge pas.
- **« Correction » n'existe qu'après un premier « Vérifier »** (grill 13). Avant, le bouton n'est pas dans la page, ni masqué ni désactivé : le corrigé n'est pas envoyé.
- **« Indice » est un `<details>`** dans la fiche, sans requête. Dans une copie notée, c'est un bouton qui demande l'indice au serveur, lequel l'enregistre (ADR-0120).
- **Verdict par case, en mots** : « Juste », « À revoir », « À compléter ». Jamais par la couleur seule.

## 3. Règles d'implémentation

### 3.1 Partial `catalog/revision_sheets/_sheet` — insertion du bloc

Après la `div.sheet-card` de l'exemple, avant la `div.sheet-box[data-tone="pitfall"]` :

```erb
<% if notion.practice %>
  <%= render "catalog/revision_sheets/practice", notion:, rest: rest_for.(index, preview::PRACTICE) %>
<% end %>
```

`notion.practice` est un `Entities::Catalog::NotionPractice` **sans correction** (`without_correction`) ; `nil` → aucun rendu, aucun titre, aucun message (CA-2).

### 3.2 Partial `catalog/revision_sheets/_practice` (nouveau)

```
div.sheet-card[data-tone="practice"]  data-catalog--revision-more-target="rest" (si rest non vide)
  p.sheet-card-title                    « Je m'entraîne »                         id="notion-<slug>-practice-title"
  p.sheet-text                          statement (sheet_text)                    (si présent)
  turbo-frame#practice_<notion.slug>
    form  action=practice_check_path(course_slug:, slug: notion.slug)  method=post
          data-turbo-frame="practice_<slug>"  aria-labelledby="notion-<slug>-practice-title"
      input[type=hidden name=digest value=practice.digest]
      ol.sheet-practice-questions
        pour chaque question q (numéro n à partir de 1) :
          li#practice-<slug>-q<n>
            fieldset
              legend.sr-only            « Question n »
              p.sheet-practice-line     segments de q.content : texte (sheet_text) et cases (§3.3), dans l'ordre
              [details.sheet-practice-hint]   (si q.hint)
                summary                « Indice »
                p.sheet-text           q.hint
      p.sheet-practice-help             « Écris tes réponses dans les cases (virgule ou point pour les décimaux), puis vérifie. »
      div.sheet-practice-actions
        button[type=submit].sheet-button   « Vérifier »
```

- Classes nouvelles dans `course_sheet.css`, en jetons du cahier seulement :
  - `.sheet-card[data-tone="practice"]` : filet gauche de 3 px en `--sheet-primary`, sinon le gabarit `.sheet-card`.
  - `.sheet-practice-line` : `font-family: var(--sheet-font-body)`, `line-height: 32px` (rythme Seyès), `flex-wrap`.
  - `.sheet-input` : `min-width: 7ch`, `height: var(--sheet-touch)` (44 px, porté à 48 px), bordure `1.5px solid var(--sheet-field-border)`, `border-radius: var(--sheet-radius-field)`, fond `--sheet-white`, focus `outline: 2px solid var(--sheet-primary)`.
  - `.sheet-button` : hauteur 48 px, fond `--sheet-primary`, texte `--sheet-white`, `--sheet-radius-box`. `.sheet-button[data-variant="ghost"]` : fond transparent, bordure `--sheet-primary`.
  - `.sheet-verdict[data-verdict="correct|wrong|blank"]` : texte et icône, en `--sheet-success`, `--sheet-error` ou `--sheet-pending`.
- Libellés : `catalog.revision_sheets.practice.{title,question,hint,help,check,correction,done,correct,wrong,blank,all_correct,some_wrong,changed,rate_limited,back}`.

### 3.3 Les cases, selon le type (fiche et copie)

Le texte d'une question est découpé par `Assessment::BlanksHelper#blank_segments(content)` → `[[:text, "AN (cm) = "], [:blank, 0], [:text, "  MN (cm) = "], [:blank, 1]]`. Le même helper sert à la fiche (styles du cahier) et à la copie (styles de l'application). Une question `numeric` sans `___` a une case unique, placée après le texte.

| Type | Case `i` | Nom du champ | Notes |
|---|---|---|---|
| `numeric` | `input[type=text] inputmode=decimal autocomplete=off` | `answers[<q>][blanks][<i>]` | l'unité de la question suit la case (`span`, `aria-describedby`) |
| `fill_blank` | `input[type=text] autocomplete=off spellcheck=false` | `answers[<q>][blanks][<i>]` | `maxlength` 200 |
| `select` | `select` avec option vide « Choisir » puis les propositions de la case `i` | `answers[<q>][blanks][<i>]` | valeur = identifiant ou position de la proposition, jamais `correct` |
| `single_choice`, `true_false`, `multiple_correct_*` | les cases à cocher ou boutons radio actuels, sous la phrase | `answers[<q>][ids][]` | une case |
| `ordering`, `matching` | les partials actuels de la copie (fiche : mêmes champs, styles du cahier) | inchangé | une case |
| `written` | `textarea` 6 lignes, `starter` en début | `answers[<q>][text]` | pas de verdict |
| `notebook` | pas de champ ; « Fais-le sur ton cahier. » | — | pas de verdict |

- Chaque case a un `aria-label` : « Case i de la question n », plus l'unité s'il y en a une.
- Les exercices où toutes les questions sont `written` ou `notebook` n'ont pas « Vérifier » mais « J'ai fini » (`done`), qui envoie le même formulaire (CA-17).

### 3.4 Réponse de « Vérifier » — partial `catalog/practice_checks/_result`

Le contrôleur rend `turbo-frame#practice_<slug>` avec le même formulaire, les saisies **gardées**, puis :

```
div.sheet-practice-feedback  role="status"  aria-live="polite"
  p                       « Tout est juste, bravo ! » | « Certaines réponses sont à revoir. » | « Complète les cases vides. »
chaque case : juste après le champ
  span.sheet-verdict[data-verdict]   icône (aria-hidden) + « Juste » | « À revoir » | « À compléter »
  le champ porte aria-invalid="true" si wrong ou blank, aria-describedby → son verdict
div.sheet-practice-actions
  button[type=submit].sheet-button                     « Vérifier »
  details.sheet-practice-correction
    summary.sheet-button[data-variant="ghost"]         « Correction »
    ol  une li par question : « Question n : » + bonnes réponses par case (« AN = 4,8 cm ; MN = 3 cm »), puis explanation (sheet_text)
        written / notebook : le corrigé type (explanation)
```

- Le focus va au message global (`tabindex="-1"`, posé par l'attribut `autofocus` du frame rendu), ce qui suffit à le faire lire.
- Les verdicts de « Vérifier » et le corrigé ne sont rendus **que** dans cette réponse, jamais dans la page de la leçon.

### 3.5 États obligatoires du bloc

| État | Rendu |
|---|---|
| **Vide** | pas d'exercice d'entraînement → pas de bloc (§3.1) |
| **Chargement** | pendant l'envoi, Turbo pose `aria-busy="true"` sur le frame ; `.sheet-button[disabled]` via `turbo-submit-start` natif (attribut `data-turbo-submits-with="Vérification…"` sur le bouton) |
| **Erreur 409** (exercice changé) | le frame montre `p.sheet-verdict[data-verdict="wrong"]` « Cet exercice a changé : recharge la fiche. » et un lien « Recharger » vers `course_path(slug, anchor: "notion-<slug>")` ; pas de formulaire |
| **Erreur 429** | le frame montre le formulaire, saisies gardées, avec « Trop d'essais d'un coup : attends une minute. » en `role="alert"` |
| **Erreur 404** | réponse 404 hors frame : Turbo affiche « Contenu manquant » dans le frame ; acceptable, ce cas suppose une leçon dépubliée pendant la lecture |
| **Succès** | §3.4 |

### 3.6 Sans JavaScript — page `catalog/practice_checks/show`

Le même POST sans en-tête `Turbo-Frame` rend une page pleine (layout de l'application) : `ui_page_header title: "<notion> — Je m'entraîne"`, le cadre du cahier (`.sheet-screen` en `data-embedded`), le partial `_result`, et un lien « Retour à la fiche » vers `course_path(slug, anchor: "notion-<slug>")`. Même statut HTTP que la réponse du frame.

### 3.7 Coupe « Voir plus »

`RevisionPreview::PRACTICE = 4`, `PITFALL = 5`. Le bloc compte 0 mot et se place entre l'exemple et le piège. Il ne peut donc pas être le bloc qui franchit les 150 mots : il est visible en entier si la coupe tombe après lui, et caché en entier (cible `rest` sur la carte) si elle tombe avant (CA-10).

### 3.8 Copie notée — cases et indice (`assessment/exercise_sessions/show`, `kinds/_numeric|_fill_blank|_select`)

- **Cases** : une question à plusieurs cases rend ses segments (§3.3) dans la `legend` à la place de l'énoncé, avec les champs dans la phrase et aux styles de l'application (`h-12 min-w-24 rounded-ln border-2 border-line bg-white px-3 font-display text-xl`). Une question à une case garde son rendu actuel, au pixel.
- **Indice** : sous le `fieldset`, quand la question a un indice :

```
turbo-frame#hint_<question.id>
  button[type=submit form="hint-form-<question.id>"]  ui_button variant: :ghost, size: :sm, icon: "light-bulb"   « Indice »

(après le form de la copie, jamais dedans : HTML interdit les formulaires imbriqués)
form#hint-form-<question.id>  action=exercise_session_hints_path(session.public_id)  method=post  data-turbo-frame=hint_<question.id>
  input[type=hidden name=question_id]
```

  La réponse (Turbo Stream `replace hint_<id>`) rend `div.rounded-ln.bg-mist.p-3.text-sm` avec `p` « Indice : <texte> », sans bouton. Une copie rechargée montre les indices déjà ouverts, lus dans `hinted_question_ids`. Sans JavaScript, le POST redirige vers la copie à l'ancre `#question-<n>`, l'indice ouvert.
- La copie n'affiche jamais « cet indice ne coûte rien » ni « l'enseignant le verra » : la mention d'aide sous le titre de l'exercice dit une fois, dans `t(".hint_notice")`, « Les indices ne changent pas ta note ; ton enseignant voit ceux que tu as ouverts. »

### 3.9 Résultat et copie lue par l'enseignant (`assessment/session_results/_question_review`, `kinds/*_review`)

- **Plusieurs cases** : la phrase est rendue avec, à la place de chaque case, la réponse de l'élève suivie de son verdict (`ui_badge` « Juste », tone `:success`, ou « À revoir », tone `:danger`) puis, si elle est fausse et que la correction est montrable (`RevealCorrectionPolicy`), « attendu : <valeur> ». Les points de la question s'affichent en « 1 / 2 pt ».
- **Indice ouvert** : `ui_badge t(".hint_opened"), tone: :neutral, icon: "light-bulb"` (« Indice ouvert ») à droite du numéro de la question, pour l'élève, l'enseignant et l'équipe.
- **Corrigé de l'équipe** (`teams/answer_keys/show`) : il montre chaque case avec ses réponses acceptées et l'indice ; l'entraînement de chaque notion est listé sous son exercice noté, titré « Je m'entraîne (non noté) ».

### 3.10 Accessibilité

- Cibles ≥ 48×48 px : cases, listes, boutons, `summary`.
- Chaque `fieldset` a sa `legend` (« Question n ») ; le texte autour des cases reste dans l'ordre de lecture.
- Le verdict se lit en mots, pas par la couleur seule. Le champ faux porte `aria-invalid` et `aria-describedby` vers son verdict.
- `aria-live="polite"` sur le message global uniquement, pas sur chaque case.
- Ordre de tabulation : cases de la question 1, son indice, cases de la question 2, …, « Vérifier », « Correction ».
- 390 px : les cases passent à la ligne avec leur texte (`flex-wrap`), jamais de défilement horizontal ; un `select` prend au plus 100 % de la largeur.

## 4. Conséquences

- La fiche de révision n'a plus 4 blocs fixes : elle en a 4 ou 5, selon la notion. Le libellé et la place du 5e ne varient pas.
- Une question à plusieurs cases se rend dans sa phrase partout : fiche, copie, résultat, corrigé. Le rendu d'une question à une case ne change pas.
- Interdit : mettre dans la page de la fiche une bonne réponse, un `correct`, une explication ou un indice de copie notée ; ajouter un contrôleur Stimulus pour l'entraînement ; afficher un « Entraînement illimité » ou un score de séance (grill 12).
