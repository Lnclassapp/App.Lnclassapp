# UDR-0139 : La page de la leçon — « Fiche de révision », puis « Prépare interros »
<!-- index
titre: Page de la leçon : fiche de révision et Prépare interros
statut: Accepté
adr-lie: XXXX-exercice-de-lecon-avec-sujet-et-notion-sans-page
problematique: La fiche est cachée derrière un bouton et les exercices dispersés sur des pages de notion ; la page d'une leçon doit tout montrer, la fiche en aperçu et les exercices assignables.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-28 |
| **Chantier** | `docs/chantiers/refonte-page-lecon` |
| **ADR lié** | ADR-0113 |
| **Remplacé par** | — |

Amende : UDR-0130 (vocabulaire, §2 et §3), UDR-0137 §4.1 (nom à l'écran), UDR-0013 et UDR-0057 R3 pour la page de la leçon (la liste des fiches de révision disparaît).

---

## 1. Contexte

Aujourd'hui, la page d'une leçon montre un texte de présentation, un bouton « Fiche de cours » vers la fiche à l'identique des maquettes, puis « Révisions de la leçon », une liste de 3 à 5 pages de notion. Les exercices sont dans ces pages. L'enseignant passe par quatre écrans pour assigner un exercice ; l'élève lit le même contenu deux fois (la fiche, puis chaque notion).

## 2. Décision

**Une page, deux sections, dans cet ordre : « Fiche de révision », puis « Prépare interros ».**

- **Fiche de révision** : la fiche à l'identique des maquettes, rendue dans la page, coupée après 150 mots en fin de bloc, puis « Voir plus » qui déplie le reste sur place. Pas de nouvelle page, pas de requête : tout est déjà dans le HTML.
- **Prépare interros** : les exercices de la leçon, groupés sous le titre de leur notion, puis « Toute la leçon ». Chaque ligne est un lien vers l'exercice ; l'enseignant assigne depuis la ligne.

**Pourquoi un contrôleur maison plutôt que `@stimulus-components/read-more`.** Ce composant replie un seul élément par `line-clamp` CSS :

- il coupe au milieu d'une phrase, d'une formule KaTeX ou d'une figure, alors que le porteur veut une coupe en fin de bloc (memo, Q12) ;
- le repli est en CSS : sans JavaScript, la fiche resterait coupée et illisible ;
- il ajoute une dépendance pour une trentaine de lignes.

Le contrôleur `catalog--revision-more` masque au démarrage ce que le serveur a marqué « suite » : sans JavaScript, tout reste visible.

**Vocabulaire (amende UDR-0130).**

| Concept | Terme d'interface | Remarque |
|---|---|---|
| `Course` | Fiche de cours | inchangé ; la rubrique reste « Cours » |
| `CourseSheet` (fiche à l'identique des maquettes) | **Fiche de révision** | titre de la première section ; remplace la proposition « Fiche de cours » d'UDR-0137 §4.1 |
| `Essential` | — (aucun nom d'objet) | son titre sert d'intertitre ; seuls « Notion à revoir » / « Notions à revoir » la nomment |
| Section des exercices | **Prépare interros** | remplace « Révisions de la leçon » |
| Exercices sans notion | **Toute la leçon** | intertitre ; « leçon » y désigne la fiche de cours, comme l'ancienne exception 2 |
| Lacune en attente | **Notion à revoir** | remplace « Fiche à revoir » |

« Fiche de révision » ne nomme plus jamais l'objet `Essential`.

## 3. Règles d'implémentation

### 3.1 Structure de `catalog/courses/show`

```
ui_back_link « Cours »
#course_header         ui_card : titre, sous-titre, badges, actions du rôle (inchangé, SANS le bouton « Fiche de cours »)
.space-y-10
  section#fiche-de-revision     aria-labelledby="revision_title"
    h2#revision_title           « Fiche de révision »
    render "catalog/courses/revision_sheet"
  section#prepare-interros      aria-labelledby="prepare_title"   data-turbo-prefetch="false"
    h2#prepare_title            « Prépare interros »
    p.text-mute                 « Un exercice par notion, puis quatre sur toute la leçon. »
    render "catalog/courses/prepare_interros"
```

- `#course_content` (texte Action Text) n'est plus une section : il devient le début du repli texte (§3.2, cas « sans fiche cahier »).
- `#course_essentials` et `_essential_row` sont retirés.
- `classroom/classroom_courses/show` (enseignant, dans sa classe) rend les mêmes deux partials, avec les bascules d'assignation de **cette** classe seulement.

### 3.2 Partial `catalog/courses/_revision_sheet`

| Cas | Rendu |
|---|---|
| La leçon a une fiche cahier | La feuille `course_sheet` est chargée (`content_for :head`) ; le bloc `.sheet-screen` de l'actuel `course_sheets/show`, avec ses contrôleurs (`math course-sheet--glossary course-sheet--simple-toggle`), extrait dans `catalog/course_sheets/_sheet` et rendu ici |
| Pas de fiche cahier, du texte | `ui_card padding: :lg` ; le texte Action Text de la leçon, puis pour chaque notion publiée, dans l'ordre : `h3.font-display.text-lg.font-medium` (titre de la notion), son texte Action Text ; le tout sous `data-controller="math"` |
| Ni fiche ni texte | `ui_empty_state title: t(".revision_empty"), icon: "document-text"` ; pas de « Voir plus » |

**La coupe des 150 mots** (calcul serveur, `Entities::Catalog::RevisionPreview`, Ruby pur) :

- on parcourt les blocs dans l'ordre de lecture (pages, sections, blocs ; ou texte de la leçon puis notions, un paragraphe Action Text = un bloc) ;
- on compte les mots du **texte seul** : paragraphes, encadrés, explications simples, étapes, cellules de tableau, intertitres ; une formule `$…$` compte un mot ; figure, média et exercice d'entraînement comptent zéro ;
- la coupe tombe **après le premier bloc qui porte le total à 150 ou plus** ;
- total ≤ 150 : pas de coupe, pas de bouton.

Chaque bloc après la coupe, et chaque page ou section entièrement après la coupe, reçoit `data-catalog--revision-more-target="rest"`. Le serveur ne pose **jamais** `hidden`.

Sous la partie visible, quand il y a une coupe :

```erb
<div class="revision-fade" data-catalog--revision-more-target="fade" hidden></div>
<%= ui_button t(".revision_more"), variant: :secondary, icon_end: "chevron-down", hidden: true,
              data: { catalog__revision_more_target: "button", action: "catalog--revision-more#toggle" },
              "aria-expanded": "false" %>
<p class="sr-only" aria-live="polite" data-catalog--revision-more-target="status"></p>
```

`.revision-fade` (dégradé du fond vers transparent, 64 px, au-dessus du bouton) est dans `course_sheet.css` pour la fiche cahier, et dans `application.tailwind.css` (`from-white`) pour le repli texte.

### 3.3 Contrôleur `app/javascript/controllers/catalog/revision_more_controller.js`

- `static targets = ["rest", "button", "fade", "status"]`, `static values = { more: String, less: String, shown: String }`.
- `connect()` : si au moins une cible `rest` → les masque (`hidden = true`), affiche `button` et `fade`. Sinon ne fait rien.
- `toggle()` :
  - replié → déplie toutes les `rest`, masque `fade`, libellé `less` (« Voir moins »), icône `chevron-up`, `aria-expanded="true"`, `status` = `shown`, focus sur le premier élément déplié (`tabindex="-1"` posé en JS) ;
  - déplié → replie, `aria-expanded="false"`, libellé `more`, puis `#fiche-de-revision` défile en haut (`scrollIntoView({ block: "start" })`) et le focus revient au bouton.
- Au morphing Turbo (rafraîchissement), `connect()` rejoue : la fiche revient repliée.
- Une adresse qui vise `#fiche-de-revision` garde la fiche repliée ; une adresse vers une ancre **dans** la suite la déplie (`connect()` lit `location.hash`).

### 3.4 Partial `catalog/courses/_prepare_interros`

```
ui_empty_state (si aucun exercice publié lisible)       t(".exercises_empty"), icon: "pencil-square"
sinon, pour chaque notion qui a un exercice, dans l'ordre des notions :
  div#notion-<essential.slug>  class="scroll-mt-24"  tabindex="-1"
    h3.mb-2.font-display.text-lg.font-medium         titre de la notion
    ul.divide-y.divide-line.rounded-card.border.border-line.bg-white.shadow-card
      render "catalog/courses/exercise_row" (un par exercice)
puis, si des exercices de toute la leçon :
  div#toute-la-lecon  class="scroll-mt-24"
    h3 « Toute la leçon »
    ul (mêmes classes) → les exercices par position
```

**`_exercise_row`** (`li#exercise-<public_id>`, `scroll-mt-24`) :

- Ligne principale, lien `exercise_path(public_id)` sur toute la ligne, cible ≥ 48 px (`min-h-tap px-4 py-3`) :
  - titre (`font-medium text-ink`) ;
  - `ui_badge "Fixation", tone: :info` ou `ui_badge "Évaluation", tone: :brand` ;
  - `t(".question_count", count:)` en `text-sm text-mute` ;
  - à droite, **pour l'élève**, un seul état, dans cet ordre de priorité :
    1. lacune en attente sur la notion → `ui_badge t(".to_review"), tone: :warning, icon: "arrow-path"` ;
    2. assignation active non rendue → `ui_badge t(".due", day: l(due_on, format: "%A")), tone: :info` (« À rendre jeudi » ; `t(".due_today")` le jour même) ;
    3. au moins une copie rendue → meilleure note, `ui_badge "14/20"`, tone `:success` dès 14/20 (UDR-0087 §3.1), `:neutral` sinon ;
    4. rien.
  - **pour l'équipe**, le statut de publication (`ui_badge`, comme `_essential_row` aujourd'hui).
- **Pour l'enseignant**, sous la ligne : une ligne par classe de ce niveau qu'il enseigne, `render "classroom/assignments/toggle", compact: true, primary: <premier « Assigner » de la page>` (UDR-0134 §3.13). Sans classe du niveau : une seule fois sous l'intro de la section, `t(".assign_targets_none", level:)` (valeur reprise de `catalog.essentials.show.assign_targets_none`).
- Les exercices d'entraînement **dans** la fiche de révision n'ont jamais de bascule.

### 3.5 Tokens

- Hors de la fiche cahier : jetons de l'UDR-0136 seulement (`bg-white`, `bg-paper`, `text-ink`, `text-mute`, `border-line`, `rounded-card`, `shadow-card`, `font-display`, `min-h-tap`). Aucune valeur arbitraire.
- La fiche cahier garde sa feuille `course_sheet.css` et l'exception d'UDR-0137 ; son conteneur prend toute la largeur de la colonne, sans `ui_card` autour.
- Espacements : `space-y-10` entre sections, `mb-4` sous un `h2`, `mt-6` entre deux groupes de notion.

### 3.6 États obligatoires

| État | Fiche de révision | Prépare interros |
|---|---|---|
| Vide | `ui_empty_state` « La fiche de révision arrive bientôt. » | `ui_empty_state` « Les exercices arrivent bientôt. » ; aucune bascule |
| Chargement | aucun : rendu serveur ; barre de progression Turbo | idem ; une bascule envoyée passe en `aria-busy="true"` (existant) |
| Erreur | sans objet (aucune requête) | bascule refusée : toast et ligne inchangée (Turbo Stream existant de `_toggle`) |
| Succès | 150 mots, « Voir plus » ; ou tout, si court | la liste ; la bascule devient « Assignée » sans rechargement |

### 3.7 Redirections et ancres

| Ancienne adresse | Nouvelle |
|---|---|
| `course_essential_path(course, essential)` | 301 → `course_path(course, anchor: "notion-#{essential.slug}")` |
| `course_sheet_path(course)` | 301 → `course_path(course, anchor: "fiche-de-revision")` |
| `classroom_essential_path(classroom, essential)` | 301 → `classroom_course_path(classroom, course, anchor: "notion-#{essential.slug}")` |

Tous les liens internes vers ces anciennes adresses sont remplacés (accueil, lacunes, résultat, carte « Reprendre », lacunes de la classe) : la redirection ne sert qu'aux favoris.

### 3.8 Accessibilité

- Un seul `h1` (la leçon) ; `h2` pour les deux sections ; `h3` pour les groupes.
- « Voir plus » : `button` réel, `aria-expanded`, cible ≥ 48 px, annonce dans une région `aria-live="polite"`.
- Les badges d'état ne portent pas le sens par la couleur seule : le texte est toujours présent.
- L'ancre `#notion-<slug>` reçoit le focus à l'arrivée par une « Notion à revoir ».
- Ordre de tabulation : retour, actions du rôle, fiche, « Voir plus », exercices dans l'ordre affiché, bascules sous leur exercice.

### 3.9 Textes (valeurs imposées)

| Clé | Valeur |
|---|---|
| `catalog.courses.show.revision_title` | « Fiche de révision » |
| `catalog.courses.show.revision_more` | « Voir plus » |
| `catalog.courses.show.revision_less` | « Voir moins » |
| `catalog.courses.show.revision_shown` | « Fiche de révision affichée en entier » |
| `catalog.courses.show.revision_empty` | « La fiche de révision arrive bientôt. » |
| `catalog.courses.show.prepare_title` | « Prépare interros » |
| `catalog.courses.show.prepare_intro` | « Un exercice par notion, puis quatre sur toute la leçon. » |
| `catalog.courses.show.lesson_wide_title` | « Toute la leçon » |
| `catalog.courses.show.exercises_empty` | « Les exercices arrivent bientôt. » |
| `catalog.courses.show.question_count` | one « %{count} question » · other « %{count} questions » |
| `catalog.courses.show.due` | « À rendre %{day} » |
| `catalog.courses.show.due_today` | « À rendre aujourd'hui » |
| `catalog.courses.show.to_review` | « À revoir » |
| `catalog.courses.show.assign_targets_none` | « Aucune de vos classes n'est en %{level}. » |
| `catalog.course_sheets.name` | « Fiche de révision » |
| `classroom.student_classrooms.pending_gaps.title` | « Notions à revoir » |
| `assessment.session_results.gap_outcome.opened.message` | « Cette notion passe à revoir. » |
| `assessment.session_results.gap_outcome.opened.hint` | « Refais l'exercice de « %{essential} » et vise au moins %{grade}/20. » |
| `assessment.session_results.gap_outcome.lifted.message` | « Notion levée ! » |
| `assessment.session_results.gap_outcome.open_essential` | « Refaire l'exercice » |
| `classroom.classroom_courses.show.*` | mêmes valeurs que `catalog.courses.show.*` |

Les clés `catalog.courses.show.essentials_title`, `classroom.classroom_courses.show.essentials_title` et `catalog.essentials.show.*` sont supprimées avec leurs vues. `i18n-tasks unused` reste vert.

## 4. Conséquences

- La page de la leçon charge `course_sheet.css` quand la leçon a une fiche cahier : l'exception d'UDR-0137 s'étend à `catalog/courses/_revision_sheet` et `catalog/course_sheets/_sheet`, pas au reste de la page. `test/design/design_tokens_test.rb` est mis à jour en conséquence.
- Interdits désormais à l'écran : « Fiche de révision » pour `Essential`, « Fiche essentielle », « Révisions de la leçon », « Fiche à revoir ».
- La règle « 3 lignes, puis Voir plus » (UDR-0057 R3) ne s'applique plus à la page de la leçon : « Prépare interros » montre tous ses exercices (7 à 9).
- Le contrôleur `reveal` reste pour les listes ; `catalog--revision-more` est réservé au repli de la fiche.
