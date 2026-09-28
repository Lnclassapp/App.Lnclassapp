# UDR-0052 : L'espace direction — cinq destinations, un tableau de bord par classe, des listes filtrées dans un frame, des gestes de gestion confirmés en modale

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-09-28, avec ses retours)* |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/espace-direction`](../../chantiers/espace-direction/prd.md) — critères ED-01 à ED-47, ED-56 à ED-64 |
| **ADR lié** | [ADR-0066](../adr/0066-espace-direction-droits-et-gestes.md) (droits, gestes) · [ADR-0067](../adr/0067-tableau-de-bord-de-l-etablissement.md) (tableau de bord) · [ADR-0065](../adr/0065-matricule-de-l-eleve.md) (matricule) · [ADR-0044](../adr/0044-rattachement-de-la-direction-par-invitation.md) · [ADR-0057](../adr/0057-code-d-etablissement.md) · [ADR-0059](../adr/0059-ajuster-les-classes-d-un-niveau.md) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0006](0006-shell-applicatif-par-role.md) · [UDR-0042](0042-actions-de-ligne-dans-un-menu.md) |
| **Amende** | [UDR-0006](0006-shell-applicatif-par-role.md) (cinquième destination de la direction) · [UDR-0019](0019-invitation-equipe.md) (acceptation d'une invitation de direction, second facteur) · [UDR-0036](0036-gestion-des-etablissements.md) (section « Direction » de la fiche) · [UDR-0041](0041-page-profil.md) (fonction et établissement) · [UDR-0050](0050-inviter-un-collegue-et-croissance.md) (écran d'attente) · ferme **C-31** ([UDR-0002](0002-ui-ux-de-l-organisation-scolaire.md)) |
| **Remplacé par** | — |

---

## 1. Contexte

Un Proviseur, un Censeur, un Éducateur ou une Secrétaire n'a aujourd'hui aucun écran : un compte `school_admin` atterrit sur l'écran d'attente, et les quatre entrées de sa navigation sont inactives (UDR-0006). Pour chaque geste — ajouter une classe, transmettre le code, savoir qui enseigne où, changer un élève de classe — il appelle l'équipe, qui ne suit plus quand les établissements se multiplient.

Ces personnes travaillent souvent sur un téléphone Android d'entrée de gamme (ADR-0051), entre deux cours. Elles ont besoin de **voir** leur établissement en un coup d'œil et de faire **un** geste à la fois, sans jamais toucher par erreur un autre établissement ni une donnée d'élève qu'elles n'ont pas à voir.

La contradiction **C-31** (feuille de route §4) reste ouverte : l'UDR-0002 prévoyait une recherche par DRENA, une carte d'école et des onglets école → classes ; le code de l'ancienne application n'en avait rien. Elle se tranche ici pour la direction.

## 2. Décision

1. **Le shell de la direction a cinq destinations** : Accueil (le tableau de bord), Classes, Enseignants, Élèves, Établissement. Le profil reste dans le menu du compte. Cinq est le maximum de l'UDR-0006.
2. **Pas d'identifiant d'établissement dans l'espace** : la direction n'a qu'un établissement, toujours le sien. Aucune recherche de DRENA, aucune liste d'établissements, aucune carte d'école à choisir. **C-31 est fermée** ainsi : pour la direction, la « carte d'école » de l'UDR-0002 devient l'en-tête de la page Établissement, et les onglets école → classes deviennent les destinations du shell ; les badges suivent l'UDR-0005 (`ui_badge`), jamais `bg-green-100`. Côté équipe, les UDR-0036, 0044 et 0046 restent en vigueur.
3. **Accueil = tableau de bord** : trois chiffres en tête, puis une ligne par classe (effectif, devoirs, taux de rendu, moyenne), sans aucune note d'élève (ADR-0067). Chaque ligne mène à la page de la classe.
4. **Les listes (enseignants, élèves) se filtrent par classe dans un Turbo Frame qui avance l'URL**, et se paginent par 20 : le retour arrière retrouve le filtre, une liste de mille élèves reste légère.
5. **Chaque geste de gestion est une modale** (`ui_modal`, UDR-0006) : inviter, retirer (confirmé), réintégrer un enseignant (confirmé), régénérer le code (confirmé), changer un élève de classe (une ou deux étapes). Un geste qui détruit un lien est **confirmé** et passe par le menu ⋮ de la ligne (UDR-0042).
6. **Un bouton que la fonction ne permet pas n'est pas affiché** (Éducateur, Secrétaire : pas de « Retirer », pas de « Réintégrer », pas de « Régénérer », pas d'« Inviter »). Le serveur refuse de toute façon (403).
7. **Changer un élève de classe** : depuis sa ligne de la liste (une étape : la classe), ou en le cherchant par son matricule entier (deux étapes dans la même modale : le matricule, puis la confirmation du nom et le choix de la classe). La recherche ne trouve que les élèves **de l'établissement** (relecture du porteur, 2026-09-28) : un matricule inconnu, d'un élève sans classe cette année ou d'un autre établissement reçoit **le même message**. Aucun rattachement d'un élève venu d'ailleurs.
8. **L'équipe voit la direction sur la fiche de l'établissement** (section « Direction »), l'invite et la retire, Proviseur compris.
9. **Un enseignant retiré se réintègre depuis la page « Enseignants »** (relecture du porteur, 2026-09-28) : une section « Enseignants retirés » les liste ; le Proviseur et le Censeur les réintègrent après confirmation.
10. **Le code d'adhésion d'une classe existe dès sa création**, y compris pour une classe ajoutée par la direction : la direction le lit et le copie, sans le régénérer ni le fermer.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.0 Commun à toutes les pages

**Routes** (contrat du Lot 0, `config/routes/school_admin.rb`, `scope "school-admin", module: "school_admin", as: "school_admin"`)

| Verbe et chemin | Action | Nom de route |
|---|---|---|
| `GET /school-admin` | `homes#show` | `school_admin_home_path` |
| `GET /school-admin/classrooms` | `classrooms#index` | `school_admin_classrooms_path` |
| `GET /school-admin/classrooms/:public_id` | `classrooms#show` | `school_admin_classroom_path` |
| `POST /school-admin/level-classrooms` | `level_classrooms#create` | `school_admin_level_classrooms_path` |
| `GET /school-admin/teachers` | `teachers#index` | `school_admin_teachers_path` |
| `DELETE /school-admin/teachers/:public_id` | `teachers#destroy` | `school_admin_teacher_path` |
| `GET /school-admin/teachers/departed` | `departed_teachers#index` | `school_admin_departed_teachers_path` |
| `POST /school-admin/teachers/:public_id/reinstatement` | `teacher_reinstatements#create` | `school_admin_teacher_reinstatement_path` |
| `GET /school-admin/students` | `students#index` | `school_admin_students_path` |
| `GET /school-admin/students/placement/new` | `student_placements#new` | `new_school_admin_student_placement_path` |
| `POST /school-admin/students/placement/lookup` | `student_placements#lookup` | `lookup_school_admin_student_placement_path` |
| `GET /school-admin/students/:student_public_id/placement/edit` | `student_placements#edit` | `school_admin_edit_student_placement_path` |
| `PATCH /school-admin/students/:student_public_id/placement` | `student_placements#update` | `school_admin_update_student_placement_path` |
| `GET /school-admin/school` | `schools#show` | `school_admin_school_path` |
| `GET` · `PATCH /school-admin/school/code` | `school_codes#show` · `#update` | `school_admin_school_code_path` |
| `GET /school-admin/school/staff` | `staff_members#index` | `school_admin_staff_members_path` |
| `DELETE /school-admin/school/staff/:user_public_id` | `staff_members#destroy` | `school_admin_staff_member_path` |
| `GET …/school/staff/invitations/new` · `POST …/school/staff/invitations` | `staff_invitations#new` · `#create` | `new_school_admin_staff_invitation_path` · `school_admin_staff_invitations_path` |

