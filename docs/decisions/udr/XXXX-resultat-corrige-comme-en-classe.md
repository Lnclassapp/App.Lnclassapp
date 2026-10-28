# UDR-XXXX : Résultat d'une copie corrigé comme en classe — appréciation, « À revoir », bonnes réponses, pause de « Recommencer »
<!-- index
titre: Résultat corrigé comme en classe
statut: Accepté
adr-lie: XXXX-correction-complete-et-pause-de-recommencer
problematique: Donner à l'élève, après sa copie, ce que donnerait un enseignant : bonne réponse, appréciation et ce qu'il doit revoir
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-28 |
| **Chantier** | `docs/chantiers/correction-comme-en-classe` |
| **ADR lié** | ADR-XXXX-correction-complete-et-pause-de-recommencer |
| **Remplace** | UDR-0023, sur le seul point « sans jamais montrer les bonnes réponses à l'élève » ; UDR-0087 §3.6, sur le seul titre « Félicitations ! » / « Courage ! » |
| **Remplacé par** | — |

---

## 1. Contexte

Après « Rendre ma copie », l'élève lit sa note, « Félicitations ! » ou « Courage ! » et une phrase tirée au hasard, puis une
correction qui montre son choix et l'explication, jamais la bonne réponse. Quand l'explication ne suffit pas, il ne sait
pas ce qu'il aurait fallu répondre. Rien ne lui dit non plus ce qu'il doit revoir. Un enseignant, lui, rendrait la copie
corrigée avec une appréciation.

## 2. Décision

- **Le titre du résultat devient l'appréciation** : « Très bien », « Bien », « Assez bien » ou « À retravailler », selon la
  note sur 20 affichée.
  - Un seul mot d'ordre, celui d'un bulletin.
  - « Félicitations ! » et « Courage ! » disparaissent : à 12 ou 13/20, « Courage ! » contredisait « Bien ».
- **Une ligne « À revoir » sous la phrase d'encouragement** nomme la notion (exercice de notion) ou renvoie à la leçon
  (exercice de toute la leçon), avec les numéros des questions en cause. C'est une ligne de texte, pas une carte : elle suit
  l'appréciation comme la remarque suit la note en marge d'une copie.
- **La correction montre la bonne réponse à l'élève**, avec le rendu que l'enseignant a déjà (`reveal`). Seul change le
  libellé du choix de l'élève : « Ton choix » pour lui, « Choix de l'élève » pour l'enseignant. Une mauvaise réponse n'est
  jamais en rouge pour l'élève (UDR-0087 §3.5) : son choix faux prend le ton `warning`.
- **Pendant la pause**, le bouton « Refaire l'exercice » laisse sa place à une phrase qui donne l'heure du retour, sur le
  résultat comme sur la page de l'exercice. Pas de compte à rebours animé : l'heure suffit et ne demande aucun JavaScript.

## 3. Règles d'implémentation

**Structure — `assessment/session_results/show`** (seuls les blocs changés ; le reste suit l'UDR-0087 §3.6 et l'UDR-0138 §3.4)

1. `h1#session_result_title` : `t(".appreciation.#{level}")`, avec `level` ∈ `very_good`, `good`, `fair`, `rework`. Il est calculé par
   `Entities::Assessment::Appreciation` sur `Grading.grade_on_20(score_percent)` :

   | Note sur 20 affichée | `level` | Texte |
   |---|---|---|
   | ≥ 16 | `very_good` | « Très bien » |
   | 12 à 15 | `good` | « Bien » |
   | 10 et 11 | `fair` | « Assez bien » |
   | ≤ 9 | `rework` | « À retravailler » |

   Mêmes classes qu'aujourd'hui (`font-display text-3xl font-medium tracking-tight`). Il est lu par l'élève **et** par
   l'enseignant ou l'équipe.
2. La phrase d'encouragement (`t(".cheers.#{tone}")`), **élève seul**, inchangée. `tone` garde le seuil de 14/20
   (`MASTERY_THRESHOLD`), comme la couleur de la note et les confettis.
3. `p#session_to_review`, juste sous la phrase d'encouragement (sous le nom de l'élève pour l'enseignant). Classes :
   `text-sm text-ink text-balance`. Elle est **absente** quand aucune question n'est en cause (fausse ou sans réponse). Son
   texte :
   - exercice de notion : `t(".to_review.essential_html", essential: lien, questions:)`, soit « À revoir : « Calculer une longueur », questions 2 et 4 ». Le lien porte le nom de la notion et mène à `course_path(slug, anchor: "notion-<slug>")` ;
   - exercice de toute la leçon : `t(".to_review.lesson_html", lesson: lien, questions:)`, soit « À revoir dans la leçon : question 3 ». Le lien porte le mot « la leçon » et mène à `course_path(slug, anchor: "toute-la-lecon")` ;
   - `questions` : `t(".to_review.questions", count:, list:)`, avec `list` = `to_sentence` des numéros (« 2, 3 et 7 »). La forme est « question 3 » au singulier, « questions 2 et 4 » au pluriel.
   Les liens sont en `font-medium text-brand underline underline-offset-2`.
4. `section#session_review` : `h2` « Correction question par question » inchangé. La phrase d'aide :
   - élève : « Pour chaque question : ton choix, la bonne réponse et l'explication. » (`review_hint_student`, réécrite) ;
   - enseignant ou équipe : inchangée (`review_hint_reveal`).
