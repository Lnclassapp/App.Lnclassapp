# UDR-0107 : Fiche d'un élève dans sa classe — en-tête, trois chiffres et badges, exercices de la classe, « fait seul », gérer
<!-- index
titre: Fiche d'un élève dans sa classe
statut: Accepté *(porteur, 2026-10-16)*
adr-lie: [0097](../adr/0097-fiche-d-un-eleve-dans-sa-classe.md)
problematique: Enseignant de la classe et équipe : une page par élève présent (`/classrooms/:id/students/:id`) ; carte d'en-tête (photo, nom, numéro masqué, arrivée), trois chiffres et badges de la classe, exercices assignés avec état, meilleur score, catégorie, signe et lien vers la meilleure session, « fait seul » sur 30 jours, puis « Gérer » (code de récupération, retrait). Lisible sans JavaScript, une colonne au téléphone
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-16 : recommandations du memo, Q5 amendée) |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/rapports-de-classe`](../../chantiers/rapports-de-classe/prd.md) |
| **ADR lié** | [ADR-0097](../adr/0097-fiche-d-un-eleve-dans-sa-classe.md) (ce que lit la fiche) · [ADR-0079](../adr/0079-lecture-de-la-comprehension-d-un-exercice-assigne.md) (catégorie, signe) · [ADR-0072](../adr/0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md) (fait, retard) |
| **S'appuie sur** | [UDR-0072](0072-comprehension-d-un-exercice-assigne.md) (couleurs de catégorie, signes, badges) · [UDR-0062](0062-echeances.md) (échéances) · [UDR-0042](0042-actions-de-ligne-dans-un-menu.md) · [UDR-0081](0081-inscription-eleve-sans-code-de-classe.md) §3.7 (voie, nouveau, retrait) |
| **Remplacé par** | — |

---

## 1. Contexte

L'enseignant croise des noms d'élèves sur la page de sa classe et sur la page de suivi d'un exercice. Aucun ne mène nulle part (UDR-0027, UDR-0072 §3.5). Pour savoir où en est un élève sur les exercices de la classe, il devrait ouvrir chaque suivi et y chercher le nom. Il le fait sur téléphone, en préparant sa séance ou pendant celle-ci.

## 2. Décision

1. **Une page, pas une fenêtre.** La fiche a sa propre adresse, se partage, se recharge et revient par « retour ». Une modale cacherait la page de la classe pour un contenu long.
2. **Ce qui demande un geste d'abord.** Les trois chiffres de tête disent ce qui reste à faire ; la liste des exercices suit l'ordre de la page de la classe, pour que l'enseignant s'y retrouve.
3. **Les couleurs de la compréhension, sans en ajouter.** Catégorie, signe et badges reprennent l'UDR-0072, avec toujours le texte à côté de la couleur.
4. **Les actions rares en bas** (Q4) : « Code de récupération » et « Retirer de la classe » quittent le menu ⋮ de chaque ligne de la liste (UDR-0108) pour une section « Gérer » de la fiche.

## 3. Règles d'implémentation

> Contrat d'exécution. Vue : `app/views/classroom/classroom_students/show.html.erb`, partials dans le même dossier. Locales : `config/locales/classroom/classroom_students.fr.yml` (Lot 0).

### 3.1 Page

- `page_title` : le nom de l'élève, puis le nom de la classe (« Awa Bamba · 3ème B »).
- `content_for :nav_key, "classrooms"` (l'onglet « Classes » reste actif).
- `ui_back_link @header.name, href: classroom_path(@header.public_id)`.
- Une colonne, `space-y-8`, dans la largeur de contenu de la mise en page. Aucune grille à deux colonnes : la page se lit de haut en bas, au téléphone comme à l'ordinateur.

### 3.2 En-tête — `_identity.html.erb`

`ui_card padding: :md` :
- rangée `flex items-center gap-4` : `ui_avatar student.display_name, src: account_photo_src(student.public_id, student.photo_version), size: :lg` ; puis un bloc `min-w-0` :
  - `h1` le nom, `font-display text-2xl font-extrabold tracking-tight break-words sm:text-3xl` ;
  - `p.text-sm.text-mute` : « 3ème B · Lycée moderne de Cocody » (`t(".context", classroom:, school:)`) ;
  - si `student.newcomer` : `ui_badge t(".new"), tone: :brand, size: :sm`, comme sur la liste (UDR-0081 §3.7).
- dessous, `dl` en `mt-4 grid grid-cols-1 gap-2 text-sm sm:grid-cols-2` :
  - « Numéro » : la valeur masquée, `font-mono whitespace-nowrap`, telle que la query la rend, avec la mention sr-only « numéro masqué » (même balisage que la liste, UDR-0079 §3.8 ter) ; ni `tel:`, ni copie ;
  - « Arrivé le » : `l(student.joined_at.to_date, format: :long)`, suivi de la voie (« par le lien », rien pour la voie standard, comme UDR-0081 §3.7).

### 3.3 Chiffres et badges — `_summary.html.erb`

`ui_card padding: :md`, `id="student_file_summary"` :
- `dl#student_file_counts [aria-label=t(".counts_label")]`, `flex flex-wrap gap-x-10 gap-y-4`, trois paires, comme les trois chiffres de la page de suivi (UDR-0062 §3.5) :
  - « Faits » : `font-display text-3xl font-extrabold tabular-nums` « 7 », suivi de `span.text-base.text-mute` « sur 10 » ;
  - « En retard » : même style ; **absent** si aucune assignation n'a d'échéance ;
  - « Pas encore faits » : même style.
