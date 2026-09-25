# UDR-0022 : Session d'exercice — une question à la fois, un verdict après chaque réponse, sans rechargement de page

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot C2, critères AS-07 à AS-11, sécurité n° 30 |
| **ADR lié** | [ADR-0028](../adr/0028-policies-de-domaine-par-use-case.md) (`StartSessionPolicy`, `SubmitAttemptPolicy`, `ReadSessionPolicy`, `RevealAnswersPolicy`) · [ADR-0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) · [ADR-0043](../adr/0043-remediation-declenchee-par-la-cloture.md) · [ADR-0048](../adr/0048-statuts-d-assignation-active-et-archived.md) · [ADR-0054](../adr/0054-moteur-d-evaluation-soumission-et-cloture.md) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0006](0006-shell-applicatif-par-role.md) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) |
| **Remplacé par** | — |

---

## 1. Contexte

L'élève fait un exercice question par question. Dans l'ancienne application :

- **valider sans rien cocher donnait une erreur 500** : la réponse Turbo cherchait un partiel qui n'existait pas, et un `replace` aurait de toute façon effacé le frame et son message (C-10) ;
- **une question déjà répondue pouvait être soumise de nouveau** : le doublon faussait le score, clôturait la session trop tôt, et la ligne existante était écrasée — l'élève pouvait corriger sa réponse après avoir vu le corrigé (C-11). Une proposition d'une autre question et une session abandonnée étaient acceptées ;
- **l'ordre des propositions changeait à chaque affichage** (`shuffle` sans graine) ;
- la barre de progression recomptait les tentatives dans la vue, et s'appuyait sur un style en ligne.

## 2. Décision

1. **Une question à la fois, dans un frame `question`.** La page `/sessions/:public_id` montre le titre de l'exercice, la progression, puis la **première question sans tentative** (reprise, AS-08). Répondre remplace le frame par le **verdict** et la progression par la nouvelle valeur, **par Turbo Stream, sans rechargement de page**. « Question suivante » recharge seulement le frame.
2. **Le verdict ne dévoile jamais les propositions correctes.** Décision du porteur du 2026-09-25 (`RevealAnswersPolicy` du socle, commit `6772b58`) : l'élève ne voit jamais les bonnes réponses, pas même après sa tentative. La carte dit « Bonne réponse » ou « Mauvaise réponse » (verdict de la tentative enregistrée), rappelle les propositions **qu'il a cochées** (« Ton choix ») et affiche l'**explication** de la question quand elle existe. La query ne lit même pas la colonne `answers.correct`. *Écart assumé avec le texte de l'AS-10 (« les propositions correctes de cette question »), à confirmer par le porteur ; voir §4.*
3. **Radios ou cases à cocher selon le type** : Vrai/Faux et choix unique en boutons radio ; 2 ou 3 propositions correctes en cases à cocher, avec le badge « Plusieurs propositions correctes » et l'aide « Coche N propositions. ». Le nombre attendu est donné : c'est la règle de correction (ADR-0054), pas un indice.
4. **Ordre mélangé, stable par session** : graine `session_id ^ question_id`. Deux affichages de la même session montrent le même ordre ; deux sessions, en général non.
5. **Une réponse par question, garantie par la base.** Une re-soumission (double clic, second onglet, requête forgée) n'écrit rien : toast d'avertissement « Tu as déjà répondu à cette question. » (UDR-0007) et `turbo_stream.refresh`, qui ramène l'écran à l'état réel de la session. Même traitement pour une session terminée ou abandonnée (« Cette session est terminée. »).
6. **La dernière réponse clôt la session dans la même requête** (score, badge, lacune). Son verdict propose « Voir mon résultat » (page du Lot C3, `data-turbo-frame="_top"`) au lieu de « Question suivante ».
7. **Démarrer, reprendre, recommencer** changent de page (POST `exercise_sessions_path`, `restart=true` pour « Recommencer »), sans stream. Une session terminée ouverte par son URL mène au résultat ; une session abandonnée, à la page de l'exercice avec une alerte.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- `assessment/exercise_sessions/show` : colonne `max-w-2xl` centrée ; lien « Quitter la session » (`chevron-left`) vers `exercise_path` ; `h1` titre de l'exercice ; `_progress_bar` ; `_question_card`. Pas de `nav_key` : l'élève est dans une tâche.
- `_progress_bar` (`#progress_bar`) : « N question(s) répondue(s) sur T » et « P % », puis `<progress value max="100">` natif, `accent-brand`, `aria-label` « Progression de la session ». Aucun attribut `style`.
- `_question_card` : `turbo_frame_tag "question"` → `ui_card padding: :none` `#question-card` : bandeau `bg-mist` « Question n sur T » + badge `info` « Plusieurs propositions correctes » si plusieurs ; `form_with scope: :attempt` `#attempt-form` vers `exercise_session_attempts_path`, `data-controller="math"` (KaTeX) ; champ caché `question_id` ; `fieldset` dont la `legend` est l'énoncé ; aide ; une `label` par proposition (`min-h-tap`, `rounded-ln`, `has-checked:border-brand has-checked:bg-brand-soft`) contenant la radio ou la case `attempt[answer_ids][]` ; erreur `#attempt-errors` `role="alert"` `bg-error-soft` ; bouton « Valider » (`arrow-right`).
- `_feedback_card` : `turbo_frame_tag "question"` → `ui_card` `#feedback-card` : bandeau `role="status"` `bg-success-soft` / `bg-error-soft`, icône `check-circle` / `x-circle`, verdict et une phrase d'encouragement ; énoncé ; liste des propositions, celles cochées en `border-ink bg-mist` avec le badge « Ton choix », les autres en `text-mute` ; encadré `bg-info-soft` « Explication » (`light-bulb`) si l'explication existe ; pied : « Question suivante » (lien dans le frame) ou « Voir mon résultat » (`brand`, `trophy`, `_top`).
- `assessment/question_attempts/create.turbo_stream.erb` : `replace "question"` par `_feedback_card`, `replace "progress_bar"`.