5. Le pied de la colonne de gauche, élève seul, garde la logique d'aujourd'hui (rien au sans-faute), avec un cas de plus :
   - pas de pause : le formulaire `#restart-exercise-form` et « Refaire l'exercice », inchangés ;
   - en pause : `p#restart_paused` à la place du formulaire. Texte : « Tu as rendu 3 copies d'affilée. Tu pourras recommencer à %{time}. », avec `time` = `l(paused_until, format: :hour_minute)`, soit « 21 h 14 ». Classes : `rounded-ln bg-mist px-4 py-3 text-center text-sm text-ink`. Icône `clock` (`ui_icon`, `variant: :mini`, `aria-hidden`) avant le texte.
   - « Retour à la leçon » reste en dessous dans les deux cas.

**Structure — la correction d'une question (`_question_review`, `kinds/*_review`)**

- `reveal` vaut vrai pour l'élève auteur d'une copie rendue (`RevealCorrectionPolicy`), comme pour l'enseignant. Les cinq partials de type affichent déjà, avec `reveal`, les propositions correctes, les réponses acceptées, la valeur attendue, le bon ordre et les bonnes paires : aucune autre structure ne change.
- Nouveau local `owner:` passé de `_question_review` aux partials de type.
- `kinds/_choice_review`, avec `reveal` :
  - le badge du choix est `t("…question_review.selected")` (« Ton choix ») quand `owner`, sinon `student_choice` ;
  - une proposition choisie et fausse prend `border-warning bg-warning-soft` et l'icône `x-circle` en `text-warning` quand `owner` ; l'enseignant garde `border-error bg-error-soft`.
- Question sans réponse : rien à la place de « Ton choix » (inchangé), mais la bonne réponse et l'explication s'affichent.
- Les commentaires d'en-tête des partials « avec reveal seulement (enseignant, équipe) » deviennent « avec reveal (enseignant, équipe, élève auteur d'une copie rendue) ».

**Structure — `assessment/exercises/show`, pied `#exercise_actions` (élève)**

- Sans copie en cours et en pause : `p#restart_paused`, même texte et mêmes classes qu'au résultat, à la place du formulaire `#start-exercise-form`. La ligne `#exercise_best` (meilleure note) reste en dessous.
- Une copie en cours ne peut pas coexister avec une pause : « Reprendre » et « Recommencer » restent tels quels.

**Alerte après un démarrage refusé**

- `ExerciseSessionsController#create` sur `:conflict` / `base: [:paused]` : 303 vers `exercise_path(public_id)`, `alert: t(".paused")`. Texte : « Tu as rendu 3 copies d'affilée. Attends la fin de la pause pour recommencer. ». La page de l'exercice donne l'heure.

**Tokens**
- Couleurs : `ink`, `mute`, `mist`, `brand`, `warning`, `warning-soft`, `success`, `success-soft`, `error`, `error-soft`. Jamais de valeur en dur.
- Typographie : `font-display` pour le titre seul ; tout le reste en texte courant `text-sm`.
- Espacements et rayons : `rounded-ln`, `px-4 py-3` ; la ligne « À revoir » suit la phrase d'encouragement dans le même `div.space-y-2`.

**Comportement**
- Aucun Turbo Frame ni Stream : la page est en lecture seule et se charge en entier. La pause se lit au chargement. Une fois l'heure passée, recharger la page rend le bouton.
- Stimulus : `assessment--confetti` et `reveal` inchangés. La correction reste masquée à partir de la 4e question (« Voir plus ») pour l'élève.
- `data-controller="math"` reste sur la liste de la correction : les bonnes réponses passent par KaTeX comme le reste.

**États obligatoires**
- **Vide** : sans question en cause, pas de `#session_to_review`. Un exercice sans question n'a pas de résultat (inchangé).
- **Chargement** : aucun, rendu serveur.
- **Erreur** :
  - une copie abandonnée ou en cours n'a pas de résultat (redirection inchangée) ;
  - le démarrage refusé pendant la pause donne l'alerte décrite plus haut.
- **Succès** : le titre-appréciation, la phrase d'encouragement (élève), « À revoir » s'il y a lieu, la correction complète ; puis « Refaire l'exercice » ou la pause.

**Accessibilité**
- `#session_result_title` reste le `h1`, et `section#session_result` garde son `aria-labelledby`.
- `#session_to_review` est un simple `p`. Ses liens ont un nom accessible complet (le nom de la notion, ou « la leçon »).
- `#restart_paused` porte `role="status"`. L'icône `clock` est `aria-hidden`. L'heure s'écrit en toutes lettres (« 21 h 14 »).
- Les verdicts restent écrits en texte avec une icône, jamais par la couleur seule (UDR-0087 §3.5).
- Les liens « À revoir » ont une cible d'au moins 48 px de haut (`inline-flex min-h-tap items-center`).

## 4. Conséquences

- UDR-0023 ne vaut plus pour la règle « jamais les bonnes réponses à l'élève » : sur une copie rendue, il les voit.
- UDR-0087 §3.6 ne vaut plus pour le titre « Félicitations ! / Courage ! ». Son seuil de 14/20 reste celui de la couleur de
  la note, des confettis et de la phrase d'encouragement.
- La page de l'exercice ne montre toujours aucune bonne réponse à l'élève (`RevealAnswersPolicy`, inchangée).
- Interdit désormais :
  - une bonne réponse montrée à l'élève hors d'un résultat de copie rendue ;
  - un titre de résultat qui ne soit pas l'appréciation.
