# UDR-0021 : Page exercice — en-tête, progression de l'élève et aperçu des questions, propositions correctes réservées à l'enseignant et à l'équipe

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) — *amendée le 2026-10-02 (proposé) par le chantier `interface-epuree`* |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot C1, critères AS-02, AS-39, TR-cadre-3 ; sécurité n° 29 |
| **ADR lié** | [ADR-0028](../adr/0028-policies-de-domaine-par-use-case.md) (`ReadPublishedPolicy`, `RevealAnswersPolicy`, `StartSessionPolicy`) · [ADR-0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) (badges, maîtrise) · [ADR-0054](../adr/0054-moteur-d-evaluation-soumission-et-cloture.md) (démarrer, reprendre, recommencer) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0006](0006-shell-applicatif-par-role.md) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) · [UDR-0017](0017-formulaire-exercice.md) (modale « Modifier ») |
| **Remplacé par** | — |

---

## 1. Contexte

Avant de faire un exercice, l'élève veut savoir ce qui l'attend et où il en est ; l'enseignant veut le relire avec sa correction pour préparer sa classe ; l'équipe veut le vérifier et le publier. Dans l'ancienne application :

- la page de l'exercice montrait les bonnes réponses « à l'enseignant et à l'équipe », mais la liste des questions était un **fragment mis en cache dont la clé ignorait le rôle** : l'élève qui passait après un enseignant recevait les réponses cochées (AS-39, sécurité n° 29) ;
- un exercice sans fiche essentielle levait `NoMethodError` ;
- l'élève ne voyait que « Meilleur score » : ni son badge, ni sa maîtrise, ni le nombre de ses sessions ; et il n'avait aucun moyen de recommencer une session en cours ;
- le menu de l'équipe proposait « Supprimer », qui détruisait sessions, tentatives et badges.

## 2. Décision

