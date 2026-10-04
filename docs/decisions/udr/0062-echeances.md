# UDR-0062 : Échéances — les jours de séance à l'assignation, la date limite chez l'élève, les retards dans le suivi de l'enseignant

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-02 : « lance les lots ») |
| **Date** | 2026-10-02 |
| **Chantier** | [`docs/chantiers/fonctions-espace-eleve`](../../chantiers/fonctions-espace-eleve/memo.md) — grill Q5 à Q8, Q10 à Q12 ; [PRD](../../chantiers/fonctions-espace-eleve/prd.md) |
| **ADR lié** | [ADR-0072](../adr/0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md) (exercice seul, jours de séance, `due_on`, retard lu) · [ADR-0048](../adr/0048-statuts-d-assignation-active-et-archived.md) · [UDR-0057](0057-ecrans-eleve-epures.md) (R1 à R6) · [UDR-0058](0058-accueil-eleve.md) §3.3 (accueil élève actuel) · [UDR-0027](0027-page-classe.md), [UDR-0028](0028-cours-dans-la-classe-et-bascule-d-assignation.md), [UDR-0029](0029-fiche-essentielle-dans-la-classe.md) (écrans enseignant) · [UDR-0011](0011-ma-classe.md) (aucune liste nominative pour l'élève) |
| **Amende** | UDR-0011, 0013, 0015, 0027, 0028, 0029 ; déprécie l'UDR-0030 (§3.6) — acceptés le 2026-10-02 |
| **Remplacé par** | — |

---

## 1. Contexte

**L'élève** ne sait pas pour quand faire un exercice. Son accueil liste les exercices du plus récemment assigné au plus ancien ; rien ne dit lequel presse. La maquette V2 du porteur montre « À rendre demain », trie par date limite et pose un point ambre sur une matière en retard.

**L'enseignant** assigne un exercice « pour la séance prochaine » (Q6), mais l'application ne connaît pas ses séances. Il ne voit pas non plus qui a rendu l'exercice en retard (Q12).

L'ADR-0072 fixe la donnée : les jours de séance de l'enseignant dans la classe, une échéance figée à l'assignation (`due_on`, le prochain jour de séance), et un retard lu, jamais stocké. Cette UDR fixe les trois surfaces : l'assignation et la page de la classe chez l'enseignant, l'accueil chez l'élève, le suivi d'un exercice assigné.

Un effet de bord de l'ADR-0072 touche la navigation de l'enseignant. Il atteint aujourd'hui un exercice par les **cours assignés** de sa classe (page classe → cours dans la classe → fiche dans la classe → bascule de l'exercice). Sans cours assignables, ce chemin est vide. Le §3.4 le rouvre par un bloc « Cours » (memo, Q18, révisable par le porteur).

## 2. Décision

1. **La question des jours vient au moment d'assigner**, une fois par classe, jamais en bloquant : tant que l'enseignant n'a pas renseigné ses jours pour la classe, « Assigner » ouvre une modale « Quels jours voyez-vous la <classe> ? », avec « Assigner » et « Plus tard » (Q11). Une fois les jours connus, « Assigner » assigne d'un clic, comme aujourd'hui.
2. **Les jours se modifient sur la page de la classe**, sans toucher aux échéances déjà données (ADR-0072 §4.3).
3. **Chez l'élève, la date limite est une étiquette sous le titre**, au format de la charte (§12), en ambre seulement si elle est aujourd'hui, demain ou dépassée (charte §5). Les exercices se trient par date limite. Un exercice terminé n'a plus de date.
4. **Chez l'enseignant, le suivi est sur l'exercice assigné** : la page de la classe donne pour chaque exercice « 18 faits, dont 3 en retard · 7 pas encore faits », et sa page de suivi nomme les élèves qui l'ont rendu en retard (Q12). Aucun élève ne voit ces noms.
5. **Seul l'accueil actuel change chez l'élève** (UDR-0058 §3.3). La famille téléphone (UDR-0058 §3.2 : pastille de la carte du haut, point ambre de la grille) arrive avec la phase 2 d'`interface-epuree` ; le §3.3 en fixe déjà les règles.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Formats et tons — `DueDateHelper`

Un seul helper, `DueDateHelper#due_badge(due_on, today: Time.zone.today, done: false)`, rend l'étiquette ; un seul helper, `#due_for_teacher(due_on)`, rend la date côté enseignant. Aucune vue ne formate une échéance elle-même.

