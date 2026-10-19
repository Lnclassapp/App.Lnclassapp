# Memo — La note sur 20 décide partout

| | |
|---|---|
| **Type de cycle** | feature (règle métier + textes d'écran) |
| **Statut** | PR prête vers `Develop` (2026-10-19) |
| **Ouvert le** | 2026-10-19 |
| **Branche** | `feature/note-sur-20-partout` |
| **Programme** | — |

---

## Le problème

L'élève lit une note sur 20, arrondie une seule fois par `Grading.grade_on_20` (`(score / 5.0).round`). Mais les règles qui décident d'un badge, d'une maîtrise, d'une réussite ou d'un « à revoir » comparaient encore le pourcentage brut à un seuil (50, 70, 80). Un élève à 68 % lit **14/20** en vert, et reçoit pourtant « Fragile » et un badge Bronze ; un élève à 48 % lit **10/20** et « En difficulté ». L'écran se contredit lui-même.

Le porteur a tranché le 2026-10-19 (« Oui, partout ») : la note affichée décide partout. La PR 256 l'a appliqué à `GapDecision` (ADR-0101 §4.5), dont la dernière phrase laissait les autres règles « sur le pourcentage brut ». Ce chantier solde ce reste.

## Pour qui

L'élève (badge, maîtrise, couleur, aide), l'enseignant (compréhension de l'exercice, réussite de la classe sur la fiche).

## Pourquoi maintenant

La décision du porteur est prise ; tant que les règles divergent, deux lectures d'un même 68 % coexistent à l'écran.

## Inventaire des endroits qui comparent un score à un seuil

Relevé par `git grep -n "PASS_THRESHOLD\|REMEDIATION_THRESHOLD\|_THRESHOLD\|>= 50\|>= 75\|score_percent"` dans `app/`, puis trié. Les numéros de ligne sont ceux de `origin/Develop` avant le chantier.

### Alignés (décision lue sur la note affichée)

| Règle | Endroit | Avant | Après |
|---|---|---|---|
| Badge Bronze / Argent / Or | `app/domain/entities/assessment/grading.rb:18` (`badge_for`) | `score >= 50 / 70 / 80` | `reaches?(score, seuil)` : dès 48 %, 68 %, 78 % (10, 14, 16/20) |
| Maîtrise (Acquis / Fragile) | `grading.rb:35-36` (`mastery_for`) | `>= 70`, `>= 50` | `reaches?` : dès 68 %, 48 % |
| « Sans évolution » : stable ou stagne | `app/domain/entities/assessment/comprehension.rb:24` (`trend_for`) | `best >= MASTERY_THRESHOLD` | `reaches?(best, MASTERY_THRESHOLD)` |
| « À revoir » d'une question | `comprehension.rb:36` (`to_revisit?`) | `rate < 50` | `!reaches?(rate, PASS_THRESHOLD)` : 48 % n'est plus à revoir |
| Taux de réussite de la classe sur une fiche | `app/infrastructure/queries/classroom/classroom_essential_query.rb:69` (`success`) | `best >= 50` | `reaches?(best, PASS_THRESHOLD)` |
| Lacune (déjà fait par la PR 256) | `app/domain/entities/assessment/gap_decision.rb:13-16` | notes comparées à la main | `reaches?` : même comportement, l'arrondi n'est plus recopié |
| Catégories de compréhension (élèves, points des questions, résumé de la classe) | `comprehension.rb:14` (`category_for`), `comprehension_summary_query.rb:21`, `exercise_progress_query.rb:28`, `session_result_query.rb:66`, `app/views/assessment/comprehension/_section.html.erb:81` | via `mastery_for` ou `badge_for` | alignés sans y toucher |

### Déjà sur la note affichée, ramenés à `reaches?` (sans changement de comportement)

Des vues recopiaient `grade_on_20(score) >= grade_on_20(MASTERY_THRESHOLD)`, voire un `>= 14` en dur : `assessment/exercises/_student_progress.html.erb:16`, `assessment/session_results/show.html.erb:8`, `classroom/student_archives/_result_row.html.erb:18`, `classroom/student_homes/_recent_activity.html.erb:27`, `classroom/student_classrooms/_treated_exercise.html.erb:8` (le `14` en dur). Elles appellent maintenant `Grading.reaches?` : l'arrondi n'existe plus qu'à un endroit.

### Textes qui citaient un pourcentage de seuil (l'écran change)

| Texte | Endroit | Avant | Après |
|---|---|---|---|
| Infobulle « Badge » | `config/locales/shared/layouts.fr.yml:26` | « Bronze à partir de 50 %… » | « Bronze dès 10/20, Argent dès 14/20, Or dès 16/20, Diamant : toutes les réponses justes » |
| Infobulle « Maîtrise » | `layouts.fr.yml:27` | « Acquis : 70 % et plus… » | « Acquis : 14/20 et plus. Fragile : de 10 à 13/20… » |
| FAQ « Comment gagner un badge ? », « Maîtrise » | `config/locales/communication/help.fr.yml:33,36` | pourcentages | notes sur 20 |

### Laissés tels quels, et pourquoi

| Endroit | Pourquoi |
|---|---|
| Diamant (`PERFECT_THRESHOLD` ; bouton « Recommencer » de `session_results/show.html.erb:72`) | Le Diamant n'est pas une note, c'est le **sans-faute** (ADR-0033 : « toutes les réponses justes »). `score_percent` est une division entière arrondie vers le bas : il ne vaut 100 que si tout est juste. Lu sur 20, 98 % s'afficherait 20/20 et donnerait un « sans-faute » faux (possible dès 50 questions). Il reste un fait, exposé par `Grading.perfect?`. |
| `Comprehension::PROGRESS_MARGIN` (10 points d'écart entre deux sessions) | Une différence entre deux scores, pas un seuil de réussite. |
| `REMEDIATION_THRESHOLD` (75) | Déjà lu sur la note par `GapDecision` (PR 256). |
| Moyennes : `teacher_home_query.rb:63-66`, `team_dashboard_query.rb:137` (« Réussite moyenne »), `student_work_query.rb:53`, `departed_students_query.rb:29` | Des statistiques (somme / nombre), pas des décisions : aucun score n'y est comparé à un seuil. Arrondir chaque note avant de moyenner changerait la moyenne sans rien décider. |
| `ClassroomEssentialQuery` : `success_percent` (part des élèves en réussite) | Une part d'élèves, arrondie pour l'affichage. C'est le **comptage** `passed_students_count` qui change (via `reaches?`), pas l'arrondi de la part. |
| `Entities::School::WorkSignal` (vert dès 70 %, jaune dès 40 %) | Un taux de **rendu** de devoirs, pas un score : aucune note sur 20 derrière. |
| Taux de bonnes réponses d'une question (`rate`), son affichage | Pas une note affichée sur 20. Seule la règle « à revoir » le compare au seuil, et le porteur l'a demandée (`to_revisit?`). |
| Calcul de la note elle-même et son arrondi | Hors périmètre (consigne du porteur). |

## Hors périmètre

- Changer `grade_on_20`, son arrondi, ou la note affichée.
- Changer la valeur d'un seuil (50, 70, 75, 80, 100).
- Recalculer les badges déjà décernés (voir le grill).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le Diamant suit-il la règle ? | Non : c'est un fait (aucune faute), pas un seuil sur un score. 98 % = 20/20 n'est pas un sans-faute. | `Grading.perfect?` explicite, test à 98 / 99 / 100 ; consigne notée dans l'ADR. |
| Les textes « Bronze à partir de 50 % » restent-ils vrais ? | Non : Bronze s'obtient dès 48 %. Un texte faux est pire qu'un texte absent. | Les textes se lisent sur 20, calculés depuis `Grading` (jamais recopiés). UDR-0128. |
| Les badges déjà décernés ? | Un badge s'écrit à la clôture et ne descend jamais. Aucun recalcul : un élève à 48 %, 68 % ou 78 % déjà clôturé garde son palier d'avant ; la prochaine session appliquera la règle. | Aucune migration ; noté dans l'ADR (conséquences). |
| Une moyenne de classe est-elle une décision ? | Non, une statistique. | Gardées telles quelles, raison ci-dessus. |
| Le point de couleur des questions de compréhension (`mastery_for(question.rate)`) suit-il ? | Oui, c'est la même échelle Acquis / Fragile / En difficulté. | Suit sans changement de vue. |

## Cas limites identifiés

- 47/48 % (9/20 → 10/20) : Bronze, Fragile, réussi, plus « à revoir ».
- 67/68 % (13/20 → 14/20) : Argent, Acquis, stable.
- 77/78 % (15/20 → 16/20) : Or.
- 72/73 % (14/20 → 15/20) : lève une lacune (déjà vrai depuis la PR 256).
- 97/98/99/100 % : 20/20 dès 98 %, Diamant seulement à 100 %.

## Questions encore ouvertes

- Aucune pour le porteur. Si les badges déjà décernés doivent être rattrapés, c'est un chantier de données à part.
