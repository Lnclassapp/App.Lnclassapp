# Plan d'exécution — Finitions UX

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Entrées : [`prd.md`](prd.md) (FU-01 à FU-54), [UDR-0054](../../decisions/udr/0054-finitions-d-interface.md) (§3 = contrat de chaque lot).

## Principe du découpage

Les sept finitions touchent souvent **la même vue** (une page reçoit à la fois son titre, son retour, son auto-focus et une infobulle). Un lot par finition ferait se croiser tous les lots sur les mêmes fichiers. Le découpage est donc :

- **Lot 0** : toutes les **briques** (helpers, partials, contrôleurs Stimulus, layout, CSS, locales communes, `/design`), et rien d'autre ;
- **un lot vertical par espace** (ou par parcours), qui applique les sept finitions à **ses** écrans : chaque vue, chaque locale d'écran, chaque test d'écran n'appartient qu'à un lot ;
- **Lot Z** : les gardes qui ne passent qu'une fois tous les écrans migrés (test des titres, suppression de l'ancien contrôleur de copie, retrait du repli `content_for :title`), puis la passe complète.

Chaque lot vertical est démontrable seul : à sa fin, les écrans de son espace ont leurs sept finitions, les autres gardent leur rendu actuel (le layout garde un repli pour les titres non migrés).

## Graphe

```
Lot 0 — SOCLE : briques des finitions (séquentiel)
  ↓
  ├─► Lot A  Entrée publique et invitation                 ┐
  ├─► Lot B  Second facteur et codes de secours          │
  ├─► Lot C1 Équipe : référentiel                        │
  ├─► Lot C2 Équipe : contenu et imports                 │
  ├─► Lot D1 Équipe : établissements                     ├─ en parallèle, fichiers disjoints
  ├─► Lot D2 Équipe : accueil, comptes, pilotage, croissance, invitation équipe │
  ├─► Lot E  Enseignant : classe, cours dans la classe, parrainage │
  ├─► Lot F  Catalogue, exercice, élève                  │
  ├─► Lot H  Profil et pages de compte                   │
  └─► Lot G  Direction (pages de l'espace direction simple)  ┘
  ↓
Lot Z — CLÔTURE : gardes globales + passe complète (séquentiel)
```

---

## Lot 0 — Socle : briques des finitions

