# UDR-0023 : Résultat de session — note, badge et correction, sans jamais montrer les bonnes réponses à l'élève

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) — *amendée le 2026-10-02 (proposé) par le chantier `interface-epuree`* |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot C3, critères AS-11 (affichage), AS-12, AS-13, AS-39 |
| **ADR lié** | [ADR-0028](../adr/0028-policies-de-domaine-par-use-case.md) (`ReadSessionPolicy`, `RevealAnswersPolicy`, `StartSessionPolicy`) · [ADR-0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) · [ADR-0054](../adr/0054-moteur-d-evaluation-soumission-et-cloture.md) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) · [UDR-0022](0022-session-d-exercice.md) |
| **Remplacé par** | — |

---

## 1. Contexte

À la fin d'une session, l'élève arrive sur son résultat (« Voir mon résultat », UDR-0022). Dans l'ancienne application :

- **le badge n'était jamais affiché** : la page lisait `@session.badge_level`, une colonne jamais écrite. Même à 100 %, l'élève voyait « :( » ;
- **ses choix n'étaient jamais surlignés** : `attempted_answer_ids` restait vide ;
- la page ne donnait que le pourcentage, sans note sur 20 ni maîtrise ;
- elle montrait à l'élève toutes les propositions, **les correctes en vert** ;
- seul l'élève y avait accès : l'enseignant ne pouvait pas relire la session d'un de ses élèves.

## 2. Décision

1. **Un résumé, puis la correction.** En tête, une carte centrée : le badge du palier atteint par **cette session** (`Grading.badge_for`), « Félicitations ! » dès `PASS_THRESHOLD`, « Courage ! » en dessous, puis la note sur 20, le score, la maîtrise et le nombre de questions justes. Sous la carte, la correction question par question, dans l'ordre des questions.
2. **« Nouveau badge ! »** quand le badge de l'élève sur l'exercice a été gagné par cette session (`exercise_badges.exercise_session_id`). Une session qui n'a pas amélioré le badge montre son palier, sans la mention.
3. **L'élève ne voit jamais les propositions correctes** (décision du porteur, 881a623 ; même règle que l'UDR-0022). Sa correction montre, pour chaque question, le verdict, **ses seuls choix** (« Ton choix ») et l'explication. `RevealAnswersPolicy` refuse l'élève ; la query ne lit alors que les propositions cochées, filtrées dans la base, et jamais la colonne `answers.correct`.
4. **L'enseignant d'une classe active de l'élève et l'équipe voient la correction complète** : toutes les propositions, la correcte marquée « Proposition correcte » (`bg-success-soft`), le choix erroné de l'élève marqué « Choix de l'élève » (`bg-error-soft`). Le nom de l'élève remplace la phrase d'encouragement. Tout autre lecteur reçoit 403.
5. **Confettis pendant 3 secondes**, pour l'élève propriétaire et dès `PASS_THRESHOLD` seulement : contrôleur Stimulus local, sans bibliothèque (Web Animations), éteint par `prefers-reduced-motion`.
6. **« Recommencer »** sous `PERFECT_THRESHOLD`, pour l'élève propriétaire quand l'exercice est encore ouvert (`StartSessionPolicy`) : POST `exercise_sessions_path`, qui change de page vers la nouvelle session ; l'ancienne reste terminée avec son score. Aucun stream : la page est en lecture seule.
7. **Les encouragements** reprennent la locale de gamification de l'ancienne application, choisis de façon stable par session. Deux phrases sont écartées : « Tu es un 10/10 ! », fausse pour un résultat partiel, et « Le BAC 2026 », datée.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- `assessment/session_results/show` : colonne `max-w-2xl` centrée ; lien « Fiche essentielle : nom » (`chevron-left`) vers `course_essential_path` ; `section#session_result` → `ui_card padding: :lg` centrée : `_badge`, `h1` (« Félicitations ! » ou « Courage ! »), encouragement (élève) ou « Session de Prénom Nom » (enseignant, équipe), « Exercice : titre » ; `dl` en 2 colonnes, 4 dès `sm` : Note (`grade_label`), Score (« N % »), Maîtrise (`mastery_label`), Questions justes (« N sur T ») ; actions : « Recommencer » (`brand`, `arrow-path`, formulaire `#restart-exercise-form`) et « Revoir l'exercice » (`secondary`, `book-open`), empilées sous `sm`. Puis `section#session_review` : `h2` « Correction question par question », une phrase d'aide selon le lecteur, `ol` `data-controller="math"`.
- `_badge` (`#session_badge`, `role="group"`) : médaillon `size-24 rounded-full border-4 border-white shadow-lift` aux couleurs du ton `badge_tone` (Bronze `warning`, Argent `neutral`, Or `gold`, Diamant `info`, aucun `neutral`), icône `trophy`, ou `lock-closed` sans palier ; nom du palier en capitales ; `ui_badge` `brand` « Nouveau badge ! » (`sparkles`) si `earned_now`.
- `_question_review` (`li#question_review_<id>`) : `ui_card padding: :none` ; bandeau `bg-mist` « Question n » et `ui_badge` verdict (`success` « Bonne réponse », `error` « Mauvaise réponse », `neutral` « Sans réponse ») ; énoncé ; pour l'élève, « Ton choix » puis ses seules propositions en `border-ink bg-mist` ; pour l'enseignant et l'équipe, toutes les propositions : correcte `border-success bg-success-soft` + `data-correct`, choix erroné `border-error bg-error-soft`, choix de l'élève `data-selected` + « Choix de l'élève », autre `border-line text-mute` ; encadré `bg-info-soft` « Explication » (`light-bulb`) si l'explication existe.
- `assessment--confetti` : calque `#confetti` (`fixed inset-0 z-50 pointer-events-none`, `aria-hidden`), confettis `h-3 w-2` aux couleurs `brand`, `success`, `gold`, `teacher`, `team`, lancés des deux bords toutes les 150 ms pendant 3 s ; le calque disparaît quand le dernier est tombé. Aucun attribut `style`.