Côté équipe (`config/routes/teams.rb`, sous `resources :schools`) : `resources :staff_members, only: %i[index destroy], path: "staff", param: :user_public_id, controller: "school_staff_members"` et `resources :staff_invitations, only: %i[new create], path: "staff/invitations", controller: "school_staff_invitations"`. Côté identité : `post "account/pending/school", to: "identity/school_rejoins#create", as: :school_rejoin`. Les deux routes de changement de classe se déclarent dans le `scope … as: "school_admin"` avec `as: :edit_student_placement` et `as: :update_student_placement` ; `departed` se déclare **avant** toute route membre de `teachers`. Le test de routage du Lot 0b fixe les noms de helper exacts de ce tableau (**20 routes** de la direction ; la route `POST /school-admin/students/placement` du premier jet est retirée avec le rattachement d'un élève venu d'ailleurs).

**Contrôleurs** : tout contrôleur `SchoolAdmin::` hérite de `SchoolAdmin::BaseController` (`allow_roles :school_admin`, renvoi vers `pending_account_path` sans établissement, ADR-0066). Aucun ne lit `params[:school_…]` : l'établissement est `current_actor.school_id`. Une ressource d'un autre établissement répond **404** (`render_not_found`).

**Tokens** : composants `ui_*` et tokens `@theme` de l'UDR-0005 seulement ; aucune valeur arbitraire `[…]`, aucun `#hex`. Couleur de rôle `bg-school` (filet du shell, `role_accent`). Fonctions : `ui_badge` `tone: :info` (Proviseur, Censeur), `tone: :neutral` (Éducateur, Secrétaire). Chiffres : `font-display font-extrabold tabular-nums`. Matricule : `font-mono tracking-wider`.

**Libellés des fonctions** (`school_admin.shared.positions`) : `principal` « Proviseur », `censor` « Censeur », `educator` « Éducateur », `secretary` « Secrétaire ».

**390 px** : chaque page est prouvée à 390 px de large sans défilement horizontal : les rangées passent en colonne (`flex-col sm:flex-row`), les grilles de chiffres en deux colonnes (`grid-cols-2 sm:grid-cols-4`), les modales en feuille basse (UDR-0005), les boutons d'en-tête sous le titre.

**Refus** : 403 d'un geste (fonction insuffisante, requête forgée) → en Turbo Stream, toast `error` « Votre fonction ne permet pas ce geste. » ; en HTML, la page 403 commune. 404 → page 404 commune, ou toast `error` « Introuvable. » en Turbo Stream.

