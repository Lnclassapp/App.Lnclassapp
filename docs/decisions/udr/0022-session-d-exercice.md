# UDR-0022 : Session d'exercice — une question à la fois, un verdict après chaque réponse, sans rechargement de page
<!-- index
titre: Session d'exercice
statut: Accepté — *amendé le 2026-10-02 : épuration élève (UDR-0057)*
adr-lie: [0028](../adr/0028-policies-de-domaine-par-use-case.md), [0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md), [0043](../adr/0043-remediation-declenchee-par-la-cloture.md), [0048](../adr/0048-statuts-d-assignation-active-et-archived.md), [0054](../adr/0054-moteur-d-evaluation-soumission-et-cloture.md)
problematique: Une question à la fois, un verdict après chaque réponse, sans rechargement de page
-->

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) — *amendée le 2026-10-02 (acceptée par le porteur) par le chantier `interface-epuree`* |
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
2. **Le verdict ne dévoile jamais les propositions correctes.** Décision du porteur du 2026-09-25 (`RevealAnswersPolicy` du socle, commit `6772b58`) : l'élève ne voit jamais les bonnes réponses, pas même après sa tentative. La carte dit « Bonne réponse » ou « Mauvaise réponse » (verdict lu dans `question_attempts.correct`), montre **les seules propositions qu'il a cochées** (« Ton choix »), sans dire lesquelles sont justes, et affiche l'**explication** de la question quand elle existe. Les autres propositions de la question ne sont pas listées : une proposition juste que l'élève n'a pas choisie n'apparaît ni dans la carte ni dans la réponse Turbo Stream. La query filtre les propositions cochées dans la base et ne lit jamais la colonne `answers.correct`. *Écart avec le plan (C2, `last_feedback`) et l'AS-10 (« les propositions correctes de cette question »), validé par le team-lead le 2026-09-25 ; voir §4.*
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
- `_feedback_card` : `turbo_frame_tag "question"` → `ui_card` `#feedback-card` : bandeau `role="status"` `bg-success-soft` / `bg-error-soft`, icône `check-circle` / `x-circle`, verdict et une phrase d'encouragement ; énoncé ; intitulé « Ton choix », puis la liste des **seules propositions cochées**, en `border-ink bg-mist` (`aria-labelledby` vers l'intitulé) ; encadré `bg-info-soft` « Explication » (`light-bulb`) si l'explication existe ; pied : « Question suivante » (lien dans le frame) ou « Voir mon résultat » (`brand`, `trophy`, `_top`).
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
- **Écart avec le plan et l'AS-10** : l'AS-10 du PRD et le plan (C2, `last_feedback`) prévoyaient d'afficher les propositions correctes de la question tentée, et l'amendement de l'ADR-0028 l'autorisait. La décision plus récente du porteur (`6772b58`) l'interdit ; le team-lead a validé la carte ci-dessus le 2026-09-25 et corrige le PRD et le plan au socle. Si le porteur rouvre ce point, seules la query (`last_feedback`) et `_feedback_card` changent.
- L'explication reste affichée : la décision du porteur porte sur les bonnes réponses seulement, et l'explication est un contenu pédagogique rédigé par l'équipe. Le team-lead pose la question au porteur ; s'il veut la retirer, ce sera une petite suite (`_feedback_card` seulement).
- Un test du contrôleur le prouve : ni la carte ni la réponse Turbo Stream ne contiennent le texte d'une proposition juste non choisie (choix unique, et deux propositions correctes dont une seule trouvée).

## Amendement du 2026-10-02 — épuration (UDR-0057) · Statut : Accepté (2026-10-02, porteur)

> **Décision du porteur (2026-10-02)** : amendement accepté.

*Chantier [`interface-epuree`](../../chantiers/interface-epuree/memo.md), Lot C, [UDR-0057](0057-ecrans-eleve-epures.md). Statut : `Accepté` (porteur, 2026-10-02). Le Lot C ne code rien avant l'acceptation du porteur (plan, « Porte des lots C à F »). Une fois acceptée, cette section fait foi en cas d'écart avec le texte ci-dessus.*

**Contexte.** L'UDR-0057 impose six règles (R1 à R6) à chaque écran élève. Cet écran n'est ouvert qu'à l'élève (`allow_roles :student`). L'audit du 2026-10-02 relève un avancement dit trois fois, un nombre de propositions dit deux fois et deux consignes inutiles.

**Changements pour l'élève**