**Tokens**
- Uniquement les tokens `@theme` et les composants `ui_*` (UDR-0005) : `bg-mist`, `bg-success-soft`, `bg-error-soft`, `bg-info-soft`, `border-success`, `border-error`, `text-mute`, `rounded-ln`, `rounded-card`, `shadow-lift`, `min-h-tap`, `animate-slide-up`.

**Comportement**
- Lecture seule : aucun frame, aucun stream. « Recommencer » : Turbo Drive, redirection 303 vers la nouvelle session.
- Session inconnue : 404. Lecteur refusé par `ReadSessionPolicy` : 403 « Accès interdit. », sans rien montrer de la session. Session en cours : redirection vers la session ; abandonnée : la page de la session renvoie à l'exercice (UDR-0022).
- Aucun `cache` de vue : le HTML dépend du lecteur.

**États obligatoires**
- Réussite (≥ `PASS_THRESHOLD`) : « Félicitations ! », confettis, badge. Échec : « Courage ! », « Non acquis », « En difficulté », pas de confetti.
- Sans faute : Diamant, pas de « Recommencer ».
- Question sans tentative : « Sans réponse », aucune proposition.

**Accessibilité**
- Le badge est nommé en toutes lettres : `aria-label` « Badge Or », ou « Non acquis » (UDR-0007) ; le médaillon est décoratif.
- Le verdict ne repose pas sur la couleur seule : texte et icône ; « Proposition correcte » et « Choix de l'élève » sont écrits.
- Les confettis sont `aria-hidden`, ne captent aucun clic, et ne jouent pas sous `prefers-reduced-motion`.

## 4. Conséquences