- `border-t border-line pt-5 mt-6`, puis le titre `p.text-sm.text-mute` « Badges dans cette classe » et `render "assessment/comprehension/badge_counts", counts: file.badge_counts` (quatre paliers, zéro atténué, UDR-0072).

### 3.4 Exercices de la classe — `_assignments.html.erb`

`section#student_file_assignments [aria-labelledby=student_file_assignments_title]`, `h2` « Exercices de la classe » en `mb-4 font-display text-xl font-extrabold`.

Une `ul` `divide-y divide-line rounded-card border border-line bg-white shadow-card`, une `li#assignment_<public_id>` par assignation, dans l'ordre de la query, `px-4 py-3 sm:px-5` :

- **Ligne 1**, `flex items-start justify-between gap-3` :
  - à gauche, `min-w-0` : le titre de l'exercice, `font-medium break-words`, lien vers la page de suivi `classroom_assignment_path(classroom, assignment)` (`text-ink underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-brand`) ; dessous, `flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-mute` : `ui_subject_badge material_name, category: material_category, size: :sm`, puis l'échéance `due_for_teacher(due_on)` (UDR-0062, ambre si passée).
  - à droite, `shrink-0 text-right` : l'état (§3.4.1).
- **Ligne 2**, seulement si l'exercice est fait, `mt-2 flex flex-wrap items-center justify-between gap-x-3 gap-y-1 text-sm` :
  - à gauche : la catégorie, pastille `size-2.5 rounded-full` de `comprehension_dot_class(category)` (`aria-hidden`) et `comprehension_label(category)` ; puis le signe, `ui_icon(trend_icon(trend), variant: :mini, size: :sm)` (`aria-hidden`) et `trend_label(trend)` en `text-mute` ; sans signe, rien ;
  - à droite : « 3 sessions » (`t(".sessions", count:)`, `text-mute tabular-nums`), puis le lien « Voir la meilleure session » vers `exercise_session_result_path(best_session_public_id)`, `text-xs font-medium text-brand-strong underline-offset-4 hover:underline` (même style que « Voir le résultat » de la liste).

#### 3.4.1 État, à droite de la ligne 1

| `status` | Rendu |
|---|---|
| `:done` | le meilleur score « 90 % », `font-display text-lg font-extrabold tabular-nums` ; dessous `text-xs text-mute` « Fait le 3 oct. » (`l(done_on, format: :due_short)`) |
| `:late` | le meilleur score, même style ; dessous `text-xs text-mute` « Rendu en retard le 5 oct. » |
| `:pending` | `text-sm text-mute` « Pas encore fait » |
| `:overdue` | `ui_badge t(".overdue"), tone: :warning, size: :sm` « Pas encore fait » ; l'échéance de la ligne est déjà en ambre (UDR-0062) |

- L'`aria-label` de la `li` n'est pas posé : le texte se lit dans l'ordre (titre, matière, échéance, état, catégorie, signe, sessions).

### 3.5 Fait seul — `_self_practice.html.erb`

`section#student_file_self_practice [aria-labelledby=…]`, `h2` « Fait seul · 30 derniers jours » (le nombre de jours vient de `StudentFileQuery::SELF_PRACTICE_DAYS`, interpolé), même style que §3.4.

- `p.text-sm.text-mute.mb-3` : « Exercices faits sans qu'on les lui ait assignés. » et, si `self_practice_total > self_practice.size`, « Les 20 plus récents sur 34. »
- Même `ul` que §3.4. Chaque `li` en `flex items-center justify-between gap-3 px-4 py-3 sm:px-5` : à gauche, `min-w-0` le titre (`font-medium break-words`) et dessous la matière (`ui_subject_badge … size: :sm`) et la date (`l(completed_at.to_date, format: :due_short)`) ; à droite, `shrink-0 text-right` le score « 75 % » (`tabular-nums font-medium`) et, dessous, « Voir le résultat » (même lien que §3.4).
- Les lignes ne sont pas des liens entiers : un seul lien par ligne.