### 3.1 Shell et navigation — amende l'UDR-0006

- `NavigationHelper::DESTINATIONS[:school_admin]` : `[:home, :school_admin_home_path, "home"]`, `[:classrooms, :school_admin_classrooms_path, "squares-2x2"]`, `[:teachers, :school_admin_teachers_path, "user-group"]`, `[:students, :school_admin_students_path, "users"]`, `[:school, :school_admin_school_path, "building-library"]`. Libellé de la dernière : `shared.navigation.school` « Établissement ». Aucune entrée inactive.
- La page d'une classe déclare `content_for :nav_key, "classrooms"`.
- `ShellUser#detail` d'un `school_admin` : « <Fonction> · <Établissement> » (`Queries::Identity::ShellUserQuery`).
- `Authentication::HOME_ROUTES` gagne `school_admin_home: :school_admin_home_path`.

### 3.2 Accueil — tableau de bord (`school_admin/homes/show`)

**Structure**
- `ui_page_header(title: "Tableau de bord", subtitle: <nom de l'établissement>)`.
- `section#dashboard_totals` (`aria-labelledby="dashboard_totals_title"`, titre `sr-only` « Chiffres de l'établissement ») : grille `grid grid-cols-3 gap-3` de trois `ui_card(padding: :md)` (exception assumée à la règle des deux colonnes du §3.0 : trois chiffres courts tiennent à 390 px) : « Classes », « Enseignants », « Élèves » ; chiffre `text-3xl`, libellé `text-sm text-mute`. Chaque carte est un lien (`href:`) vers sa destination.
- `section#dashboard_classrooms` (`aria-labelledby`, `h2` « Mes classes ») : une `ui_card` contenant `ul` de `li#dashboard_classroom_<public_id>`, triés par niveau puis nom. Chaque `li` est un lien pleine largeur vers `school_admin_classroom_path` (`min-h-tap`), `grid grid-cols-2 sm:grid-cols-6 gap-2 py-3 border-t border-line` :
  - nom de la classe (`font-medium`, `sm:col-span-2`) et niveau (`text-sm text-mute`) ;
  - « Effectif » `34 / 80` ; « Devoirs » `12` ; « Rendu » `68 %` ; « Moyenne » `54 %`, chacun avec son libellé `text-2xs text-mute uppercase` au-dessus (visible en mobile, `sm:sr-only` en bureau, où une ligne d'en-tête `div[aria-hidden]` les porte).
  - Une valeur absente s'écrit « — » avec `aria-label` « non disponible ».
- Sous la liste, `p.text-sm.text-mute#dashboard_definitions` : « Rendu : part des élèves de la classe qui ont terminé au moins un exercice donné par un devoir. Moyenne : moyenne des exercices terminés de ces devoirs. »

**Comportement** : rendu serveur, sans frame (une seule query, ADR-0067). Aucune note d'élève, aucun nom d'élève dans la page.

**États obligatoires**
- Vide (aucune classe de l'année) : dans `#dashboard_classrooms`, `ui_empty_state(icon: "squares-2x2", title: "Aucune classe cette année", description: "Ajoutez vos classes depuis la page Classes.", action: { label: "Voir les classes", href: school_admin_classrooms_path })`. Les trois chiffres affichent `0`.
- Chargement : sans objet (rendu serveur ; Turbo pose `aria-busy`).
- Erreur : page 500 commune.
- Succès : les chiffres.

**Accessibilité** : chaque ligne est un seul lien dont le nom accessible est « <classe> : effectif 34 sur 80, 12 devoirs, rendu 68 %, moyenne 54 % » (`aria-label`). Cibles ≥ 48 px.

### 3.3 Classes (`school_admin/classrooms/index`) et « + »

**Structure**
- `ui_page_header(title: "Classes", subtitle: "Année <2026-2027>")`.
- `section#direction_level_classrooms` : même gabarit que `teams/schools/_level_classrooms` (UDR-0046), avec ces différences : **pas de « − »** ; sous le libellé de chaque ligne `li#level_classrooms_<key>`, les classes de la ligne en liens `ui_badge`-like (`a.inline-flex.min-h-tap.items-center.rounded-full.border.border-line.px-3.text-sm`) vers `school_admin_classroom_path` ; puis le compte et le « + ».
- « + » : `form_with url: school_admin_level_classrooms_path, method: :post` (`level`, `series` en champs cachés), `ui_button` `secondary` icône `plus`, texte `sr-only` « Ajouter une classe de <niveau> ». Affiché pour **toutes** les fonctions (ADR-0066), seulement si l'établissement est actif et le couple ouvert.

**Comportement**
- `POST /school-admin/level-classrooms` → `AddLevelClassroom` (policy `StaffPolicy`, `:add_classroom`) avec l'établissement de l'acteur.
- Succès : Turbo Stream `replace "level_classrooms_<key>"` + toast `success` « Classe « 6ème 5 » ajoutée. Code d'adhésion : KFM-37. » — le code est généré **à la création** de la classe (`ClassroomRepository#create`, comme la génération en masse), jamais plus tard ; repli HTML : 303 vers `school_admin_classrooms_path` avec `notice`.
- Refus : toast `error` au motif (textes de `teams.level_classrooms.errors`, repris dans `school_admin.level_classrooms.errors`), ligne re-rendue, statut 403 / 404 / 422.

**États** : vide → `ui_empty_state(icon: "academic-cap", title: "Aucun niveau ouvert", description: "Le référentiel ne propose aucun niveau à cet établissement. Contactez l'équipe Lnclass.")` ; chargement : `aria-busy` du formulaire pendant l'envoi ; erreur : toast ; succès : toast et ligne remplacée.

**Accessibilité** : `div[role=group]` de chaque ligne nommé « <niveau> : <n> classes » ; le « + » a son nom `sr-only` ; le résultat est annoncé par le toast (région `#toasts` `aria-live`) ; le focus n'est pas déplacé par le code (aucun contrôleur Stimulus nouveau) : après le `replace`, il revient au document, ce qui est accepté.

### 3.4 Page d'une classe (`school_admin/classrooms/show`)

**Structure**
- `content_for :nav_key, "classrooms"` ; lien retour `a#back-to-classrooms` « ← Classes » (`min-h-tap text-sm text-brand-strong`).
- `ui_page_header(title: <nom>, subtitle: "<niveau> · Année <2026-2027>")`.
- `ui_card#classroom_summary` : `dl` en `grid grid-cols-2 sm:grid-cols-4 gap-4` : « Effectif » `34 / 80`, « Devoirs donnés », « Taux de rendu », « Moyenne » (mêmes définitions et « — » que 3.2) ; puis bloc `#classroom_join_code` : libellé « Code d'adhésion », valeur `font-mono text-2xl font-bold tracking-widest` (`KFM-37`, `aria-labelledby`), bouton « Copier le code » (`secondary`, `sm`, `clipboard-document`, contrôleur `classroom--join-code-copy`, `aria-label` « Copier le code KFM-37 »), aide « À transmettre aux élèves de la classe : ils le saisissent pour s'inscrire. » ; si le code est fermé, « Code fermé » `ui_badge tone: :warning` et aucun bouton. **Ni « Régénérer » ni « Fermer »** pour la direction (V3, `vie-de-la-classe`).
- `ui_card#classroom_teachers` titre « Enseignants de la classe » : `ul` de noms avec `ui_subject_badge` de leur matière ; vide : `p.text-sm.text-mute` « Aucun enseignant ne s'est encore déclaré dans cette classe. ».
- Rangée d'actions : `ui_button` « Voir les élèves » (`primary`, icône `users`) vers `school_admin_students_path(classroom: public_id)` et « Voir les enseignants » (`secondary`, `user-group`) vers `school_admin_teachers_path(classroom: public_id)`.

**Comportement** : classe d'un autre établissement, archivée ou d'une autre année → 404. Aucune liste d'élèves, aucune note.

**États** : vide (classe sans élève) : effectif `0 / 80`, rendu et moyenne « — » ; chargement : sans objet ; erreur : 404 ; succès : la page.

**Accessibilité** : `dl` avec `dt`/`dd` ; code lu par son libellé ; cibles ≥ 48 px.

### 3.5 Enseignants (`school_admin/teachers/index`)

**Structure**
- `ui_page_header(title: "Enseignants", subtitle: "<n> enseignants")`.
- `form#teachers-filter` (GET, `role="search"`, `aria-label` « Filtrer les enseignants », `data-turbo-frame="teachers_list"`, `data-turbo-action="advance"`) : `select#teachers-filter-classroom` (`name="classroom"`, première option « Toutes les classes », puis les classes de l'année groupées par niveau en `optgroup`) et `ui_button` « Filtrer » `secondary` (le bouton reste pour le fonctionnement sans JavaScript ; `data-action="change->…"` n'est pas requis).
- `turbo_frame_tag "teachers_list"` contenant `ul#school_teachers` de `li#teacher_<public_id>` : `ui_avatar(name, size: :md)` (initiales, sans photo), nom (`font-medium`), `ui_subject_badge`, puis les classes de l'enseignant **dans cet établissement** en badges texte ; à droite, pour le Proviseur et le Censeur seulement, `ui_dropdown(label: "Actions pour <nom>")` avec l'item « Retirer de l'établissement » (`tone: :danger`, `dialog: "remove-teacher-<public_id>"`). Puis `ui_pagination(page:, pages:)`.
- `ui_modal(id: "remove-teacher-<public_id>", size: :sm, title: "Retirer <nom> de l'établissement ?")` : texte « <Prénom> ne verra plus l'établissement ni ses classes. Les classes, les devoirs et les résultats des élèves restent. Son compte reste actif : il pourra rejoindre un autre établissement avec son code, ou être réintégré depuis « Enseignants retirés ». » ; pied « Annuler » (`secondary`, `modal#close`) et « Retirer » (`danger`, `type: :submit`, `form: "remove-teacher-<public_id>-form"`) ; `form#remove-teacher-<public_id>-form` en `DELETE school_admin_teacher_path(public_id)`.

**Comportement**
- Filtre et pagination : GET dans le frame, URL avancée (`?classroom=…&page=…`) ; classe inconnue ou d'un autre établissement dans le filtre → ignorée (toutes les classes).
- Retrait : succès → Turbo Stream : toast `success` « <nom> a été retiré(e) de l'établissement. », `replace "teachers_list"` (page courante re-rendue, filtre gardé par les champs cachés `classroom` et `page` du formulaire de retrait) et `replace "departed_teachers"` (l'enseignant y apparaît) ; repli HTML : 303 vers `school_admin_teachers_path` avec `notice`. Refus : toast (403, 404).

**Enseignants retirés** (même page, sous la liste ; relecture du porteur, 2026-09-28)
- `turbo_frame_tag "departed_teachers", src: school_admin_departed_teachers_path, loading: :lazy` (squelette `ui_loading_state variant: :skeleton, lines: 2`), rendu par `school_admin/departed_teachers/index` : `ui_card#direction_departed_teachers`, `h2` « Enseignants retirés (<n>) », aide `text-sm text-mute` « Ils ne peuvent pas revenir seuls avec le code de l'établissement. » ; `ul#departed_teachers_list` de `li#departed_teacher_<public_id>` : `ui_avatar` (initiales), nom, `ui_subject_badge`, « Retiré(e) le <jj mois aaaa> » (`text-sm text-mute`) ; pour le Proviseur et le Censeur seulement, `ui_dropdown(label: "Actions pour <nom>")` avec l'item « Réintégrer dans l'établissement » (`icon: "arrow-uturn-left"`, `dialog: "reinstate-teacher-<public_id>"`), comme le retrait (UDR-0042). Pagination par 20 dans le frame.
- Confirmation `ui_modal(id: "reinstate-teacher-<public_id>", size: :sm, title: "Réintégrer <nom> ?")` : « <Prénom> retrouvera l'établissement dès sa prochaine page. Il ne retrouve pas ses classes : il s'y déclarera de nouveau, comme à son arrivée. » ; pied « Annuler », « Réintégrer » (`primary`, `type: :submit`) ; `form#reinstate-teacher-<public_id>-form` en `POST school_admin_teacher_reinstatement_path(public_id)`.
- Succès → Turbo Stream : toast `success` « <nom> est réintégré(e) dans l'établissement. », `replace "departed_teachers"` et `replace "teachers_list"` (première page, sans filtre) ; repli HTML : 303 vers `school_admin_teachers_path` avec `notice`. Refus : 403 (fonction) ou 404 (enseignant d'un autre établissement, plus réintégrable) en toast.
- États : vide → la carte n'affiche que `p.text-sm.text-mute` « Aucun enseignant retiré. » ; chargement : squelette du frame ; erreur : `ui_error_state(retry_href: school_admin_departed_teachers_path)` ; succès : liste.
- Accessibilité : le menu ⋮ porte le nom « Actions pour <nom> » ; confirmation en `<dialog>` native ; cibles ≥ 48 px ; 390 px.

**États**
- Vide (aucun enseignant) : `ui_empty_state(icon: "user-group", title: "Aucun enseignant pour l'instant", description: "Transmettez le code de l'établissement aux enseignants : ils s'inscrivent avec.", action: { label: "Voir le code", href: school_admin_school_path })`.
- Vide filtré : `ui_empty_state(icon: "magnifying-glass", title: "Aucun enseignant dans cette classe")`.
- Chargement : le frame porte `aria-busy` pendant le filtre (classes `aria-busy:opacity-50`, UDR-0006).
- Erreur : toast.
- Succès : la liste ; après retrait, la ligne disparaît.

**Accessibilité** : la liste est `aria-live="polite"` ; le menu ⋮ suit le motif « menu button » (UDR-0005, UDR-0042) ; la confirmation est une `<dialog>` native.

### 3.6 Élèves (`school_admin/students/index`) et changement de classe

**Structure de la liste**
- `ui_page_header(title: "Élèves", subtitle: "<n> élèves")` avec, en action, `ui_button` « Chercher par matricule » (`secondary`, icône `magnifying-glass`, `href: new_school_admin_student_placement_path`, `data: { turbo_frame: "modal" }`), pour **toutes** les fonctions, affiché seulement si la liste n'est pas vide.
- `form#students-filter` : comme 3.5 (`students_list`, `name="classroom"`).
- `turbo_frame_tag "students_list"` : `ul#school_students` de `li#student_<public_id>` : `ui_avatar` (initiales), nom, matricule (`font-mono tracking-wider text-sm text-mute`, `aria-label` « Matricule <valeur épelée> »), classe (badge texte) ; `ui_dropdown(label: "Actions pour <nom>")` avec l'item « Changer de classe » : `ui_dropdown_item` lien vers `school_admin_edit_student_placement_path(public_id)`, `frame: "modal"` — il ouvre directement l'étape 2 **par l'identifiant public** de l'élève, sans matricule ni compteur de débit. Aucun numéro de téléphone, aucune note. Puis `ui_pagination`.

**Structure de la modale** (`turbo_frame_tag "modal"` → `ui_modal(id: "student-placement-modal", open: true, title: "Changer un élève de classe")`)
- **Étape 1** (`new`, et re-rendu de `lookup` en échec) : `form#student-lookup-form` (`POST lookup_school_admin_student_placement_path`, scope `student_lookup`) : `ui_field :student_number`, libellé « Matricule de l'élève », `required`, `maxlength` 16, `autocomplete="off"`, `autocapitalize="characters"`, `spellcheck=false`, `inputmode="text"`, `placeholder` « 12345678A », classes `font-mono tracking-wider uppercase`, aide « Le matricule complet d'un élève de l'établissement, 8 chiffres et une lettre. ». Pied : « Annuler » et « Rechercher » (`type: :submit`, `form: "student-lookup-form"`).
- **Étape 2** (`edit`, `lookup` réussi, et re-rendu de `update` en échec) : `div#student-placement-candidate` (`bg-brand-soft border border-brand/30 rounded-ln px-4 py-3`) : nom en `font-display font-extrabold`, matricule `font-mono`, « Actuellement en <classe> ». Puis `form_with url: school_admin_update_student_placement_path(public_id), method: :patch` (`form#student-placement-form`, scope `student_placement`) — **toujours par l'identifiant public**, jamais de matricule, que l'étape vienne de la liste ou de la recherche — : `ui_field :classroom_public_id, as: :select` libellé « Nouvelle classe », `required`, classes actives de l'année de l'établissement groupées par niveau (« 6ème 2 — 34 / 80 »), la classe actuelle en `disabled` avec « (classe actuelle) ». Pied : « Retour » (`secondary`, lien vers `new_school_admin_student_placement_path`, `data-turbo-frame="modal"`, seulement après une recherche) ou « Annuler », et « Changer de classe » (`primary`, `type: :submit`).

**Comportement**
- `lookup` : format invalide → 422, étape 1, erreur sous le champ « Le matricule compte 8 chiffres et une lettre, par exemple 12345678A. », saisie gardée, **sans lecture en base** ; matricule inconnu, compte anonymisé, élève sans classe de l'année ou d'un autre établissement → **422, étape 1, champ re-rendu vide, erreur sous le champ « Aucun élève de l'établissement n'a ce matricule. Vérifiez-le auprès de l'élève. »** — mêmes octets pour tous ces cas, jeton CSRF excepté (le champ vide retire aussi le matricule de la réponse) ; trouvé → 200, étape 2.
- `edit` : élève qui n'est pas de l'établissement → 404 ; **hors** du compteur de débit.
- `update` : succès → Turbo Stream : toast `success` « <nom> est maintenant en <classe>. », `replace "students_list"` (première page, sans filtre), fermeture de la modale (`turbo_stream.update "modal", ""`) ; repli HTML : 303 vers `school_admin_students_path` avec `notice`. Classe pleine → 422, étape 2, alerte `role="alert"` `bg-error-soft text-error` « Cette classe est complète (80 / 80). Choisissez-en une autre. » ; déjà dans cette classe → 422, étape 2, « <nom> est déjà dans cette classe. » ; élève qui n'est plus de l'établissement, classe d'un autre établissement ou archivée → 404 (toast). **Hors** du compteur de débit.
- **Débit** (ADR-0065) : `lookup`, le seul qui reçoit un matricule, 10 par minute et 100 par jour par compte ; au-delà, **429**, la modale affiche `ui_error_state(title: "Trop de recherches", message: "Réessayez dans une minute.")` et aucun formulaire.
- Le matricule n'est jamais dans une URL ; `student_number` est filtré des journaux.

**États**
- Vide (aucun élève) : `ui_empty_state(icon: "users", title: "Aucun élève pour l'instant", description: "Les élèves rejoignent leur classe avec son code d'adhésion, affiché sur la page de chaque classe.", action: { label: "Voir les classes", href: school_admin_classrooms_path })`, sans « Chercher par matricule ».
- Vide filtré : « Aucun élève dans cette classe ».
- Chargement : `aria-busy` du frame et du formulaire de la modale.
- Erreur : sous le champ (étape 1), alerte (étape 2), `ui_error_state` (429), toast (403, 404).
- Succès : toast, liste remplacée, modale fermée.

**Accessibilité** : erreurs reliées par `aria-describedby`, `aria-invalid` (`ui_field`) ; à l'étape 2, le `select` porte `autofocus` (la modale s'ouvre avec la réponse du frame) ; l'encadré du candidat est `aria-live="polite"` ; cibles ≥ 48 px ; la modale est une feuille basse à 390 px.