**Tokens**
- Uniquement les tokens `@theme` et les composants `ui_*` (UDR-0005) : `bg-mist`, `bg-brand-soft`, `bg-success-soft`, `bg-error-soft`, `bg-info-soft`, `text-mute`, `rounded-ln`, `rounded-card`, `min-h-tap`.

**Comportement**
- Frame `question` ; stream du `create` (verdict et progression) ; réponse vide ou sélection mal formée : `replace "question"` par la carte avec son erreur, **statut 422**, jamais 500 ; doublon ou session close : toast `warning` + `turbo_stream.refresh(request_id: nil)`.
- Repli HTML : succès → redirection vers la session, verdict en flash ; erreur → page de session complète en 422 ; doublon → redirection avec alerte.
- Contrôleurs réservés à l'élève (`allow_roles :student`) ; la page d'une session d'un autre élève répond 403 sans rien en montrer ; un brouillon, 404.

**États obligatoires**
- Erreur : « Sélectionne au moins une proposition. » · « Coche le nombre de propositions demandé, parmi celles de la question. » · « Tu as déjà répondu à cette question. » · « Cette session est terminée. »
- Succès : « Bonne réponse » / « Mauvaise réponse ».

**Accessibilité**
- Cibles ≥ 48 px (`min-h-tap`) sur chaque proposition, toute la ligne cliquable.
- L'énoncé est la `legend` du groupe ; l'erreur est reliée par `aria-describedby` et annoncée (`role="alert"`) ; le verdict est annoncé (`role="status"`).
- Le verdict ne repose pas sur la couleur seule : texte et icône.

## 4. Conséquences

- Plus aucune correction d'une question ne se rejoue : la tentative est immuable (ADR-0054). L'élève qui s'est trompé passe à la suite, puis recommence l'exercice.
- **Point à confirmer par le porteur** : l'AS-10 du PRD et le plan (C2, `last_feedback`) prévoyaient d'afficher les propositions correctes de la question tentée, et l'amendement de l'ADR-0028 l'autorisait. La décision plus récente du porteur, appliquée par le socle, l'interdit. Si le porteur rouvre ce point, seules la query (`last_feedback`) et `_feedback_card` changent.
- L'explication reste affichée : c'est un texte pédagogique rédigé par l'équipe, pas une marque de proposition correcte. L'équipe veille à ce qu'elle explique sans recopier la bonne proposition, si le porteur le souhaite.
