# UDR-0056 : Les gestes de la direction — une page « Établissement » (lien et classes), un retrait confirmé en modale, une liste des enseignants retirés, un code saisi depuis l'écran d'attente

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-10-01)* |
| **Date** | 2026-10-01 |
| **Chantier** | [`docs/chantiers/gestion-etablissement-direction`](../../chantiers/gestion-etablissement-direction/prd.md) — critères GD-01 à GD-27 |
| **ADR lié** | [ADR-0071](../adr/0071-gestes-de-la-direction-sur-son-etablissement.md) · [ADR-0065](../adr/0065-espace-direction-simple-en-lecture-seule.md) · [ADR-0057](../adr/0057-code-d-etablissement.md) · [ADR-0059](../adr/0059-ajuster-les-classes-d-un-niveau.md) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0042](0042-actions-de-ligne-dans-un-menu.md) · [UDR-0054](0054-finitions-d-interface.md) |
| **Amende** | [UDR-0052](0052-espace-direction-simple.md) (troisième destination, menu ⋮ sur « Enseignants ») · [UDR-0046](0046-classes-par-niveau.md) (le bloc « Classes par niveau » devient un partiel partagé) · [UDR-0050](0050-inviter-un-collegue-et-croissance.md) (écran d'attente de l'enseignant sans établissement) |
| **Remplacé par** | — |

---

## 1. Contexte

La direction lit deux pages (UDR-0052) et appelle l'équipe pour tout le reste. Elle travaille souvent sur un téléphone Android d'entrée de gamme, entre deux cours : elle doit **trouver le lien à partager en un geste**, ajouter une classe sans formulaire, et faire partir un enseignant sans risque d'erreur. Un enseignant retiré doit comprendre ce qui lui arrive et savoir quoi faire.

## 2. Décision

1. **Une troisième destination, « Établissement »** : en tête, le lien d'inscription des enseignants (copier, WhatsApp, changer) ; dessous, le bloc « Classes par niveau » de l'équipe, à l'identique.
2. **Le code n'a pas d'écran à lui** : la direction le voit dans son lien et le change par « Changer le lien » (confirmé).
3. **« Retirer de l'établissement »** est un item du menu ⋮ de la ligne d'un enseignant (UDR-0042), **confirmé en modale**, qui dit ce qui disparaît (classes, devoirs actifs) et ce qui reste.
4. **« Enseignants retirés »** est une page sœur, liée depuis « Enseignants », avec un bouton « Réintégrer » par ligne, sans confirmation (geste qui ne détruit rien).
5. **L'écran d'attente** d'un enseignant sans établissement porte le champ « Code d'établissement ».
6. Un établissement non actif : tout se lit, **aucun bouton de geste n'est affiché** ; le serveur refuse de toute façon (403).

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.0 Commun

**Routes** (Lot 0, `config/routes/school_admin.rb`, dans le `scope "school-admin", module: "school_admin", as: "school_admin"` existant) :

| Verbe et chemin | Action | Nom de route |
|---|---|---|
| `GET /school-admin/school` | `schools#show` | `school_admin_school_path` |
| `PATCH /school-admin/school/link` | `school_links#update` | `school_admin_school_link_path` |
| `POST /school-admin/school/level-classrooms` | `level_classrooms#create` | `school_admin_level_classrooms_path` |
| `DELETE /school-admin/school/level-classrooms/:public_id` | `level_classrooms#destroy` | `school_admin_level_classroom_path` |
| `GET /school-admin/teachers/departed` | `departed_teachers#index` | `school_admin_departed_teachers_path` |
| `DELETE /school-admin/teachers/:public_id` | `teachers#destroy` | `school_admin_teacher_path` |
| `POST /school-admin/teachers/:public_id/reinstatement` | `teacher_reinstatements#create` | `school_admin_teacher_reinstatement_path` |

Déclaration : `get "teachers/departed", to: "departed_teachers#index", as: :departed_teachers` **avant** `resources :teachers, only: %i[index destroy], param: :public_id` ; `resource :school, only: :show do resource :link, only: :update, controller: "school_links" ; resources :level_classrooms, only: %i[create destroy], path: "level-classrooms", param: :public_id end` ; `post "teachers/:public_id/reinstatement", to: "teacher_reinstatements#create", as: :teacher_reinstatement`. Côté identité (`config/routes/identity.rb`) : `post "account/pending/school", to: "identity/pending_school_joins#create", as: :pending_school_join`.

**Contrôleurs** : tout contrôleur `SchoolAdmin::` hérite de `SchoolAdmin::BaseController` ; l'établissement est `current_actor.school_id`, **jamais** un paramètre ; une ressource d'un autre établissement répond 404 (`render_not_found`).