### 3.7 Établissement (`school_admin/schools/show`), code et personnel

**Structure de la page** (Lot 0)
- `ui_page_header(title: <nom>, subtitle: "<DRENA> · <Public | Privé | Mixte>")`.
- `turbo_frame_tag "school_code", src: school_admin_school_code_path, loading: :lazy, class: "block transition-opacity aria-busy:pointer-events-none aria-busy:opacity-50" { ui_loading_state variant: :skeleton, lines: 3 }`.
- `turbo_frame_tag "school_staff", src: school_admin_staff_members_path, loading: :lazy, …` (même gabarit).

**Code** (`school_admin/school_codes/show`, rendu dans le frame `school_code`)
- `ui_card#direction_school_code` : gabarit du bloc `#school_code` de l'UDR-0044 (libellé, `span#school_code_value`, « Copier le code », « Copier le lien », aide, `a#school_code_link`), sans le menu ⋮.
- Pour le Proviseur et le Censeur : `ui_modal(id: "regenerate-school-code", size: :sm, trigger: "Régénérer le code", trigger_variant: :secondary, trigger_icon: "arrow-path")`, titre « Régénérer le code de l'établissement ? », texte de l'UDR-0044 **plus** « Les liens d'invitation déjà partagés par vos enseignants cesseront aussi de fonctionner. » ; `form#regenerate-school-code-form` en `PATCH school_admin_school_code_path`.
- `PATCH` : succès → Turbo Stream : toast `success` « Nouveau code d'établissement : <K7M-4QZ>. » et `replace "direction_school_code"` ; repli HTML : 303 vers `school_admin_school_path`. Refus → toast 403.
- États : vide sans objet ; chargement : squelette du frame ; erreur : `ui_error_state(retry_href: school_admin_school_code_path)` si le frame échoue, toast si le geste échoue ; succès : toast et bloc remplacé.