1. **Une seule page, `/exercises/:public_id`**, pour l'élève, l'enseignant et l'équipe. Un brouillon, un exercice archivé ou un exercice dont la fiche ou le cours n'est pas publié répond **404** hors de l'équipe, sans rien confirmer (`ReadPublishedPolicy`).
2. **Trois blocs empilés** : l'en-tête de l'exercice, la progression (élève seulement), l'aperçu des questions. Tout se lit d'un défilement ; aucun chargement différé.
3. **Les propositions correctes ne quittent le serveur que pour l'enseignant et l'équipe** (`RevealAnswersPolicy`). Pour l'élève, la query **ne lit même pas** la colonne `answers.correct` ni l'explication : la vue ne peut rien fuiter, même par erreur. L'élève voit l'énoncé et les propositions, sans marque ; il découvre la correction de chaque question dans sa session, juste après sa réponse (Lot C2).
4. **Aucun `cache`** dans la page ni dans ses partials : le HTML dépend du rôle. Toute mise en cache future devra mettre le rôle — et, pour l'élève, l'utilisateur — dans sa clé, et passer le test TR-cadre-3.
5. **La progression de l'élève** : meilleur score (sessions terminées), maîtrise (« Acquis », « Fragile », « En difficulté », ADR-0033), badge (« Badge Or »), nombre de sessions terminées. Sans session en cours : **« Commencer l'exercice »**. Avec une session en cours : **« Reprendre »** (lien vers la session) et **« Recommencer »** (qui abandonne la session ouverte, ADR-0054), avec une phrase qui le dit.
6. **L'équipe** voit, dans l'en-tête, le panneau de statut (`content_status_panel`, publier ou archiver) et **« Modifier »**, qui ouvre la modale de l'UDR-0017 dans le frame `modal`. Il n'y a **pas de « Supprimer »** : un exercice s'archive.
7. **L'enseignant** voit l'aperçu corrigé, sans bouton de session ni d'édition. L'assignation se fait depuis la classe (Lots D5 et D7).

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- `assessment/exercises/show` : `#exercise_header` (lien retour, `ui_card`), puis `div.space-y-10` → `_student_progress` seulement si `@progress` n'est pas `nil`, puis `_questions_preview`. `content_for :nav_key, "courses"`.
- `#exercise_header` : lien « Fiche essentielle : La méiose » vers `course_essential_path(course_slug, essential_slug)` ; `ui_card` → contexte « Cours · Fiche essentielle : … », `h1` titre, badges : matière **toujours** `ui_subject_badge(name, category:)`, niveau et série, type (« Fixation » ou « Évaluation », `brand`), « N questions » (icône `question-mark-circle`). Équipe : à droite (dessous au téléphone), `content_status_panel(record:)` et `ui_button` « Modifier » (`secondary`, `sm`, icône `pencil-square`, `data-turbo-frame="modal"`). Description (`#exercise_description`) sous les badges, si elle existe.
- `_student_progress` (`#student_progress`) : `ui_card` → titre « Ta progression », `dl` en 2 colonnes au téléphone et 4 dès `sm` : « Meilleur score » (« 85 % » ou « Aucune session terminée »), « Maîtrise » (ou « — »), « Badge » (`ui_badge` « Badge Or », ton de `badge_tone`, icône `trophy` ; sinon « Pas encore de badge »), « Sessions » (« 2 terminées »). Actions à droite (dessous au téléphone) : `form#start-exercise-form` POST `exercise_sessions_path` → « Commencer l'exercice » (icône `play`) ; ou `ui_button` « Reprendre » vers `exercise_session_path` et `form#restart-exercise-form` POST avec `restart=true` → « Recommencer » (`secondary`, icône `arrow-path`).
- `_questions_preview` (`#exercise_questions`) : titre « Aperçu des questions » et une aide qui dépend du rôle ; `ol[data-controller=math]` de `li.question` (`rounded-card`, numéro dans une pastille `bg-brand-soft`, énoncé, badge du type de question, `ul` des propositions `li.answer`). Avec reveal : proposition correcte `li#answer_<id>[data-correct]` en `bg-success-soft`, icône `check-circle`, `ui_badge` « Proposition correcte » (`success`) ; les autres, lettre A, B, C… en pastille ; puis l'explication (« Explication : … », `bg-info-soft`, icône `light-bulb`). Sans reveal : **aucun identifiant de proposition, aucun `data-correct`, aucune explication** dans le HTML.
- Lecture : `ExerciseRepository#find_by_public_id` (faits des policies, jamais rendu à l'élève), `ReadPublishedPolicy`, `RevealAnswersPolicy`, puis `ExerciseDetailQuery(public_id:, reveal:)` ; `StartSessionPolicy` décide de `ExerciseProgressQuery(student_id:, exercise_id:)`.

**Tokens**
- Composants `ui_*` et tokens `@theme` seulement. Aucune classe de l'ancienne application, aucune valeur arbitraire.

**Comportement**
- Lecture seule : aucun `*.turbo_stream.erb` propre à la page. « Commencer », « Reprendre » et « Recommencer » changent de page (Turbo Drive) ; ce sont de vrais formulaires `POST` qui marchent sans JavaScript.
- « Modifier » vise le frame `modal` ; l'enregistrement répond par le stream du Lot B5, qui rafraîchit cette page par morphing (`turbo_stream.refresh`).
- Les formules des énoncés et des propositions passent par le contrôleur Stimulus `math` (KaTeX chargé à la demande).

**États obligatoires**
- Vide : « Aucune question pour cet exercice » (« Ajoutez des questions avec « Modifier » : un exercice sans question ne peut pas être publié. »), visible de l'équipe seulement puisqu'un exercice publié a au moins une question.
- Chargement : sans objet (page rendue d'un bloc).
- Erreur : 404 (exercice inconnu, ou non lisible hors équipe) par `RendersResult`, sans aucune donnée de l'exercice.
- Succès : sans objet sur cette page ; les toasts de publication et de modification viennent du Lot B5.

**Accessibilité**
- La marque « Proposition correcte » est un texte, jamais la seule couleur ; le numéro de question est doublé d'un « Question N » `sr-only`.
- « Modifier » a pour nom « Modifier l'exercice « Méiose » ».
- Cibles tactiles ≥ 48 px ; la page tient dans 390 px sans défilement horizontal (test système).

## 4. Conséquences

- Tout écran qui montre des propositions (C2 pour la correction d'une question, C3 pour le résultat) lit `correct` par une query qui ne le sélectionne que si `RevealAnswersPolicy` l'accorde, et ne met rien en cache sans le rôle dans la clé.
- Le test `test/integration/assessment/answer_leak_test.rb` (TR-cadre-3) est le garde de cette page : il affiche l'exercice pour l'équipe, puis l'enseignant, puis l'élève, **cache de fragments actif**.
- « Supprimer un exercice » disparaît de l'interface ; l'archivage (UDR-0017) le remplace.

## Amendement du 2026-09-28

*Chantier [`docs/chantiers/actions-en-menu`](../../chantiers/actions-en-menu/prd.md), [UDR-0042](0042-actions-de-ligne-dans-un-menu.md). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **« Modifier » passe dans le menu ⋮** « Actions pour <titre> » (`#exercise-actions-menu`), seule entrée, après le panneau de statut. Le nom accessible « Modifier l'exercice « … » » est remplacé par celui du bouton ⋮.

## Amendement du 2026-09-29 — finitions d'interface

*Chantier [`docs/chantiers/finitions-ux`](../../chantiers/finitions-ux/prd.md), [UDR-0054](0054-finitions-d-interface.md). Statut : `Accepté` (avec l'UDR-0054, par le porteur le 2026-09-29). Le texte ci-dessus reste tel qu'il a été accepté ; cette section fait foi en cas d'écart.*

- Retour : `ui_back_link` vers `course_essential_path`, libellé = nom de la fiche (au lieu de « Fiche essentielle : <nom> »).
- Titre : « <titre de l'exercice> · <espace> · Lnclass ».
- Badge et maîtrise de l'élève : suivis d'une infobulle des seuils (UDR-0054 §3.4).

## Amendement du 2026-10-02 — épuration (UDR-0057) · Statut : Proposé

*Chantier [`interface-epuree`](../../chantiers/interface-epuree/memo.md), Lot C, [UDR-0057](0057-ecrans-eleve-epures.md). Statut : `Proposé`. Le Lot C ne code rien avant l'acceptation du porteur (plan, « Porte des lots C à F »). Une fois acceptée, cette section fait foi en cas d'écart avec le texte ci-dessus et les amendements précédents.*

**Contexte.** L'UDR-0057 impose six règles (R1 à R6) à chaque écran élève. Cette page est l'écran de détail de l'exercice : elle reçoit ce que l'accueil retire de ses lignes (UDR-0058 §3.3, grill Q4). L'audit de la vue élève, le 2026-10-02, relève deux textes d'aide permanents, deux répétitions, deux formes de la note dans le parcours et une liste sans limite.

**Q4 — ce que l'accueil retire.** Le bloc `#student_progress` affiche **déjà** les quatre informations : badge, meilleur score, maîtrise et nombre de sessions terminées (§2.5, `_student_progress`). Badge et maîtrise ont déjà leur infobulle des seuils (amendement du 2026-09-29) : la page explique donc badges et maîtrise, comme l'UDR-0058 §3.3 l'exige. Rien n'est à ajouter. Le Lot C prouve par un test système que les quatre valeurs restent visibles.

**Changements pour l'élève**

| Élément | Aujourd'hui | Après | Règle (R1–R6, Q4) | Où va l'information |
|---|---|---|---|---|
| Ligne de contexte de `#exercise_header` (`show.context`) | « <cours> · Fiche essentielle : <fiche> » | « <cours> » seul. Clé : `context: "%{course}"`, sans le paramètre `essential` | R6 | Le nom de la fiche reste dans le lien retour (`ui_back_link`), juste au-dessus de la carte |
| « Meilleur score » de `_student_progress` | « 85 % » | Libellé « Meilleure note », valeur `grade_label(progress.best_score_percent)` (« 17/20 »). Clés : `best_score: "Meilleure note"` ; `score` supprimée | R6 (une seule forme de la note dans le parcours, UDR-0058 §3.3) | Même valeur, sous la forme du résultat de session et de l'accueil |
| « Meilleur score » sans session terminée | « Aucune session terminée » | « — » en `text-mute`. Clé : `no_score: "—"` | R6 | « Sessions » dit déjà « Aucune terminée », dans le même bloc |
| Phrase `restart_hint` de `_student_progress` | Paragraphe permanent sous les boutons, quand une session est en cours | Paragraphe retiré. Même texte dans `ui_info_tip t(".restart_hint"), label: t(".restart")`, juste après le bouton « Recommencer », dans le même conteneur d'actions | R4 | Dans l'infobulle « Aide : Recommencer » |
| Aide `student_hint` de `_questions_preview` | Paragraphe permanent sous « Aperçu des questions » | Paragraphe retiré. Même texte dans `ui_info_tip t(".student_hint"), label: t(".title")`, dans le `h2`, juste après son texte (motif des `dt` de `_student_progress`) | R4 | Dans l'infobulle « Aide : Aperçu des questions ». La session montre aussi le verdict après chaque réponse |
| Liste `ol` des questions de `_questions_preview` | Toutes les questions | 3 questions visibles, les suivantes rendues mais masquées (`hidden`), puis « Voir plus » | R3 | Les questions suivantes sont déjà dans la page. « Voir plus » les révèle par 3, sans requête |

**« Voir plus » de l'aperçu (élève seulement)**
- `show` passe une locale de plus : `render "questions_preview", questions: @detail.questions, reveal: @reveal, student: @progress.present?`. `@progress` n'existe que pour l'élève (`StartSessionPolicy`).
- Si `student` : `section#exercise_questions` porte `data-controller="reveal"` et `data-reveal-step-value="3"`. Chaque `li.question` porte `data-reveal-target="item"`. À partir de la quatrième, il porte aussi `hidden`.
- Après l'`ol`, s'il y a plus de 3 questions : `ui_button` « Voir plus » (`variant: :ghost`, `full: true`, `data-reveal-target="button"`), puis `p.sr-only[aria-live=polite][data-reveal-target=status]`. Libellés et action : le contrat du contrôleur `reveal` et ses clés de `config/locales/shared/components.fr.yml` (Lot 0).
- `data-controller="math"` reste sur l'`ol` : KaTeX rend aussi les questions masquées.
- Sans `student`, l'aperçu est inchangé : toutes les questions, aucune cible `reveal`.

**Contrôle R1 à R6 (vue élève)**
- **R1** — Conforme aujourd'hui. Une seule action principale : « Commencer l'exercice » (`primary`), ou « Reprendre » (`primary`) avec « Recommencer » (`secondary`). « Voir plus » est `ghost`. L'élève n'a pas de menu ⋮.
- **R2** — Conforme aujourd'hui. Le `main` a deux enfants directs : `#exercise_header` et `div.space-y-10`. À 390 px, l'élève voit au plus quatre blocs : lien retour, carte de l'exercice, « Ta progression », aperçu.
- **R3** — Change : 3 questions, puis « Voir plus ». Les badges de l'en-tête ne forment pas une liste de lignes.
- **R4** — Change : `restart_hint` et `student_hint` passent en infobulle. Badge et maîtrise ont déjà la leur.
- **R5** — Conforme aujourd'hui. L'accent est `brand` (badge du type). La couleur du badge de matière suit la pastille de matière (UDR-0058 §3.4). Le ton du badge de palier code le palier, et le nomme en texte (UDR-0007).
- **R6** — Change : la fiche n'est plus nommée deux fois. « Aucune session terminée » n'est plus dit deux fois. La note a une seule forme, sur 20.

**Inchangé pour l'enseignant, l'équipe et la direction**
- Panneau de statut, menu ⋮ « Modifier », publier, archiver (équipe).
- Aide `reveal_hint` visible, aperçu corrigé complet, sans « Voir plus » (enseignant, équipe).
- Pas de bloc « Ta progression ».
- Seule la ligne de contexte change pour eux : c'est une simple répétition du lien retour (R6).

**Vérification**
- `test/system/assessment/exercise_page_test.rb` : badge, meilleure note, maîtrise et sessions visibles pour l'élève (Q4) ; 3 questions puis « Voir plus » ; `assert_single_primary_action` et `assert_blocks_above_fold(max: 5)` à 390 px ; l'enseignant voit toutes les questions, `reveal_hint` et aucun « Voir plus ».
- `test/controllers/assessment/exercises_controller_test.rb` : l'assertion sur `student_hint` vise désormais le panneau de l'infobulle.