### 3.6 Gérer — `_manage.html.erb` (Q4)

Rendue seulement si la classe est active (toujours vrai ici : une classe archivée répond 404) et si au moins une action est permise.

`section#student_file_manage`, `h2` « Gérer », même style. Une `ui_card padding: :md` en `flex flex-col gap-3 sm:flex-row` :
- « Code de récupération » : un `form_with url: account_pin_recovery_codes_path(student.public_id), method: :post, data: { turbo_frame: "_top" }` qui contient `ui_button t(".issue_code"), type: :submit, variant: :secondary, icon: "key"`. Même requête que l'entrée du menu qu'elle remplace (UDR-0077 §3.4). Sa réponse ne change pas.
- « Retirer de la classe » : si `ManageClassroomMembersPolicy` le permet, la confirmation est une `ui_modal title: t(".remove_title", name:), size: :sm, trigger: t(".remove"), trigger_variant: :danger, trigger_icon: "user-minus", trigger_href: classroom_student_path(classroom, student, remove: 1), open: params[:remove].present?` : son déclencheur ouvre la `<dialog>` avec JavaScript, et sans JavaScript il charge la fiche avec la fenêtre servie ouverte (déclencheur-lien de l'UDR-0061). Contenu inchangé : avertissement, Annuler, Retirer. Le formulaire `DELETE classroom_student_path(classroom, student)` porte `hidden_field_tag :origin, "file"` et `data: { turbo_frame: "_top" }` : la réponse est une redirection 303 vers la page de la classe, avec le toast existant.

### 3.7 États obligatoires

| État | Rendu |
|---|---|
| **Vide** — aucune assignation active | §3.3 : « 0 sur 0 », badges à zéro ; §3.4 : `ui_empty_state title: « Aucun exercice assigné à la classe. », description: « Les exercices que vous assignez apparaîtront ici. », icon: "clipboard-document-list"` à la place de la `ul` |
| **Vide** — aucun « fait seul » | §3.5 : `ui_empty_state title: « Aucun exercice fait seul ces 30 derniers jours. », icon: "sparkles"` |
| **Chargement** | page complète, aucun squelette (< 100 ms, ADR-0067) |
| **Erreur** | 403 et 404 par les pages d'erreur existantes (`render_result`, `render_not_found`) |
| **Succès** | §3.2 à §3.6 |

### 3.8 Accessibilité

- Un seul `h1` (le nom) ; `h2` par section, chaque `section` reliée à son titre par `aria-labelledby`.
- Couleur jamais seule : catégorie, signe et échéance sont écrits.
- Cibles ≥ 48 px de haut pour les boutons de « Gérer » ; les liens de ligne ont `py-1` de marge de toucher et ne sont jamais imbriqués.
- Focus visible `focus-visible:outline-2 focus-visible:outline-brand` sur tous les liens.
- Le numéro masqué est caché aux lecteurs d'écran au profit de « numéro masqué » (même règle que la liste).

### 3.9 Téléphone

- À 390 px, 375 px et 360 px : aucun défilement horizontal (test système). Le titre d'un exercice et le nom passent à la ligne, jamais tronqués.
- La ligne 2 d'un exercice passe sur deux lignes si besoin : la catégorie et le signe à gauche, les sessions et le lien dessous à droite.

### 3.10 Libellés — `config/locales/classroom/classroom_students.fr.yml` (Lot 0)

`classroom.classroom_students.show` : `context`, `new` (« Nouveau »), `contact` (« Numéro »), `contact_masked`, `joined_on` (« Arrivé le %{date} »), `via.link` (« par le lien »), `counts_label` (« Exercices de la classe »), `done` (« Faits »), `done_of` (« sur %{count} »), `late` (« En retard »), `pending` (« Pas encore faits »), `badges_title` (« Badges dans cette classe »), `assignments.title`, `assignments.empty.*`, `done_on`, `late_on`, `not_done`, `overdue`, `sessions` (one / other, « session », jamais « essai » : UDR-0007), `best_session`, `self_practice.title`, `self_practice.hint`, `self_practice.truncated`, `self_practice.empty`, `see_result`, `manage.title`, `issue_code`, `remove`, `remove_title`, `remove_warning`, `cancel`, `remove_confirm`.

## 4. Conséquences

- La fiche devient l'endroit d'un élève : la V5 y ajoutera ses lacunes et ses remédiations (AS-17), sous la section « Exercices de la classe ».
- Les noms d'élèves des écrans enseignant deviennent des liens vers elle (UDR-0108, UDR-0109).
- La page de résultat d'une session garde son lien de retour vers la fiche essentielle (UDR-0023) : l'enseignant revient à la fiche par « retour ».
- Interdit désormais : afficher sur la fiche un badge, un score ou une session d'une autre classe ; afficher le numéro complet.