**Personnel** (`school_admin/staff_members/index`, rendu dans le frame `school_staff`)
- `ui_card#direction_staff` : `h2` « Personnel de direction (<n>) » ; pour le Proviseur et le Censeur, `ui_button` « Inviter un membre » (`secondary`, `user-plus`, `href: new_school_admin_staff_invitation_path`, `data: { turbo_frame: "modal" }`).
- `ul#staff_members` de `li#staff_member_<user_public_id>` : `ui_avatar` (initiales), nom, badge de fonction, « Depuis le <jj mois aaaa> » (`text-sm text-mute`), `ui_badge("Vous", tone: :info)` pour soi. Menu ⋮ « Retirer » (`danger`, `dialog: "remove-staff-<user_public_id>"`) seulement pour le Proviseur et le Censeur, **ni sur soi ni sur un Proviseur**.
- Confirmation `remove-staff-<user_public_id>` : « Retirer <nom> du personnel ? », « <Prénom> sera déconnecté(e) et ne verra plus l'établissement. Son compte reste, sans accès. » ; `DELETE school_admin_staff_member_path(user_public_id)`.
- Succès : toast « <nom> a été retiré(e) du personnel. » et `replace "direction_staff"` ; repli HTML : 303 vers `school_admin_school_path`.
- États : vide impossible (l'acteur en fait partie) ; chargement : squelette ; erreur : `ui_error_state(retry_href:)` ; succès : liste.

**Invitation** (`school_admin/staff_invitations/new`, `create` ; côté équipe `teams/school_staff_invitations`) — partiels partagés `shared/staff_invitations/_form` et `_created`
- `ui_modal(id: "staff-invitation-modal", open: true, title: "Inviter un membre de la direction")` : `form#staff-invitation-form` (scope `staff_invitation`) : `ui_field :contact, as: :tel` (« Numéro de téléphone », aide « 10 chiffres. Ce numéro ne doit pas déjà avoir un compte Lnclass. ») et `ui_radio_group :position` (« Fonction ») : les fonctions que l'acteur peut inviter : Censeur, Éducateur, Secrétaire pour la direction ; les quatre, Proviseur compris, pour l'équipe seulement (ADR-0066 §4.3). Pied : « Annuler », « Créer le lien d'invitation ».
- Succès : `turbo_stream.update "modal"` avec `_created` (gabarit de `teams/invitations/_created`, UDR-0019) : « Invitation de <07 00 00 00 09> comme <Censeur> à <établissement>. », champ en lecture seule du lien, « Copier le lien » (`classroom--join-code-copy`), consigne « Transmettez ce lien à la personne invitée, hors de Lnclass. Il expire dans 72 heures. », encadré `bg-warning-soft` « Ce lien ne s'affichera qu'une fois. ». Repli HTML : page `created`, 201.
- Erreurs (422, sous le champ) : « Ce numéro a déjà un compte Lnclass. » ; « Une invitation est déjà en cours pour ce numéro. » ; « L'établissement a déjà un Proviseur. » (sous la fonction) ; établissement non actif → alerte `role="alert"` « L'établissement n'est pas actif. ».
- **Débit** : 30 invitations par heure et par compte (direction et équipe) ; au-delà, 429 et `ui_error_state(title: "Trop d'invitations", message: "Réessayez dans une heure.")` dans la modale.

**Accessibilité** : frames `aria-busy` ; boutons de copie nommés ; confirmations en `<dialog>` ; `ui_radio_group` en `<fieldset>` avec `<legend>` ; cibles ≥ 48 px.

### 3.8 Acceptation d'une invitation de direction — amende l'UDR-0019

- `identity/invitations/show` pour `kind = "school_staff"` : titre « Rejoindre la direction de <établissement> », sous-titre « Fonction : <Censeur> » (bandeau `bg-brand-soft`, icône `building-library`), puis **le même formulaire** que l'équipe (nom, prénoms, genre, PIN et confirmation, UDR-0019).
- Succès : même issue que l'équipe (UDR-0019 : page de connexion et son toast, puis activation du second facteur, codes de secours) ; « Terminé » mène à `school_admin_home_path` (§3.12). Aucun toast propre à la direction.
- `:conflict` (Proviseur déjà pris, établissement inactif) : alerte `role="alert"` « Cette invitation ne peut plus être acceptée. Demandez-en une nouvelle. », sans formulaire ; lien périmé : page existante.

### 3.9 Écran d'attente — amende l'UDR-0050

Toute la vue (quatre cas) et `Identity::PendingAccountsController` appartiennent au socle (Lot 0b) ; `Identity::SchoolRejoinsController` (Lot C) la re-rend en erreur.

Ordre du premier cas applicable dans `identity/pending_accounts/show` :

1. `school_admin` sans établissement : `ui_empty_state(icon: "building-library", title: "Aucun établissement", description: "Votre compte de direction n'est rattaché à aucun établissement actif. Contactez l'équipe Lnclass.")`, boutons « Mon profil » (`secondary`, `profile_path`) et « Se déconnecter ».
2. `teacher` avec demande `pending` : inchangé (UDR-0050) ; demande `rejected` : texte inchangé, suivi du formulaire de code du cas 3.
3. `teacher` sans école principale, sans demande en attente (retiré, ou demande approuvée puis retiré) : `ui_empty_state(icon: "building-library", title: "Vous n'êtes rattaché à aucun établissement", description: "Saisissez le code de votre nouvel établissement pour le rejoindre. Retiré par erreur ? Demandez à votre ancienne direction de vous réintégrer.")`, puis `form#school-rejoin-form` (`POST school_rejoin_path`, scope `school_rejoin`) : `ui_field :school_code` au gabarit de l'UDR-0044 (« Code d'établissement », `K7M-4QZ`, mêmes erreurs), bouton « Rejoindre l'établissement » (`brand`, pleine largeur) ; puis « Se déconnecter ».
4. Les autres cas : inchangés.