**Élève** (charte §12 ; `today` = date d'Abidjan) :

| Cas | Texte | Ton `ui_badge` | Icône |
|---|---|---|---|
| `due_on` nul, ou exercice terminé | rien | — | — |
| `due_on == today` | « À rendre aujourd'hui » | `warning` | `clock` |
| `due_on == today + 1` | « À rendre demain » | `warning` | `clock` |
| `today + 2 ≤ due_on ≤ today + 7` | « À rendre samedi » (jour seul, minuscule) | `neutral` | `clock` |
| `due_on > today + 7` | « À rendre lun. 12 oct. » | `neutral` | `clock` |
| `due_on == today − 1` | « En retard · prévu hier » | `warning` | `exclamation-circle` |
| `due_on < today − 1` | « En retard · prévu mardi 29 sept. » (jour et date, charte §12) | `warning` | `exclamation-circle` |

- « Moins de 24 h » se lit en jours (ADR-0072 §4.4) : faute d'heure de séance, aujourd'hui et demain sont ambre.
- Le ton `warning` est l'ambre de l'application (`--color-warning`, `--color-warning-soft`, UDR-0005). Il ne sert qu'à ces cas (R5, charte §5).
- L'état est dit en texte **et** en couleur : c'est la raison d'accessibilité que R6 admet (la couleur seule ne suffit jamais).
- Dates abrégées et noms de jours par `I18n.l` avec les formats `date.formats.due_short` (« %a %-d %b ») et `date.formats.due_long` (« %A %-d %b »), ajoutés à `config/locales/fr.yml`.

**Enseignant** (vouvoiement, date toujours absolue, pour qu'une capture reste juste le lendemain) : « Pour jeu. 8 oct. » ; sans échéance : « Sans date limite ».

### 3.2 Accueil élève actuel — `classroom/student_homes/show`, `_assigned_exercise`

**Données** (`StudentHomeQuery`, ADR-0072 §4.6) : `ExerciseRow` gagne `due_on` (de l'assignation active de l'exercice dans la classe principale).

**Ordre de la liste « À faire »**, testé dans cet ordre :
1. les exercices **non terminés** (`completed_count == 0`) avant les terminés ;
2. parmi eux, par `due_on` croissant, les exercices **sans échéance après** ceux qui en ont une (cas limite du memo) ;
3. à égalité, le plus récemment assigné d'abord (l'ordre actuel).

Un exercice commencé ne passe pas devant un exercice dû plus tôt (charte §8). Le premier de la liste garde le seul bouton principal (R1, UDR-0058 §3.3) : c'est désormais le plus urgent.

**Ligne `_assigned_exercise`** : la ligne actuelle, et une seule chose de plus.
- Sous le titre, la ligne des badges devient `div.flex.flex-wrap.items-center.gap-2` : `ui_subject_badge` (inchangé), puis `due_badge(exercise.due_on, done: exercise.completed_count.positive?)` en taille `sm`.
- Rien d'autre ne change : titre en lien, un bouton, révélation après 3 lignes.
- Le badge de progression de la carte (« N faits sur M ») est inchangé.

**R6** : l'échéance n'est dite qu'une fois, sur la ligne. La carte « Ma classe » ne la répète pas.

### 3.3 Famille téléphone — règles fixées ici, appliquées par la phase 2 d'`interface-epuree`

Elles entreront dans l'amendement de l'UDR-0058 §3.2 ; elles ne sont pas codées par ce chantier.

- **Carte du haut** : l'exercice choisi est le premier de l'ordre du §3.2. Sous « <matière> », la pastille de date (charte §8) avec le texte du §3.1 ; ambre dans les cas `warning`, sinon blanc à 16 %. S'il existe au moins un exercice en retard, la carte prend l'état « En retard » de la charte (le plus ancien, « Et N autres en retard »).
- **« À faire ensuite »** : à droite de chaque ligne, la date (charte §11), ambre dans les cas `warning`.
- **Point ambre** sur la case d'une matière (13 px, anneau de la couleur du fond) **si et seulement si** un exercice de cette matière est en retard pour l'élève (non terminé, `due_on < today`). Jamais de compteur. `StudentHomeQuery` expose pour cela `late_material_slugs`.

### 3.4 Enseignant — assigner un exercice et ses jours de séance

**La bascule** (`classroom/assignments/_toggle`, UDR-0028 §3) garde ses locaux et en gagne un : `needs_session_days:` (booléen, vrai quand l'acteur est un enseignant de la classe sans jours renseignés pour elle ; toujours faux pour l'équipe).
- `needs_session_days: false` : inchangé, `button_to` POST, l'échéance est calculée par le serveur.
- `needs_session_days: true` : « Assigner » devient un lien (`ui_button`, `secondary`, `sm`, icône `plus`, même `aria-label`) vers `new_classroom_assignment_path(classroom_public_id, assignable_key:)`, `data-turbo-frame="modal"`. Sans JavaScript, la même adresse rend la page du formulaire.
- État assigné : le badge « Assigné », puis, si `due_on`, le texte `due_for_teacher` (`text-sm text-mute`), puis « Retirer ».

**La modale des jours** — `classroom/assignments/new` (route `GET /classrooms/:classroom_public_id/assignments/new`, `Classroom::AssignmentsController#new`) :
- `ui_modal(title: « Quels jours voyez-vous la <classe> ? », size: :sm, open: true)` dans le frame `modal`.
- Une ligne de contexte : « <titre de l'exercice> sera à rendre pour la séance suivante. »
- `fieldset` (`legend` `sr-only` « Jours de séance ») : six cases à cocher, « Lun. » à « Sam. » (valeurs 1 à 6), en boutons bascule de 48 px (`ui_radio_group` en mode cases multiples, ou six `label` stylés `has-checked:bg-brand-soft`), sur une ligne qui passe à deux lignes de trois sous `sm`.
- Pied : `ui_button` « Plus tard » (`ghost`) et « Assigner » (`primary`), deux soumissions du même formulaire POST `classroom_assignments_path` :
  - « Assigner » envoie `assignment[weekdays][]` et l'exercice : jours enregistrés, puis assignation avec échéance (ADR-0072 §4.3) ;
  - « Plus tard » (`name="later"`) envoie l'exercice seul : assignation sans échéance ; la question reviendra.
- « Assigner » sans aucun jour coché : 422, la modale se rouvre avec l'erreur « Cochez au moins un jour, ou choisissez « Plus tard ». » sur le `fieldset` (`aria-describedby`, `aria-invalid`).
- Succès : la modale se ferme (`submitEnd`), le stream `create` remplace la bascule (avec la date) **et toutes les autres bascules de la page** passent à `needs_session_days: false` (`turbo_stream.refresh` de la page, morphing, comme l'UDR-0013 §2.6) ; toast « <exercice> ajouté à <classe>, à rendre jeudi 8 oct. » ou, sans échéance, « <exercice> ajouté à <classe>. ».

**Page de la classe — bloc « Jours de séance »** (`classroom/classrooms/_session_days`, `#classroom_session_days`), sous l'en-tête, rendu **seulement pour un enseignant de la classe** (l'équipe n'a pas de jours) :
- Renseignés : « Vos jours de séance : lundi, jeudi » et `ui_button` « Modifier » (`ghost`, `sm`, icône `pencil-square`, `data-turbo-frame="modal"`).
- Non renseignés : « Jours de séance non renseignés : vos exercices n'auront pas de date limite. » et « Renseigner » (`secondary`, `sm`).
- « Modifier » ouvre `classroom/session_days/edit` (`GET /classrooms/:classroom_public_id/session_days/edit`), la même grille de six cases, pré-cochée ; « Enregistrer » (`primary`) envoie `PATCH /classrooms/:classroom_public_id/session_days` (`Classroom::SessionDaysController#update`, use case `SetSessionDays`). **Tout décocher est permis** et vaut « non renseigné ».
- Sous les cases, une ligne `text-sm text-mute` : « Les dates déjà données ne changent pas. »
- Succès : stream `replace` de `#classroom_session_days`, toast « Jours de séance enregistrés. ».
- Classe archivée : le bloc est en lecture seule, sans bouton.

**Page de la classe — bloc « Exercices assignés »** (`classroom/classrooms/_assigned_exercises`, `#assigned_exercises`), **à la place de « Cours assignés »** :
- Une ligne par assignation **active** d'exercice, triée par `due_on` croissant (sans échéance à la fin), puis du plus récent au plus ancien.
- Une ligne (`li#assignment_<public_id>`, lien étiré vers la page de suivi) : titre de l'exercice, `ui_subject_badge`, `due_for_teacher(due_on)` ; dessous, `text-sm` : « 18 faits, dont 3 en retard · 7 pas encore faits ». « dont N en retard » n'apparaît que si N > 0 et que l'exercice a une échéance. Chevron à droite.
- Vide : `ui_empty_state` « Aucun exercice assigné », « Ouvrez un cours ci-dessous pour assigner un exercice à cette classe. », icône `clipboard-document-list`.

**Page de la classe — bloc « Cours »** (`classroom/classrooms/_courses`, `#classroom_courses`) — **retenu le 2026-10-02 par l'orchestrateur, sur recommandation, révisable par le porteur** (memo, Q18) :
- Les cours **publiés** du niveau et de la série de la classe, de la matière de l'enseignant (`teacher_profiles.material_id`) ; l'équipe voit toutes les matières.
- Une ligne par cours, lien vers `classroom_course_path` (UDR-0028), triée par position du programme puis par nom.
- C'est le seul chemin vers les exercices depuis la classe une fois les cours non assignables.

### 3.5 Suivi d'un exercice assigné

Route `GET /classrooms/:classroom_public_id/assignments/:public_id`, `Classroom::AssignmentFollowUpsController#show`, `as: :classroom_assignment`. Policy `Policies::Classroom::FollowAssignmentPolicy` (ADR-0072 §4.5) **avant** toute lecture ; query `Queries::Classroom::AssignmentFollowUpQuery`.

- `ui_back_link` vers `classroom_path` (libellé : le nom de la classe). `content_for :nav_key, "classrooms"`. `page_title` « <exercice> · Enseignant · Lnclass ».
- `ui_card` d'en-tête : « <classe> · <établissement> », `h1` titre de l'exercice, `ui_subject_badge`, `due_for_teacher(due_on)`, « Assigné le 2 oct. ». Lien « Voir l'exercice » (`ghost`) vers `exercise_path`.
- Trois chiffres, `dl` en ligne (`tabular-nums`) : « Faits » 18 · « dont en retard » 3 · « Pas encore faits » 7. « dont en retard » est absent sans échéance.
- Section « Rendus en retard » (`#late_students`), si N > 0 : une ligne par élève, nom (« Prénom Nom », ordre alphabétique du nom), à droite « Fait le mer. 7 oct. » (date de sa première session rendue). Pas de score (il est sur la page de l'exercice et dans la réussite de la classe, UDR-0029 : R6).
- Les élèves « pas encore faits » ne sont **pas** nommés : le grill ne demande que les retardataires (question ouverte).
- Sans échéance : pas de section retard ; un `text-sm text-mute` « Cet exercice n'a pas de date limite. ».
- Assignation archivée, ou d'une autre classe : 404. Élève, autre enseignant, direction : 403.

### 3.6 Retrait de l'assignation de cours et de fiches (ADR-0072 §4.1)

| Écran (UDR) | Ce qui part | Ce qui reste |
|---|---|---|
| Page cours du catalogue (UDR-0013) | « Assigner à mes classes » de l'enseignant, dans `_role_actions` | L'enseignant lit le cours, sans action ; l'équipe garde son panneau et son menu |
| Page fiche du catalogue (UDR-0015) | Aucun bouton (l'assignation s'y faisait déjà depuis la classe) | « Assigné par ton enseignant » chez l'élève, lu sur les seules assignations d'exercice |
| Cours dans la classe (UDR-0028) | La bascule du cours ; la bascule de chaque fiche ; l'aide « Assignez une fiche essentielle… » | L'en-tête du cours, la liste des fiches et leurs liens vers la fiche dans la classe |
| Fiche dans la classe (UDR-0029) | La bascule de la fiche et son `role="group"` | Les exercices, leur réussite et leur bascule, avec l'étape des jours (§3.4) |
| Assigner un cours (UDR-0030) | **Tout l'écran** : route `course_assignments`, `CourseAssignmentsController`, `CourseAssignmentTargetsQuery`, vue et locales | — (UDR dépréciée) |
| Page classe (UDR-0027) | « Cours assignés » | En-tête, élèves ; s'ajoutent « Jours de séance », « Exercices assignés » et « Cours » (§3.4) |
| Ma classe, élève (UDR-0011) | La carte « Cours assignés », toujours vide désormais (amendement accepté) | La carte de la classe ; les cours restent au catalogue (« Voir mes cours ») |

### 3.7 Tokens

- Composants `ui_*` et tokens du `@theme` uniquement (UDR-0005, UDR-0057) ; ambre = `warning` / `warning-soft`. Aucun `#hex`, aucun `style=`, aucune valeur entre crochets.
- Cases des jours : `rounded-ln border border-line`, cochée `bg-brand-soft border-brand text-brand-strong`.

### 3.8 États obligatoires

- **Vide** : aucun exercice assigné (élève : inchangé ; enseignant : §3.4) ; aucun rendu en retard : section absente.
- **Chargement** : tout est rendu par le serveur ; la modale des jours arrive dans le frame `modal` avec le squelette de `ui_modal` existant.
- **Erreur** : jours non cochés avec « Assigner » (422, message sur le `fieldset`) ; refus d'assignation inchangés (UDR-0028) ; `:forbidden` sur les jours (équipe, autre enseignant) en toast d'erreur.
- **Succès** : toasts du §3.4.
- **Classe archivée** : aucun bouton, dates lisibles.

### 3.9 Accessibilité

- Les six jours sont un `fieldset` avec `legend` ; chaque case a son `label` complet en `sr-only` (« Lundi ») sous l'abréviation visible ; cible ≥ 48 px.
- « Plus tard » et « Assigner » sont deux vrais boutons de soumission, dans l'ordre de tabulation « jours, Plus tard, Assigner ».
- La modale suit `ui_modal` : focus sur la première case à l'ouverture, Échap, retour du focus sur « Assigner » de la ligne d'origine.
- L'étiquette d'échéance de l'élève est du texte ; l'icône est `aria-hidden`.
- La liste des retardataires est une `ul` sous un `h2` ; les chiffres du suivi sont une `dl`.

### 3.10 Contrôle de la règle (UDR-0057), accueil élève

| Règle | Après |
|---|---|
| R1 | Un seul bouton principal, sur la première ligne (la plus urgente). |
| R2 | Inchangé : l'étiquette est dans la ligne, pas un bloc. |
| R3 | Inchangé : 3 lignes, puis « Voir plus ». |
| R4 | Aucun texte d'aide ; l'étiquette est une donnée. |
| R5 | L'ambre ne sert qu'à l'échéance proche ou dépassée. |
| R6 | L'échéance est dite une fois ; texte et couleur ensemble pour l'accessibilité. |

## 4. Conséquences

- **L'enseignant n'assigne plus que des exercices.** Ses écrans perdent leurs bascules de cours et de fiches ; l'UDR-0030 est dépréciée.
- **La page de la classe change de rôle** : du « ce que j'ai assigné » au « qui a fait quoi », avec la liste nominative réservée à l'enseignant de la classe et à l'équipe.
- **L'accueil élève se trie par urgence.** Le premier exercice est le plus pressé, terminé ou non commencé.
- **La FAQ gagne une question** « Que veut dire « En retard » ? » dans le lot des échéances (Q14, UDR-0061 §3.1).
- **La homepage ment** : « Déclare tes classes, assigne-leur des cours et des exercices » (`homepage.index.audience.roles.teachers.text`, `role_modal.teacher.lead`, `features.items.teachers.text`). Ces textes passent à « des exercices » dans le lot des échéances.
- **À signaler, sans le modifier ici** : l'UDR-0058 (§2.1, §4) annonce le retour de la **durée** d'un exercice par ce chantier ; elle est abandonnée (Q9). Son amendement de phase 2 d'`interface-epuree` la retire, et reprend le §3.3 ci-dessus et l'icône d'aide de l'UDR-0061.
- Interdit désormais : formater une échéance hors de `DueDateHelper` ; utiliser l'ambre pour autre chose qu'une échéance ; montrer un nom d'élève en retard à un élève.

## Amendement du 2026-10-03 — réorganisation des espaces équipe et enseignant

*Chantier [`docs/chantiers/reorganisation-equipe-enseignant`](../../chantiers/reorganisation-equipe-enseignant/prd.md), [UDR-0069](0069-accueil-enseignant-par-niveau-et-assignation-depuis-le-catalogue.md). Statut : proposé, accepté avec le plan du chantier. Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **La bascule sert aussi au catalogue** (UDR-0069 §3.8) : fiche essentielle et page d'un exercice, une bascule par classe du bon niveau ; nouveau local `classroom_name:` qui nomme la classe dans les `aria-label`. Modale des jours, streams et rafraîchissement inchangés.

## Amendement du 2026-10-04 — compréhension d'un exercice assigné

*Chantier [`docs/chantiers/rapports-exercices`](../../chantiers/rapports-exercices/prd.md), [UDR-0072](0072-comprehension-d-un-exercice-assigne.md), [ADR-0079](../adr/0079-lecture-de-la-comprehension-d-un-exercice-assigne.md). Statut : accepté (2026-10-04, porteur). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **§3.4, ligne d'un exercice assigné** : sous « N faits… », un pied, sous la même policy que les comptes : badges de la classe à gauche, cercle de compréhension à droite (UDR-0072 §3.4).
- **§3.5, page de suivi** : une section « Compréhension » entre la carte d'en-tête et les rendus en retard, catégories dans l'adresse (`?category=`) (UDR-0072 §3.5). Les élèves pas encore faits sont désormais **nommés**, après les rendus en retard (UDR-0072 §3.5 bis, ADR-0079 §4.8). Le reste de la page ne change pas.
