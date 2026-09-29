# UDR-0021 : Page exercice — en-tête, progression de l'élève et aperçu des questions, propositions correctes réservées à l'enseignant et à l'équipe

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
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

*Chantier [`docs/chantiers/finitions-ux`](../../chantiers/finitions-ux/prd.md), [UDR-0054](0054-finitions-d-interface.md). Statut : `Proposé`. Le texte ci-dessus reste tel qu'accepté ; une fois l'UDR-0054 acceptée, cette section fait foi en cas d'écart.*

- Retour : `ui_back_link` vers `course_essential_path`, libellé = nom de la fiche (au lieu de « Fiche essentielle : <nom> »).
- Titre : « <titre de l'exercice> · <espace> · Lnclass ».
- Badge et maîtrise de l'élève : suivis d'une infobulle des seuils (UDR-0054 §3.4).