| Élément | Aujourd'hui | Après | Règle (R1–R6, Q4) | Où va l'information |
|---|---|---|---|---|
| Ligne de texte de `_progress_bar` | « N questions répondues sur T » à gauche, « P % » à droite, au-dessus de la barre | Ligne retirée. `div#progress_bar` ne contient plus que le `<progress>` (`value`, `max="100"`, `aria-label` « Progression de la session », contenu de repli « P % »). Clé `progress_bar.answered` supprimée | R6 | Le bandeau de la carte dit « Question n sur T ». La barre montre l'avancée. Les lecteurs d'écran lisent la valeur du `<progress>` |
| Badge `info` « Plusieurs propositions correctes » du bandeau de `_question_card` | À côté de « Question n sur T » | Retiré. Clé `question_card.multiple` supprimée | R6 | La consigne « Coche N propositions. », sous l'énoncé, le dit déjà, avec le nombre |
| Consigne `hint` d'une question à une seule réponse (Vrai/Faux, choix unique) | « Choisis une proposition. » sous l'énoncé | Non rendue. La consigne n'est rendue que si `question.multiple?`. Clé : `hint: "Coche %{count} propositions."` ; `hint.one` supprimée | R4 | Les boutons radio ne laissent cocher qu'une proposition : le champ porte la consigne |
| Consigne `hint` d'une question à plusieurs réponses | « Coche N propositions. » | Inchangée | — (R4 ne s'applique pas) | C'est la règle de correction (§2.3, ADR-0054), pas une aide : sans elle, l'élève ne peut pas répondre juste |
| Encouragement `feedback_card.encouragement.error` | « Ce n'est pas grave : lis l'explication, puis continue. » | « Ce n'est pas grave, continue. » | R4 | L'encadré « Explication » est juste en dessous, quand il existe. La phrase ne renvoie plus à un encadré parfois absent |

**Contrôle R1 à R6**
- **R1** — Conforme aujourd'hui. Carte de question : « Valider » (`primary`) seul. Verdict : « Question suivante » (`primary`) ou « Voir mon résultat » (`brand`), jamais les deux. « Quitter la session » est le lien retour.
- **R2** — Conforme aujourd'hui. Trois blocs : lien retour, `header` (titre et barre), frame `question`.
- **R3** — Conforme aujourd'hui, sans objet. Les propositions sont les choix d'un champ de formulaire : elles restent toutes visibles, car en masquer une changerait la question. « Ton choix » liste 1 à 3 propositions.
- **R4** — Change : la consigne « Choisis une proposition. » disparaît, l'encouragement d'erreur ne donne plus de consigne. « Coche N propositions. » reste (règle de correction).
- **R5** — Conforme aujourd'hui. Accent `brand` (sélection, radios, cases, « Voir mon résultat »). `info` (explication) est la nuance `brand-strong` / `brand-soft` (UDR-0005). `success` et `error` signalent le verdict.
- **R6** — Change : l'avancement n'est dit qu'une fois (« Question n sur T »), le nombre de propositions aussi. Le verdict garde texte, icône et couleur : c'est une raison d'accessibilité (§3, « Accessibilité »).

**Inchangé pour l'enseignant et l'équipe**
- Rien ne change pour eux : cet écran leur est fermé (`allow_roles :student`). Le stream `question_attempts/create` remplace toujours `question` et `progress_bar`.

**Vérification**
- `test/system/assessment/exercise_session_test.rb` : la ligne 53 lit désormais la valeur du `<progress>` ; une question à choix unique n'a pas de consigne ; une question à plusieurs réponses a « Coche N propositions. » et aucun badge « Plusieurs propositions correctes » ; `assert_single_primary_action` et `assert_blocks_above_fold(max: 5)` à 390 px.
- `test/controllers/assessment/exercise_sessions_controller_test.rb` : la ligne 33 lit la valeur du `<progress>`, plus le texte « N questions répondues sur T ».

## Amendement du 2026-10-05 — question suivante sans requête · Statut : Proposé

*Chantier [`interface-eleve-organisation`](../../chantiers/interface-eleve-organisation/memo.md), [UDR-0076](0076-organisation-des-ecrans-eleve.md) §3.3, en application de l'[ADR-0076](../adr/0076-politique-de-cache-reglee-sur-les-allers-retours.md). Cette section fait foi sur le §2.1 en cas d'écart, une fois acceptée.*

- Le stream d'une réponse joint la question suivante dans un `<template>` du frame `question`. « Question suivante » l'affiche sans requête (contrôleur `assessment--next-question`) et donne le focus à son énoncé ; sans JavaScript, le lien recharge le frame comme avant.
- Aucun cache : ni fragment, ni ETag. La question jointe ne porte aucune proposition correcte.
