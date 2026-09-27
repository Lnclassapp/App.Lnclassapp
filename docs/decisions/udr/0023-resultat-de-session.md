# UDR-0023 : Résultat de session — note, badge et correction, sans jamais montrer les bonnes réponses à l'élève

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
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