- **Couche**       : infrastructure + delivery + ui (briques partagées, aucun écran métier)
- **Fichiers**     : app/helpers/page_title_helper.rb *(nouveau : `page_title`, `document_title`)*
                     app/helpers/components_helper.rb *(`ui_back_link`, `ui_info_tip`, `ui_copy_button`, `ui_page_header(back:)`, `ui_modal(document_title:)`, `ui_field(autofocus:)`)*
                     app/helpers/navigation_helper.rb *(`back_href`)*
                     app/views/components/_back_link.html.erb *(nouveau)*
                     app/views/components/_info_tip.html.erb *(nouveau)*
                     app/views/components/_copy_button.html.erb *(nouveau)*
                     app/views/components/_page_header.html.erb
                     app/views/components/_modal.html.erb *(contrôleur `autofocus` sur la `<dialog>`, pied marqué `data-autofocus-footer`)*
                     app/views/components/_field.html.erb
                     app/views/layouts/application.html.erb *(`document_title` avec repli `content_for :title`, `autofocus` sur `<body>`, `print:hidden` sur les toasts ; la ligne `secret_response_meta_tag` reste)*
                     app/javascript/controllers/clipboard_controller.js *(nouveau)*
                     app/javascript/controllers/autofocus_controller.js *(nouveau)*
                     app/javascript/controllers/autosubmit_controller.js *(nouveau)*
                     app/javascript/controllers/search_controller.js *(nouveau)*
                     app/javascript/controllers/download_controller.js *(nouveau)*
                     app/javascript/controllers/modal_controller.js *(`modal:opened`, titre de l'onglet)*
                     app/assets/stylesheets/application.tailwind.css *(`@utility summary-plain`)*
                     app/infrastructure/queries/shared/text_search.rb *(nouveau : fragment sans casse ni accents)*
                     config/locales/shared/components.fr.yml
                     config/locales/shared/layouts.fr.yml *(espaces du titre, messages de copie, libellés des briques)*
                     app/views/design/index.html.erb
                     app/views/design/frame.html.erb
                     app/views/design/modal.html.erb
                     app/views/design/shell.html.erb
                     app/controllers/design_controller.rb
                     config/locales/design/index.fr.yml *(section « Finitions »)*
                     test/design/design_tokens_test.rb *(si l'utilitaire l'exige)*
- **Dépend de**    : —
- **Test associé** : test/system/design_system_test.rb (section « Finitions » : FU-29, FU-39 et FU-51 sur la démonstration, auto-focus d'une modale et d'une confirmation, titre d'une modale, infobulle à 390 px) · test/helpers/page_title_helper_test.rb · test/helpers/components_helper_test.rb · test/helpers/navigation_helper_test.rb · test/infrastructure/queries/shared/text_search_test.rb
- **Done quand**   : sur `/design`, section « Finitions », chaque brique marche dans Chrome (copie et son échec, envoi automatique une seule fois, recherche qui attend 300 ms et remplace l'URL, modale qui vise son premier champ et confirmation qui vise « Annuler », titre de l'onglet qui change à l'ouverture d'une modale, infobulle sans débordement à 390 px) ; les écrans métier ne changent que par ce que portent les composants (focus des modales et des confirmations, `autofocus` existants devenus des cibles du contrôleur) ; `bin/check-asset-budget` passe

> Le Lot 0 dépasse une poignée de fichiers parce qu'il porte **sept** briques, pas du métier : aucun écran, aucune route, aucune migration. Il **gèle** leurs API (UDR-0054 §3) : un lot vertical qui aurait besoin d'en changer une s'arrête et le Lot 0 rouvre.

---

## Lot A — Entrée publique et invitation

- **Couche**       : delivery + ui
- **Fichiers**     : app/controllers/identity/invitations_controller.rb *(`session[:login_contact]` au succès, aucune session d'authentification)*
                     app/controllers/identity/sessions_controller.rb *(`new` lit et supprime `session[:login_contact]`)*
                     app/views/identity/invitations/show.html.erb
                     app/views/identity/sessions/new.html.erb
                     app/views/identity/pin_resets/new.html.erb
                     app/views/identity/teacher_registrations/new.html.erb
                     app/views/identity/teacher_registrations/_form.html.erb
                     app/views/identity/pending_teacher_registrations/new.html.erb
                     app/views/identity/pending_teacher_registrations/_school_fields.html.erb
                     app/views/classroom/join_codes/new.html.erb
                     app/views/classroom/joins/new.html.erb
                     app/views/classroom/joins/_signup_form.html.erb
                     app/views/errors/forbidden.html.erb
                     app/views/errors/not_found.html.erb
                     app/views/homepage/index.html.erb
                     config/locales/identity/invitations.fr.yml
                     config/locales/identity/sessions.fr.yml
                     config/locales/identity/pin_resets.fr.yml
                     config/locales/identity/teacher_registrations.fr.yml
                     config/locales/identity/pending_teacher_registrations.fr.yml
                     config/locales/classroom/joins.fr.yml
                     config/locales/errors/pages.fr.yml
                     config/locales/homepage/index.fr.yml
                     test/system/identity/teacher_signup_test.rb
                     test/system/classroom/join_test.rb
- **Dépend de**    : Lot 0
- **Test associé** : test/controllers/identity/invitations_controller_test.rb · test/controllers/identity/sessions_controller_test.rb · test/system/identity/team_invitation_test.rb · test/system/finitions/public_pages_test.rb — FU-03, FU-13, FU-17, FU-19, FU-30, FU-31, FU-32, FU-33, FU-44, FU-53 (acceptation)
- **Done quand**   : une personne invitée arrive sur « Se connecter » avec son numéro pré-rempli et le focus sur le PIN, sans session ouverte ni numéro dans l'URL ou le flash ; le logo de chaque page publique mène à l'accueil public ; `/join` s'ouvre au 5ᵉ caractère valide ; une erreur d'inscription met le focus sur le champ fautif

---

## Lot B — Second facteur et codes de secours

- **Couche**       : delivery + ui
- **Fichiers**     : app/controllers/identity/second_factors_controller.rb *(paramètre `backup`, conservé au 422)*
                     app/views/identity/second_factors/new.html.erb
                     app/views/identity/second_factor_enrollments/new.html.erb
                     app/views/identity/second_factor_enrollments/backup_codes.html.erb
                     config/locales/identity/second_factors.fr.yml
                     test/controllers/identity/second_factor_enrollments_controller_test.rb
                     test/system/identity/sign_in_test.rb
- **Dépend de**    : Lot 0
- **Test associé** : test/controllers/identity/second_factors_controller_test.rb · test/system/finitions/second_factor_test.rb — FU-12, FU-34, FU-35, FU-36, FU-37, FU-38, FU-39, FU-40, FU-41, FU-42, FU-43, FU-53 (codes de secours, vérification)
- **Done quand**   : un membre de l'équipe tape 6 chiffres et arrive sur son accueil sans cliquer, une seule tentative étant journalisée ; il bascule sur le code de secours sans envoi automatique ; il télécharge, copie et imprime ses codes et ne continue qu'après « Je les ai gardés » ; l'activation a « Se déconnecter »

> **Part de la base qui contient déjà `SecretResponse`** (`secrets-hors-cache`, fusionné) : `second_factor_enrollments_controller.rb` déclare `secret_response :new, :create` et son flux ajoute `turbo_stream_secret_response`. Le lot le **réutilise tel quel** : il ne recrée ni ne déplace rien, ne modifie pas ce contrôleur, et ne pose lui-même aucun en-tête. La page des codes de secours reste hors cache ; le texte du fichier téléchargé (valeur `content` du contrôleur `download`) n'ajoute aucun secret qui n'y soit déjà. La vérification (`second_factors_controller.rb`) n'affiche aucun secret et n'a pas à être marquée.

---

## Lot C1 — Équipe : référentiel

- **Couche**       : ui
- **Fichiers**     : app/views/teams/levels/index.html.erb
                     app/views/teams/levels/new.html.erb
                     app/views/teams/levels/edit.html.erb
                     app/views/teams/levels/_form.html.erb
                     app/views/teams/levels/_level_row.html.erb
                     app/views/teams/series/index.html.erb
                     app/views/teams/series/new.html.erb
                     app/views/teams/series/edit.html.erb
                     app/views/teams/series/_form.html.erb
                     app/views/teams/materials/index.html.erb
                     app/views/teams/materials/new.html.erb
                     app/views/teams/materials/edit.html.erb
                     app/views/teams/materials/_form.html.erb
                     app/views/teams/drenas/index.html.erb
                     app/views/teams/drenas/new.html.erb
                     app/views/teams/drenas/edit.html.erb
                     app/views/teams/drenas/_form.html.erb
                     app/views/teams/classroom_plans/show.html.erb
                     app/views/teams/classroom_plans/edit.html.erb
                     config/locales/teams/levels.fr.yml
                     config/locales/teams/series.fr.yml
                     config/locales/teams/materials.fr.yml
                     config/locales/teams/drenas.fr.yml
                     config/locales/teams/classroom_plans.fr.yml
                     test/system/teams/levels_test.rb
                     test/system/teams/series_test.rb
                     test/system/teams/materials_test.rb
                     test/system/teams/drenas_test.rb
                     test/system/teams/classroom_plan_test.rb
- **Dépend de**    : Lot 0
- **Test associé** : test/system/finitions/team_referential_test.rb — FU-04, FU-05 (niveau, DRENA), FU-10 (Niveaux, Séries, Matières, DRENA, Barème), FU-15, FU-16, FU-18, FU-22
- **Done quand**   : sur Niveaux, Séries, Matières, DRENA et Barème, un retour « Accueil » précède le titre ; chaque modale vise son premier champ et change le titre de l'onglet ; une confirmation vise « Annuler » ; le badge « hors génération » a une infobulle et plus de `title`

---

## Lot C2 — Équipe : contenu et imports

- **Couche**       : ui
- **Fichiers**     : app/views/teams/courses/new.html.erb
                     app/views/teams/courses/edit.html.erb
                     app/views/teams/courses/_form.html.erb
                     app/views/teams/essentials/new.html.erb
                     app/views/teams/essentials/edit.html.erb
                     app/views/teams/essentials/_form.html.erb
                     app/views/teams/exercises/new.html.erb
                     app/views/teams/exercises/edit.html.erb
                     app/views/teams/exercises/_form.html.erb
                     app/views/teams/imports/index.html.erb
                     app/views/teams/imports/new.html.erb
                     app/views/teams/imports/show.html.erb
                     config/locales/teams/courses.fr.yml
                     config/locales/teams/essentials.fr.yml
                     config/locales/teams/exercises.fr.yml
                     config/locales/teams/imports.fr.yml
                     test/system/teams/course_management_test.rb
                     test/system/teams/essential_management_test.rb
                     test/system/teams/exercise_form_test.rb
                     test/system/teams/import_flow_test.rb
- **Dépend de**    : Lot 0
- **Test associé** : test/system/finitions/team_content_test.rb — FU-05 (cours), FU-10 (Rapport d'import), FU-11 (imports)
- **Done quand**   : les modales cours, fiche, exercice et import visent leur premier champ et ont un titre ; le rapport d'import a le lien « Imports » au lieu du bouton ; le titre « Importer : … » n'a plus de deux-points

---

## Lot D1 — Équipe : établissements

- **Couche**       : ui (+ mesure du PRD §7)
- **Fichiers**     : app/views/teams/schools/index.html.erb
                     app/views/teams/schools/show.html.erb
                     app/views/teams/schools/edit.html.erb
                     app/views/teams/schools/_filters.html.erb
                     app/views/teams/schools/_header.html.erb
                     app/views/teams/schools/_school_row.html.erb
                     app/views/teams/schools/_form.html.erb
                     app/views/teams/school_classrooms/new.html.erb
                     app/views/teams/school_classrooms/_form.html.erb
                     app/views/teams/staff_invitations/new.html.erb
                     app/views/teams/staff_invitations/_created.html.erb
                     app/views/teams/staff_invitations/created.html.erb
                     config/locales/teams/schools.fr.yml
                     config/locales/teams/school_classrooms.fr.yml
                     config/locales/teams/staff_invitations.fr.yml
                     test/controllers/teams/staff_invitations_controller_test.rb
                     test/system/teams/schools_test.rb
                     test/system/teams/school_code_test.rb
                     test/system/teams/staff_invitation_test.rb
                     test/system/teams/school_classroom_creation_test.rb
- **Dépend de**    : Lot 0
- **Test associé** : test/system/finitions/schools_search_test.rb · test/controllers/teams/schools_controller_test.rb — FU-01, FU-09, FU-25, FU-26 (fiche), FU-45, FU-46 ; mesure du PRD §7
- **Done quand**   : la liste des établissements se filtre pendant la frappe et au changement des listes, l'URL remplacée, le nombre annoncé ; « Établissements » ramène à la liste filtrée ; le lien d'invitation de la direction se copie ; la mesure du PRD §7 est écrite dans `journal.md` (au-delà de 150 ms, le lot s'arrête et remonte)

---

## Lot D2 — Équipe : accueil, comptes, pilotage, croissance, invitation équipe

- **Couche**       : ui
- **Fichiers**     : app/views/teams/homes/show.html.erb
                     app/views/teams/account_lookups/show.html.erb
                     app/views/teams/dashboards/show.html.erb
                     app/views/teams/dashboards/_filters.html.erb
                     app/views/teams/dashboards/_key_figures.html.erb
                     app/views/teams/dashboards/_drenas.html.erb
                     app/views/teams/growth/show.html.erb
                     app/views/teams/invitations/new.html.erb
                     app/views/teams/invitations/_created.html.erb
                     app/views/teams/invitations/created.html.erb
                     config/locales/teams/homes.fr.yml
                     config/locales/teams/account_lookups.fr.yml
                     config/locales/teams/dashboards.fr.yml
                     config/locales/teams/growth.fr.yml
                     config/locales/teams/invitations.fr.yml
                     test/controllers/teams/account_lookups_controller_test.rb
                     test/controllers/teams/invitations_controller_test.rb
                     test/system/teams/account_unlock_test.rb
                     test/system/teams/dashboard_test.rb
                     test/system/teams/growth_test.rb
                     test/system/teams/team_home_test.rb
- **Dépend de**    : Lot 0
- **Test associé** : test/system/finitions/team_accounts_test.rb — FU-02 (équipe), FU-10 (Croissance, Débloquer un compte), FU-21 (pilotage), FU-23, FU-24, FU-50, FU-52
- **Done quand**   : « Débloquer un compte » cherche seul dès le numéro complet et jamais avant ; la DRENA du pilotage part au changement ; les indicateurs du pilotage et de Croissance ont leurs infobulles ; le lien d'invitation de l'équipe se copie ; l'accueil s'appelle « Accueil · Équipe · Lnclass »


> « Débloquer un compte » **tel qu'il existe** (`/teams/accounts`, `teams/account_lookups/show`, UDR-0020) : pas de page « Comptes », pas d'annuaire. Seuls la recherche en mode `digits`, le retour, le titre et le focus changent ; la carte `_result` n'est pas touchée.
---

## Lot E — Enseignant : classe, cours dans la classe, parrainage

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : app/infrastructure/queries/classroom/classroom_header_query.rb *(`school_public_id`)*
                     app/infrastructure/queries/classroom/classroom_overview_query.rb *(`search:` sur les élèves)*
                     app/controllers/classroom/classrooms_controller.rb *(lecture de `q`)*
                     app/views/classroom/classrooms/show.html.erb
                     app/views/classroom/classrooms/_header.html.erb
                     app/views/classroom/classrooms/_roster.html.erb
                     app/views/classroom/classroom_courses/show.html.erb
                     app/views/classroom/classroom_essentials/show.html.erb
                     app/views/classroom/course_assignments/index.html.erb
                     app/views/classroom/teacher_homes/show.html.erb
                     app/views/classroom/teaching_selections/index.html.erb
                     app/views/identity/referrals/show.html.erb
                     app/views/identity/referrals/_invite.html.erb
                     app/javascript/controllers/identity/share_controller.js *(copie retirée, `recordCopy` sur `clipboard:copied`)*
                     config/locales/classroom/classrooms.fr.yml
                     config/locales/classroom/classroom_courses.fr.yml
                     config/locales/classroom/classroom_essentials.fr.yml
                     config/locales/classroom/course_assignments.fr.yml
                     config/locales/classroom/teacher_homes.fr.yml
                     config/locales/classroom/teaching_selections.fr.yml
                     config/locales/identity/referrals.fr.yml
                     test/infrastructure/queries/classroom/classroom_header_query_test.rb
                     test/system/classroom/classroom_page_test.rb
                     test/system/classroom/teacher_home_test.rb
                     test/system/classroom/teaching_selection_test.rb
                     test/system/classroom/course_assignments_test.rb
                     test/system/classroom/classroom_essential_test.rb
                     test/system/identity/invite_colleague_test.rb
- **Dépend de**    : Lot 0
- **Test associé** : test/infrastructure/queries/classroom/classroom_overview_query_test.rb · test/controllers/classroom/classrooms_controller_test.rb · test/system/finitions/classroom_test.rb — FU-02 (enseignant), FU-07, FU-08, FU-10 (Inviter un collègue), FU-26 (classe), FU-28, FU-48, FU-53 (classe)
- **Done quand**   : l'enseignant copie le code et le lien de sa classe, retrouve un élève en tapant son nom, revient par « Accueil » ; l'équipe revient de la classe à la fiche de l'établissement ; la copie du lien de parrainage est toujours comptée

---

## Lot F — Catalogue, exercice, élève

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : app/infrastructure/queries/catalog/course_catalog_query.rb *(`search:`)*
                     app/controllers/catalog/courses_controller.rb *(lecture de `q`)*
                     app/views/catalog/courses/index.html.erb
                     app/views/catalog/courses/show.html.erb
                     app/views/catalog/essentials/show.html.erb
                     app/views/assessment/exercises/show.html.erb
                     app/views/assessment/exercises/_student_progress.html.erb
                     app/views/assessment/exercise_sessions/show.html.erb
                     app/views/assessment/session_results/show.html.erb
                     app/views/assessment/session_results/_badge.html.erb
                     app/views/classroom/student_homes/show.html.erb
                     app/views/classroom/student_classrooms/show.html.erb
                     config/locales/catalog/courses.fr.yml
                     config/locales/catalog/essentials.fr.yml
                     config/locales/assessment/exercises.fr.yml
                     config/locales/assessment/exercise_sessions.fr.yml
                     config/locales/assessment/session_results.fr.yml
                     config/locales/assessment/badges.fr.yml
                     config/locales/classroom/student_homes.fr.yml
                     config/locales/classroom/student_classrooms.fr.yml
                     test/controllers/catalog/courses_controller_test.rb
                     test/system/catalog/course_catalog_test.rb
                     test/system/catalog/essential_page_test.rb
                     test/system/classroom/student_home_test.rb
                     test/system/classroom/student_classroom_test.rb
- **Dépend de**    : Lot 0
- **Test associé** : test/infrastructure/queries/catalog/course_catalog_query_test.rb · test/system/finitions/catalog_and_student_test.rb — FU-02 (élève), FU-14, FU-27 (élève), FU-47, FU-53 (catalogue)
- **Done quand**   : le catalogue se filtre par nom pendant la frappe (sans accents) et au changement des listes ; la page cours n'a plus de fil complet ; les badges et la maîtrise ont leur infobulle ; « Ma classe » n'a toujours pas de « Copier »

---

## Lot G — Direction

- **Couche**       : infrastructure + delivery + ui *(pages de l'espace direction simple, UDR-0052 / ADR-0065, en production)*
- **Fichiers**     : app/infrastructure/queries/school/student_work_query.rb *(`search:` sur les élèves d'une classe)*
                     app/controllers/school_admin/classrooms_controller.rb *(lecture de `q`)*
                     app/views/school_admin/classrooms/index.html.erb
                     app/views/school_admin/classrooms/show.html.erb
                     app/views/school_admin/teachers/index.html.erb
                     config/locales/school_admin/classrooms.fr.yml
                     config/locales/school_admin/teachers.fr.yml
                     test/controllers/school_admin/classrooms_controller_test.rb
                     test/system/school_admin/student_work_test.rb
- **Dépend de**    : Lot 0
- **Test associé** : test/infrastructure/queries/school/student_work_query_test.rb · test/system/finitions/school_admin_test.rb — FU-10 (Classe, direction), FU-11 (direction), FU-21, FU-49
- **Done quand**   : la direction lit la définition de « Taux de rendu », « Moyenne » et « — » d'un toucher, cherche un élève dans une classe de son établissement, revient par le lien « Travail des élèves »

---

## Lot H — Profil et pages de compte

- **Couche**       : ui
- **Fichiers**     : app/views/identity/profiles/show.html.erb
                     app/views/identity/profile_names/edit.html.erb
                     app/views/identity/profile_contacts/edit.html.erb
                     app/views/identity/profile_pins/edit.html.erb
                     app/views/identity/profile_photos/edit.html.erb
                     app/views/identity/pending_accounts/show.html.erb
                     app/views/identity/pin_recovery_codes/show.html.erb
                     app/views/identity/pin_recovery_codes/_code.html.erb
                     config/locales/identity/profiles.fr.yml
                     config/locales/identity/profile_contacts.fr.yml
                     config/locales/identity/profile_pins.fr.yml
                     config/locales/identity/profile_photos.fr.yml
                     config/locales/identity/pending_accounts.fr.yml
                     config/locales/identity/pin_recovery_codes.fr.yml
                     test/system/identity/profile_test.rb
                     test/system/identity/profile_contact_test.rb
                     test/system/identity/profile_pin_test.rb
                     test/system/identity/profile_photo_test.rb
- **Dépend de**    : Lot 0
- **Test associé** : test/system/finitions/account_pages_test.rb — FU-05 (profil), FU-10 (Mon profil), FU-27 (code de récupération)
- **Done quand**   : le profil a son retour « Accueil » ; les quatre modales du profil visent leur premier champ (sans attribut `autofocus`) et ont un titre ; la modale du code de récupération n'a toujours pas de « Copier »

---

## Lot Z — Clôture

- **Couche**       : ui + gardes
- **Fichiers**     : app/views/layouts/application.html.erb *(retrait du repli `content_for :title`)*
                     app/javascript/controllers/classroom/join_code_copy_controller.js *(supprimé)*
                     test/views/Lnclass » dans une locale)*
                     docs/chantiers/finitions-ux/journal.md
- **Dépend de**    : Lots A, B, C1, C2, D1, D2, E, F, G, H
- **Test associé** : test/views/page_titles_test.rb · test/system/finitions/narrow_screens_test.rb — FU-06, FU-11, FU-20, FU-53, FU-54
- **Done quand**   : `bin/ci` passe en entier une fois ; plus aucune vue ne pose `content_for :title` ni `autofocus` ; `classroom--join-code-copy` n'existe plus et le budget JS est mesuré dans `journal.md`

---

## Rattachement des critères

| Critère | Lot(s) | Critère | Lot(s) | Critère | Lot(s) |
|---|---|---|---|---|---|
| FU-01 | D1 | FU-19 | A | FU-37 | B |
| FU-02 | D2, E, F | FU-20 | Z | FU-38 | B |
| FU-03 | A | FU-21 | G, D2 | FU-39 | 0, B |
| FU-04 | C1 | FU-22 | C1 | FU-40 | B |
| FU-05 | C1, C2, H | FU-23 | 0, D2 | FU-41 | B |
| FU-06 | Z | FU-24 | D2 | FU-42 | B |
| FU-07 | E | FU-25 | D1 | FU-43 | B |
| FU-08 | E | FU-26 | E, D1 | FU-44 | A |
| FU-09 | D1 | FU-27 | F, H | FU-45 | D1 |
| FU-10 | C1, C2, D2, E, G, H | FU-28 | E | FU-46 | D1 |
| FU-11 | C2, G, Z | FU-29 | 0 | FU-47 | F |
| FU-12 | B | FU-30 | A | FU-48 | E |
| FU-13 | A | FU-31 | A | FU-49 | G |
| FU-14 | F | FU-32 | A | FU-50 | D2 |
| FU-15 | C1 | FU-33 | A | FU-51 | 0 |
| FU-16 | C1 | FU-34 | B | FU-52 | D2 |
| FU-17 | A | FU-35 | B | FU-53 | A, B, E, F, Z |
| FU-18 | C1 | FU-36 | B | FU-54 | Z |

Aucun critère orphelin : les 54 sont rattachés.

---

## Vérification de collision

> Construite en listant tous les fichiers de tous les lots, puis `awk … | sort | uniq -d` (commande de la skill `plan-lots`, sortie reproduite ci-dessous). Les seuls fichiers listés deux fois sont **séquentiels**, jamais dans deux lots parallèles.

Sortie de la commande le 2026-09-29 : `app/views/layouts/application.html.erb` seul (Lot 0 puis Lot Z, séquentiels). Un contrôle par lot (un fichier compté une fois par lot) donne le même résultat.

| Fichier | Lot propriétaire | Remarque |
|---|---|---|
| `app/views/layouts/application.html.erb` | Lot 0, puis Lot Z | Séquentiel : Z retire le repli après la fusion de tous les lots ; `secret_response_meta_tag` n'est jamais touché |
| `app/helpers/components_helper.rb`, `app/helpers/page_title_helper.rb`, `app/helpers/navigation_helper.rb` | Lot 0 | API gelées ; aucun lot vertical ne les modifie |
| `app/views/components/*` | Lot 0 | Idem |
| `app/javascript/controllers/*_controller.js` (racine) et `modal_controller.js` | Lot 0 | Idem |
| `app/javascript/controllers/identity/share_controller.js` | Lot E | Seul lot qui touche au partage |
| `app/javascript/controllers/classroom/join_code_copy_controller.js` | Lot Z | Supprimé quand E (classe) et D1 (fiche établissement) ne l'appellent plus |
| `app/assets/stylesheets/application.tailwind.css` | Lot 0 | |
| `config/locales/shared/*.fr.yml` | Lot 0 | Les textes d'infobulle propres à un écran vont dans la locale de l'écran, jamais dans `shared` après le Lot 0 |
| `config/locales/identity/second_factors.fr.yml` | Lot B | Contient la vérification **et** l'activation |
| `config/locales/identity/profiles.fr.yml` | Lot H | Contient aussi la modale du nom |
| `config/locales/classroom/joins.fr.yml` | Lot A | `/join` et `/c/<code>` |
| `app/views/classroom/student_homes/*`, `student_classrooms/*` | Lot F | Le Lot E ne touche que la classe vue par l'enseignant et l'équipe |
| `app/infrastructure/queries/classroom/classroom_header_query.rb` | Lot E | Lu aussi par « Ma classe » (F), qui ne le modifie pas (ajout d'un champ seulement) |
| `app/infrastructure/queries/shared/text_search.rb` | Lot 0 | Utilisé par E, F, G sans modification |
| `test/system/identity/sign_in_test.rb` | Lot B | Le Lot A écrit ses cas de connexion dans `test/system/finitions/public_pages_test.rb` |
| `test/system/design_system_test.rb` | Lot 0 | |
| `config/routes/*.rb` | aucun | Aucune route nouvelle (paramètres `q`, `backup`, `search` seulement) |
| `db/*` | aucun | Aucune migration, aucun index |
| `test/fixtures/*` | aucun | Les tests créent leurs données par les usines existantes ; un lot qui aurait besoin d'une fixture partagée s'arrête et remonte au Lot 0 |

## Base de départ et chantiers voisins

Mise à jour du 2026-09-29 : `Develop` contient la V2 **espace direction simple** (#86) et le correctif **`secrets-hors-cache`** (#91). Le chantier `espace-direction` complet et `annuaire-equipe` sont au backlog : **aucun lot n'en dépend**. Les fichiers de la base que des lots touchent sont listés ici avec leur unique propriétaire, pour qu'aucun lot ne défasse ce qui vient d'être fusionné.

| Fichier fusionné (origine) | Lot propriétaire | Ce que le lot garde intact |
|---|---|---|
| `app/views/layouts/application.html.erb` (`secrets-hors-cache`) | Lot 0, puis Lot Z | La ligne `secret_response_meta_tag` du `<head>` |
| `app/controllers/concerns/secret_response.rb`, `app/helpers/secret_response_helper.rb`, `app/controllers/application_controller.rb` (`secrets-hors-cache`) | aucun | Réutilisés, jamais modifiés |
| `app/controllers/identity/second_factor_enrollments_controller.rb` (`secrets-hors-cache`) | aucun | `secret_response :new, :create` et le flux `turbo_stream_secret_response` |
| `app/views/identity/second_factor_enrollments/new.html.erb`, `backup_codes.html.erb` | Lot B | Rendus sous `secret_response` : rien à ajouter |
| `app/views/teams/invitations/create.turbo_stream.erb`, `app/views/teams/staff_invitations/create.turbo_stream.erb`, `app/views/identity/pin_recovery_codes/create.turbo_stream.erb` (`secrets-hors-cache`) | aucun | Les lots D2, D1 et H ne touchent que les partials `_created` / `_code` et les pages de repli |
| `app/views/teams/invitations/_created.html.erb`, `created.html.erb` | Lot D2 | Le lien reste rendu par le serveur ; « Copier » lit la même valeur |
| `app/views/teams/staff_invitations/new.html.erb`, `_created.html.erb`, `created.html.erb` (V2 simple) | Lot D1 | Idem |
| `app/views/identity/invitations/show.html.erb`, `app/controllers/identity/invitations_controller.rb` (V2 simple : variante direction) | Lot A | L'encadré et le toast propres à la direction ; `AcceptInvitation` n'est pas modifié |
| `app/views/school_admin/classrooms/index.html.erb`, `show.html.erb`, `app/views/school_admin/teachers/index.html.erb`, `app/controllers/school_admin/classrooms_controller.rb`, `app/infrastructure/queries/school/student_work_query.rb` (V2 simple) | Lot G | Lecture seule, aucun identifiant d'élève dans le HTML, « — » sous 5 élèves (ADR-0065) |
| `app/views/identity/pin_recovery_codes/_code.html.erb`, `show.html.erb` | Lot H | Toujours sans « Copier » |

## Dispatch

```
Vague 1 : Lot 0                                            → 1 agent, séquentiel
Vague 2 : A ‖ B ‖ C1 ‖ C2 ‖ D1 ‖ D2 ‖ E ‖ F ‖ G ‖ H         → 10 agents, worktrees isolés
Vague 3 : Lot Z                                            → 1 agent, séquentiel
```

Chaque lot parallèle travaille dans son worktree, créé **depuis la branche de chantier une fois le Lot 0 fusionné** :

```bash
git worktree add ../lnclass-finitions-ux-lot-a -b feature/finitions-ux-lot-a feature/finitions-ux
```

Brief de chaque agent : chemin absolu de son worktree ; son lot recopié en entier (quatre champs) ; liens vers `prd.md` et l'UDR-0054 (§3 = contrat ; §3.4 = textes d'infobulle à reprendre tels quels) ; l'ordre intra-lot (test rouge → domaine → infrastructure → delivery → UI) ; chemins absolus et `git -C` ; **interdiction de toucher un fichier hors de son champ `Fichiers`** (besoin d'une brique modifiée → arrêt, le Lot 0 rouvre).

## Règles de vérification des lots

1. **Pendant le travail, un lot ne lance que ses propres tests** : les fichiers de son champ `Test associé` et les tests existants de son champ `Fichiers` (`bin/rails test <fichiers>`, système compris), plus `bin/rubocop` sur ses fichiers et la garde HITL. Jamais la suite entière.
2. **La passe complète (`bin/ci`) a lieu une seule fois**, au Lot Z, sur la branche de chantier où tous les lots sont fusionnés. Un lot vertical ne la lance pas avant sa fusion.
3. **Au plus trois vérifications complètes en même temps**, tous worktrees et agents confondus (une passe `bin/ci` ou une suite système entière compte pour une). Un agent qui en aurait besoin au-delà attend qu'une se termine.
4. Un test rouge hors du périmètre du lot n'est pas corrigé par ce lot : il est signalé et le Lot Z le traite (ou le lot propriétaire, s'il n'est pas encore fusionné).
5. La mesure du PRD §7 (Lot D1) et le budget JS (Lot Z) sont notés dans `journal.md`, chiffres à l'appui.

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md`
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

Portes propres à ce chantier :

- [ ] Les textes d'infobulle (UDR-0054 §3.4) sont listés dans la PR et validés par le porteur
- [ ] `SecretResponse` intact au Lot Z : `secret_response_meta_tag` dans le layout, `secret_response :new, :create` sur l'activation, flux des invitations et du code de récupération inchangés
- [ ] Numéro UDR-0054 revérifié contre `Develop` avant la PR (le 2026-09-29 : UDR-0053 est pris par l'import des DRENA, 0054 est libre). Aucun ADR dans ce chantier

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Pour ce chantier : il refait au téléphone (390 px) le parcours de l'invitation d'équipe, de « Se connecter » pré-rempli jusqu'à l'accueil, en vérifiant que le numéro n'apparaît ni dans l'URL ni dans le journal de la requête (FU-31, FU-34, FU-40), tape un code faux au second facteur puis Entrée en même temps (FU-35, FU-36), copie un lien d'invitation, cherche un établissement et revient à la liste filtrée (FU-09, FU-45), et navigue au clavier seul dans une modale et une confirmation (FU-15, FU-18). Il vérifie aussi un parcours **sans JavaScript** (FU-37, FU-46).