- Le badge est enfin visible sur le résultat (non-régression AS-11) ; 9 sur 10 donne Or, jamais Diamant.
- Aucune vue destinée à l'élève ne contient le texte d'une proposition juste qu'il n'a pas choisie : un test du contrôleur le prouve, et un autre prouve que l'enseignant la voit marquée.
- Le fait `teaches_student` de `ReadSessionPolicy` est lu par la query du résultat (`teaches_student?`) : élève inscrit (`left_at` nul) dans une classe `active` que l'enseignant a déclarée. Un autre écran qui en aurait besoin la réutilise.
- Si le porteur retire l'explication de la correction de l'élève (question ouverte de l'UDR-0022), seul `_question_review` change.

## Amendement du 2026-09-29 — finitions d'interface

*Chantier [`docs/chantiers/finitions-ux`](../../chantiers/finitions-ux/prd.md), [UDR-0054](0054-finitions-d-interface.md). Statut : `Accepté` (avec l'UDR-0054, par le porteur le 2026-09-29). Le texte ci-dessus reste tel qu'il a été accepté ; cette section fait foi en cas d'écart.*

- Retour : `ui_back_link` vers `course_essential_path`, libellé = nom de la fiche (au lieu de « Fiche essentielle : <nom> »).
- Titre : « Résultat de <titre de l'exercice> · <espace> · Lnclass ».
- Badge : suivi d'une infobulle des seuils (UDR-0054 §3.4).

## Amendement du 2026-10-02 — épuration (UDR-0057) · Statut : Proposé

*Chantier [`interface-epuree`](../../chantiers/interface-epuree/memo.md), Lot C, [UDR-0057](0057-ecrans-eleve-epures.md). Statut : `Proposé`. Le Lot C ne code rien avant l'acceptation du porteur (plan, « Porte des lots C à F »). Une fois acceptée, cette section fait foi en cas d'écart avec le texte ci-dessus et l'amendement précédent.*

**Contexte.** L'UDR-0057 impose six règles (R1 à R6) à chaque écran élève. L'audit du 2026-10-02 relève un même résultat dit trois fois (note, score, questions justes), une aide permanente qui répète les cartes et une liste sans limite.

**Changements pour l'élève**

| Élément | Aujourd'hui | Après | Règle (R1–R6, Q4) | Où va l'information |
|---|---|---|---|---|
| « Score » du `dl` de `#session_result` | « 85 % » | Retiré. Clés `score` et `score_value` supprimées | R6 | La note sur 20 dit le même résultat (`Grading.grade_on_20` = score ÷ 5). C'est la forme unique de la note dans le parcours (UDR-0058 §3.3) |
| « Questions justes » du `dl` | « 9 sur 10 » | Retiré. Clés `correct` et `correct_value` supprimées | R6 | Même résultat que la note (`Grading.score_percent`). Le verdict de chaque question reste dans la correction, juste en dessous |
| `dl` du résumé | 4 termes, 2 colonnes puis 4 dès `sm` | 2 termes, « Note » puis « Maîtrise », en `grid-cols-2` à toutes les tailles | — | — |
| Aide `review_hint_student` sous « Correction question par question » | « Pour chaque question : ton choix, le verdict et l'explication. » | Retirée, sans infobulle. Clé supprimée. Le `h2` reste seul | R4, R6 | Chaque carte affiche déjà « Ton choix », le verdict et l'explication : la phrase les énumère |
| Liste `ol` de `#session_review` (élève propriétaire) | Toutes les questions | 3 cartes visibles, les suivantes rendues mais masquées (`hidden`), puis « Voir plus » | R3 | Les cartes suivantes sont déjà dans la page. « Voir plus » les révèle par 3, sans requête, dans l'ordre des questions |

**« Voir plus » de la correction (élève propriétaire seulement)**
- Même motif que l'[UDR-0021](0021-page-exercice.md), amendement du 2026-10-02, avec `@owner` comme condition.
- Si `@owner` : `section#session_review` porte `data-controller="reveal"` et `data-reveal-step-value="3"`. `_question_review` reçoit déjà `owner:` : son `li` porte `data-reveal-target="item"`, et `hidden` à partir de la quatrième question.
- Après l'`ol`, s'il y a plus de 3 questions : `ui_button` « Voir plus » (`ghost`, `full: true`, `data-reveal-target="button"`), puis `p.sr-only[aria-live=polite][data-reveal-target=status]` (contrat du Lot 0).
- `data-controller="math"` reste sur l'`ol` : KaTeX rend aussi les cartes masquées.

**Contrôle R1 à R6 (vue de l'élève propriétaire)**
- **R1** — Conforme aujourd'hui. « Recommencer » (`brand`) est la seule action principale ; « Revoir l'exercice » est `secondary`. Sans faute, il n'y a pas de « Recommencer ». « Voir plus » est `ghost`.
- **R2** — Conforme aujourd'hui. Trois blocs : lien retour, `#session_result`, `#session_review`.
- **R3** — Change : 3 cartes de correction, puis « Voir plus ».
- **R4** — Change : `review_hint_student` disparaît. Badge et maîtrise gardent leur infobulle des seuils.
- **R5** — Conforme aujourd'hui. Accent `brand` (« Recommencer », « Nouveau badge ! »). `success` et `error` signalent le verdict. Le ton du médaillon code le palier, qui est écrit en toutes lettres (UDR-0007). Les confettis sont un calque décoratif de 3 s, `aria-hidden`, sans information : ils gardent leurs couleurs.
- **R6** — Change : la note n'a plus qu'une forme, sur 20. Restent distincts, et donc affichés : le titre (« Félicitations ! » ou « Courage ! », seuil de réussite), le palier du badge et la maîtrise (seuils de l'ADR-0033). Le verdict de chaque carte garde texte, icône et couleur (accessibilité).

**Inchangé pour l'enseignant et l'équipe**
- « Session de Prénom Nom » à la place de l'encouragement.
- Aide `review_hint_reveal` visible, correction complète (« Proposition correcte », « Choix de l'élève »), sans « Voir plus ».
- Seuls « Score » et « Questions justes » disparaissent pour eux aussi : ce sont de simples répétitions de la note (R6).

**Vérification**
- `test/system/assessment/session_result_test.rb` : le `dl` a « Note » et « Maîtrise » seulement ; l'élève voit 3 cartes puis « Voir plus » ; `assert_single_primary_action` et `assert_blocks_above_fold(max: 5)` à 390 px ; l'enseignant voit toutes les cartes et `review_hint_reveal`.
- `test/system/boucle_pedagogique_test.rb` (ligne 350, `review_hint_reveal`) reste vert.