**Tokens** : composants `ui_*` et tokens `@theme` de l'UDR-0005 seulement ; aucune valeur arbitraire `[…]`, aucun `#hex`.

**Refus** : en Turbo Stream, `turbo_stream_toast` `type: :error` avec le texte du motif (`school_admin.shared.errors.<code>` : `forbidden` « Vous n'avez pas accès à cette action. », `not_found` « Introuvable. ») ; en HTML, les pages 403 et 404 communes.

**390 px** : chaque page est prouvée à 390 px sans défilement horizontal de la page ; les rangées de boutons passent en colonne (`flex flex-col gap-3 sm:flex-row`).

### 3.1 Navigation — amende l'UDR-0052

- `NavigationHelper::DESTINATIONS[:school_admin]` : `[:student_work, :school_admin_classrooms_path, "chart-bar"]`, `[:teachers, :school_admin_teachers_path, "user-group"]`, `[:school, :school_admin_school_path, "building-library"]`. Libellé : `shared.navigation.school` « Établissement ».
- `school_admin/departed_teachers/index` déclare `content_for :nav_key, "teachers"`.

### 3.2 Établissement (`school_admin/schools/show`)

**Structure**
- `page_title t(".page_title")` « Établissement » ; `content_for :nav_key, "school"`.
- `ui_page_header(title: <nom>, subtitle: "<Public | Privé | Mixte>")` (`t("school_types.<type>")`).
- Si l'établissement n'est pas actif : `p#school_inactive_notice.text-sm.text-warning` « Cet établissement n'est pas actif : vous pouvez consulter, mais pas modifier. ».
- `ui_card#school_link(title: "Inviter vos enseignants", subtitle: "Ils s'inscrivent avec ce lien : votre établissement est déjà rempli.", padding: :md)` contenant `div#school_link_block` (cible du Turbo Stream) :
  - `p` libellé `span#school_link_label.text-sm.text-mute` « Lien d'inscription », valeur `a#school_link_value.font-mono.text-sm.text-brand-strong.break-all` (`href` = `school_code_signup_url(school_code)`, `aria-labelledby="school_link_label"`) ;
  - `p.text-sm.text-mute` « Code d'établissement : » suivi de `span#school_code_value.font-mono.font-bold.tracking-widest` (`Entities::School::SchoolCode.display`, ex. `K7M-4QZ`) ;
  - rangée `div.mt-4.flex.flex-col.gap-3.sm:flex-row` : `ui_copy_button(<lien>, label: "Copier le lien", copied: "Lien copié", aria_label: "Copier le lien d'inscription")` ; `ui_button "Partager sur WhatsApp"`, `href: whatsapp_share_url(message)`, `variant: :brand`, `size: :sm`, `icon: "chat-bubble-left-right"`, `target: "_blank"`, `rel: "noopener"`, `id: "school_link_whatsapp"`, message « Bonjour ! Inscrivez-vous sur Lnclass comme enseignant de <nom> avec ce lien, l'établissement est déjà rempli : <lien> » ;
  - **établissement actif seulement** : `ui_modal(id: "change-school-link", size: :sm, title: "Changer le lien d'inscription ?", trigger: "Changer le lien", trigger_variant: :secondary, trigger_icon: "arrow-path")`, texte « L'ancien lien et l'ancien code cesseront aussitôt de fonctionner, liens de parrainage des enseignants compris. Les enseignants déjà inscrits restent dans l'établissement. Faites-le si le lien a circulé hors de l'établissement. », pied « Annuler » (`secondary`, `data: { action: "modal#close" }`) et « Changer le lien » (`danger`, `type: :submit`, `form: "change-school-link-form"`) ; `form_with url: school_admin_school_link_path, method: :patch, id: "change-school-link-form"`.
- Puis le bloc « Classes par niveau » : `render "shared/level_classrooms", block: @level_classrooms, add_url: school_admin_level_classrooms_path, remove_url: ->(public_id) { school_admin_level_classroom_path(public_id) }`.

**Partiel partagé `shared/_level_classrooms`** (amende l'UDR-0046) : c'est `teams/schools/_level_classrooms` **déplacé à l'identique**, avec deux locales en plus, `add_url:` (chaîne) et `remove_url:` (lambda `public_id → chemin`), à la place de `school_level_classrooms_path(block.school_public_id)` et `school_level_classroom_path(block.school_public_id, …)`. Clés de locale inchangées (`teams.level_classrooms.block.*`). La fiche de l'équipe l'appelle avec ses routes ; aucun changement visible pour l'équipe.

**Comportement**
- `PATCH school/link` → `RegenerateSchoolCode` (policy `ManageSchoolStructurePolicy`). Succès : Turbo Stream `turbo_stream.replace "school_link_block"` (bloc re-rendu avec le nouveau lien) + `turbo_stream_toast` `success` « Nouveau lien d'inscription : <K7M-4QZ>. » ; repli HTML : 303 vers `school_admin_school_path`, `notice`. Refus : toast (403).
- `POST` / `DELETE level-classrooms` → `AddLevelClassroom` / `RemoveLevelClassroom` avec le `public_id` de l'établissement de l'acteur. Turbo Stream : comme `teams/level_classrooms/update.turbo_stream.erb` (toast `@notice` ou `@alert`, `turbo_stream.replace "school_level_classrooms", method: :morph`), motifs `teams.level_classrooms.errors.*` ; repli HTML : 303 vers `school_admin_school_path`.

**États obligatoires**
- Vide : bloc des classes sans niveau → état vide du partiel (inchangé). Le lien n'est jamais vide (tout établissement a un code).
- Chargement : `aria-busy` posé par Turbo sur le formulaire pendant l'envoi.
- Erreur : toast `error`.
- Succès : toast `success`, bloc remplacé.

**Accessibilité** : la modale est une `<dialog>` native (focus piégé, Échap) ; le bouton de copie a son `aria-label` ; les « + » et « − » gardent leur nom `sr-only` (UDR-0046) ; cibles ≥ 48 px.

### 3.3 Enseignants (`school_admin/teachers/index`) — amende l'UDR-0052

- Dans `ui_page_header`, en action : `ui_button "Enseignants retirés"`, `href: school_admin_departed_teachers_path`, `variant: :secondary`, `size: :sm`, `icon: "archive-box"`.
- Le tableau gagne une 4ᵉ colonne `th scope="col"` `<span class="sr-only">Actions</span>`. Chaque `tr` devient `tr#teacher_<public_id>` (et non plus `teacher_<index>`).
- **Établissement actif seulement**, dans la dernière cellule (`td.px-4.py-3.text-right`) : `ui_dropdown(label: "Actions pour <nom>", id: "teacher-actions-<public_id>", fixed: true)` avec `ui_dropdown_item "Retirer de l'établissement", dialog: "remove-teacher-<public_id>", icon: "user-minus", tone: :danger`.
- `ui_modal(id: "remove-teacher-<public_id>", size: :sm, title: "Retirer <nom> de l'établissement ?")` : texte « <Prénom> ne verra plus l'établissement ni ses classes. Ses devoirs encore actifs seront archivés : les élèves ne les verront plus à faire. Les classes, les élèves et leurs résultats restent. Vous pourrez le réintégrer depuis « Enseignants retirés ». » ; pied « Annuler » et « Retirer » (`danger`, `type: :submit`, `form: "remove-teacher-<public_id>-form"`) ; `form_with url: school_admin_teacher_path(public_id), method: :delete, id: "remove-teacher-<public_id>-form"`.
- `DELETE` → `DetachTeacher`. Succès : Turbo Stream `turbo_stream.remove "teacher_<public_id>"` + toast `success` « <nom> a été retiré(e) de l'établissement. <n> devoir(s) archivé(s). » ; si plus aucune ligne, `turbo_stream.replace "school_teachers"` par l'état vide existant. Repli HTML : 303 vers `school_admin_teachers_path`, `notice`. Refus : toast (403, 404).

**États** : vide → état vide existant ; chargement : `aria-busy` du formulaire de la modale ; erreur : toast ; succès : ligne retirée, toast.

**Accessibilité** : menu ⋮ au motif « menu button » (UDR-0042) ; confirmation en `<dialog>` ; la modale se ferme avec la ligne qu'elle confirmait ; le résultat est annoncé par le toast (annoncé par le lecteur d'écran, comme tous les toasts) ; cibles ≥ 48 px.

### 3.4 Enseignants retirés (`school_admin/departed_teachers/index`)

**Structure**
- `page_title` « Enseignants retirés » ; `content_for :nav_key, "teachers"` ; lien retour `a#back-to-teachers` « ← Enseignants » (`min-h-tap text-sm text-brand-strong`, motif de l'UDR-0054).
- `ui_page_header(title: "Enseignants retirés", subtitle: "<nom de l'établissement>")`.
- `ui_card#departed_teachers(padding: :none)` → `ul.divide-y.divide-line` de `li#departed_teacher_<public_id>.flex.flex-col.gap-3.p-4.sm:flex-row.sm:items-center.sm:justify-between` : nom (`font-medium`), `ui_subject_badge` de la matière (ou « — » `aria-hidden` + « non calculé » `sr-only`), « Retiré le <jj mois aaaa> » (`text-sm text-mute`, `l(date, format: :long)`) ; **établissement actif seulement** : `button_to "Réintégrer", school_admin_teacher_reinstatement_path(public_id), method: :post, form: { id: "reinstate-<public_id>-form" }` rendu par `ui_button "Réintégrer", type: :submit, variant: :secondary, size: :sm, icon: "arrow-uturn-left"`.

**Comportement** : `POST reinstatement` → `ReinstateTeacher`. Succès : Turbo Stream `turbo_stream.remove "departed_teacher_<public_id>"` + toast « <nom> est de nouveau dans l'établissement. Il doit redéclarer ses classes. » ; liste devenue vide → `turbo_stream.replace "departed_teachers"` par l'état vide. Repli HTML : 303 vers `school_admin_departed_teachers_path`. Refus : toast (403, 404).

**États obligatoires**
- Vide : `ui_empty_state(icon: "archive-box", title: "Aucun enseignant retiré", description: "Un enseignant retiré de l'établissement apparaît ici, et vous pouvez le réintégrer.")`, dans `div#departed_teachers`.
- Chargement : `aria-busy` du formulaire.
- Erreur : toast.
- Succès : ligne retirée, toast.

**Accessibilité** : liste `aria-label` « Enseignants retirés » ; chaque bouton a un nom accessible « Réintégrer <nom> » (`aria-label`) ; cibles ≥ 48 px.

### 3.5 Écran d'attente — amende l'UDR-0050

Dans `identity/pending_accounts/show`, pour un `teacher` **sans établissement** dont la demande n'est **pas** `pending` (aucune demande, ou `approved`, ou `rejected`) :

- `ui_empty_state(icon: "building-library", title: "Vous n'êtes rattaché à aucun établissement", description: "Saisissez le code de votre établissement pour le rejoindre. Il vous a été transmis par sa direction.")` ; une demande `rejected` garde au-dessus son message existant.
- Sous l'état vide : `form_with model: @school_join, scope: :school_join, url: pending_school_join_path, id: "school-join-form"` : `ui_field f, :school_code` au gabarit de l'inscription enseignant (UDR-0044 : libellé « Code d'établissement », `placeholder` « K7M-4QZ », aide « 6 caractères, transmis par votre établissement. », `autocomplete="off"`, `autocapitalize="characters"`, classes `font-mono tracking-wider uppercase`), puis `ui_button "Rejoindre l'établissement", type: :submit, variant: :brand, full: true` ; puis « Se déconnecter » (inchangé).
- **Par le lien d'invitation** (porteur, 2026-10-01) : `GET /e/<code>` ouvert par un enseignant **connecté**, sans établissement et sans demande `pending`, répond 303 vers `pending_account_path(school_code: <code>)` ; l'écran d'attente pré-remplit `school_join[school_code]` avec ce code (affiché `K7M-4QZ`) et ne rejoint **rien** sans le clic « Rejoindre l'établissement ». Un code invalide arrive pré-rempli lui aussi et reçoit l'erreur à l'envoi. Tout autre compte connecté qui ouvre le lien garde le comportement actuel (son accueil). Le lien compte dans la limite de débit existante de `/e/<code>` (`school_code`, 10 par minute et par adresse).
- `POST /account/pending/school` → `JoinSchoolWithCode`. Succès : 303 vers `teacher_classrooms_path`, `notice` « Bienvenue à <établissement>. Sélectionnez vos classes. » ; erreur : 422, écran re-rendu, saisie gardée, erreur sous le champ « Code d'établissement invalide. Vérifiez-le auprès de votre établissement. » ; **10 par minute et par adresse** ; au-delà, 429, `ui_error_state(title: "Trop de tentatives", message: "Réessayez dans une minute.")` à la place du formulaire ; demande en attente → 403.

**États** : vide (le formulaire) ; chargement : `aria-busy` du formulaire ; erreur : sous le champ (422), `ui_error_state` (429) ; succès : redirection.

**Accessibilité** : erreur reliée au champ (`aria-describedby`, `aria-invalid` par `ui_field`) ; cibles ≥ 48 px ; 390 px.

## 4. Conséquences

- La direction a **3 destinations** ; il en reste deux avant le maximum de l'UDR-0006.
- Le bloc « Classes par niveau » n'existe plus qu'en un exemplaire, partagé par l'équipe et la direction.
- Interdit dans l'espace direction : un identifiant d'établissement dans une URL ; un bouton de geste sur un établissement non actif ; un retrait sans confirmation.
- Les fonctions de direction (Chef d'établissement, ACE ou Directeur des études, Éducateur, Secrétaire) ne sont pas affichées : elles viendront avec leur propre UDR.