- `POST /account/pending/school` (`Identity::SchoolRejoinsController`, Lot C) : succès → 303 vers `teacher_home_path`, toast « Bienvenue à <établissement>. » ; erreur (dont l'établissement qui a retiré l'enseignant, ADR-0066) → 422, l'écran d'attente re-rendu **par ce contrôleur avec la vue `identity/pending_accounts/show`** (variables `@case = :teacher_without_school`, `@rejoin` : le DTO en erreur), saisie gardée ; **10 par minute et par adresse**, compteur propre à ce contrôleur ; au-delà, 429, `ui_error_state` « Trop de tentatives ».
- Cas `rejected` (2) : sous le texte existant, le même formulaire de code que le cas 3 (une demande refusée n'empêche pas de rejoindre un autre établissement par son code).
- Accessibilité : erreur reliée au champ ; cibles ≥ 48 px ; 390 px.

### 3.10 Fiche de l'établissement côté équipe — amende l'UDR-0036

- Dans `teams/schools/show`, après l'en-tête et avant les classes, `turbo_frame_tag "school_staff", src: school_staff_members_path(school.public_id), loading: :lazy` (squelette).
- `teams/school_staff_members/index` : `turbo_frame_tag "school_staff"` contenant `ui_card#teams_school_staff` « Direction (<n>) », bouton « Inviter la direction » (`secondary`, `user-plus`, modale `shared/staff_invitations`, toutes fonctions proposées) ; liste au gabarit de 3.7, menu ⋮ « Retirer » sur **chaque** membre, Proviseur compris. Vide : `ui_empty_state(icon: "user-group", title: "Aucun membre de la direction", description: "Invitez le Proviseur : l'établissement pourra se gérer lui-même.")`.
- Retrait : succès → toast et `replace "teams_school_staff"` (la carte, jamais le frame, pour que le frame reste rechargeable) ; repli HTML : 303 vers la fiche.

### 3.11 Profil de la direction — amende l'UDR-0041

- `identity/profiles/_information` pour `school_admin` : le badge « En attente » disparaît ; à sa place, le badge de la fonction. Une ligne de la `dl` « Établissement » : « <Fonction> · <Établissement> », ou « Aucun établissement » (`text-mute`). Nom, numéro, PIN et photo : inchangés (ID-19, ID-20).

### 3.12 Second facteur de la direction — amende l'UDR-0019

- `identity/second_factors/new` et `identity/second_factor_enrollments/new` : sous-titre « Obligatoire pour l'équipe et la direction. » (au lieu de « … les comptes de l'équipe. »). Rien d'autre ne change à l'écran.
- Vérification réussie : `redirect_to_home` (accueil du rôle : `team_home_path` ou `school_admin_home_path`), toast inchangé.
- Codes de secours : le bouton « Terminé » mène à `home_path_for(current_actor.role)`.
- États, accessibilité, 390 px : ceux de l'UDR-0019, inchangés.

## 4. Conséquences

- La navigation de la direction a **5 destinations**, le maximum de l'UDR-0006 : toute destination de plus pour ce rôle exige une nouvelle UDR.
- Les sections d'accueil `HOME_SECTIONS[:school_admin]` ne servent plus : l'accueil de la direction est son tableau de bord.
- C-31 est fermée pour la direction ; l'UDR-0002 n'a plus de section en vigueur pour l'organisation scolaire (équipe : UDR-0036, 0044, 0046 ; direction : celle-ci).
- Interdit désormais dans l'espace direction : un identifiant d'établissement dans une URL, un numéro de téléphone d'élève ou d'enseignant, une note d'élève nommé, une recherche partielle par matricule, une recherche d'élève hors de l'établissement, un bouton de geste que la fonction ne permet pas.
- `shared/staff_invitations/` est le seul gabarit d'invitation de la direction, pour l'équipe comme pour la direction.
- Les photos ne s'affichent pas dans les listes de la direction (initiales) tant que la règle de lecture d'un compte (ADR-0060) n'est pas élargie.
