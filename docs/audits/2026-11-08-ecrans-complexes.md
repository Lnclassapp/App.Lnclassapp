# Audit 3/3 — Écrans compliqués et surchargés d'informations

> Date : 2026-11-08 · Lecture seule (aucune modification de `app/`, `config/`, `db/`, tests ; rien en production).
> Périmètre : toutes les vues de `app/views` (≈ 500 fichiers ERB), par rôle : élève, enseignant, école/direction, équipe, écrans transverses/publics.
> **Pas de rôle parent** : `User::ROLES = student, teacher, school_admin, team`. Aucune vue, route ni table « parent/tuteur ».

## Méthode et limites

- 7 sous-agents (un par rôle ou ensemble d'écrans). Mesures par `grep`/`wc` sur la vue et ses partials, puis lecture ciblée des écrans lourds. Les nombres d'actions et de chiffres sont des **estimations à ±20 %**, pas des comptages de DOM (sauf captures, section finale).
- Charge : 1 simple · 2 correct · 3 dense · 4 chargé · 5 surchargé. Critères : blocs, actions visibles, chiffres affichés, champs, clics pour la tâche principale, écrans multi-tâches.
- Limite assumée : « 600 lignes de code au plus par agent » n'a pas pu tenir pour la lecture exhaustive (≈ 12 000 lignes de vues) ; les agents ont mesuré en masse et lu en détail seulement les écrans lourds.
- Constat de départ : **le badge existe déjà** (Bronze / Argent / Or / Diamant : `Assessment::BadgesHelper`, `Grading.badge_for`, `BADGE_PILL`, `comprehension_trophy`, UDR-0131, ADR-0106). Le problème n'est pas d'introduire la médaille mais de **retirer les chiffres qui la doublent** (note /20, %, moyenne, points, x/y).

## Synthèse

| Rôle | Écrans notés | Charge 5 | Charge 4 | Charge 3 | Notes/%/moyennes à remplacer |
|---|---|---|---|---|---|
| Élève | 29 | 1 | 1 | ≈ 9 | oui (accueil, archive, aperçu, résultat, leçon) |
| Enseignant | 29 | 1 | 4 | 5 | oui (8 endroits) |
| École / direction | 21 | 0 | 3 | 3 | oui (moyenne %, taux de rendu, seuil /20) |
| Équipe | 40 | 2 | 2 | ≈ 9 | partiel (Pilotage, Croissance, points du corrigé) |
| Transverse / public | ≈ 30 | 0 | 2 | 5 | non (aucune note) |

Navigation saine : 3 destinations (élève, enseignant) ou 4 (direction, équipe) ; seule l'équipe a un niveau de plus (« Plus », 3 entrées). Ce n'est pas le problème.

## Tableau de tous les écrans (note de charge 1-5)

Colonnes : blocs/cartes · actions visibles · chiffres affichés · champs · clics pour la tâche principale · **Charge**.

### Élève

| Écran | Rôle | Route | Vue | Blocs | Actions | Chiffres | Champs | Clics | Charge |
|---|---|---|---|---|---|---|---|---|---|
| Accueil élève | élève | GET /students | classroom/student_homes/show (+ _next_step, _subjects, _history, _band, next_step/*) | 5 (étape suivante, matières, annonces, historique, bandeau install) | ~10 (Commencer, « N autres en retard », lien classe, 7-10 matières, Inviter prof, Refaire x3, « Voir plus ») | note /20 par session (x3), échéance, x/y progression, badge « retard » | 0 | 1 (Commencer) | 3 |
| Menu du compte | élève | GET /students/menu | classroom/student_menus/show (+ avatar_menu) | 1 | ~5 liens (profil, aide, thème, déconnexion) | 0 | 0 | 2 | 1 |
| Ma classe | élève | GET /students/classroom | student_classrooms/show (+ _classroom_card, _courses, _course_card, _assigned_sheets, _pending_gaps, _treated_exercise, _no_teacher) | 6 (en-tête classe, cours, devoirs, fiches à revoir, traités, éventuel « sans prof ») | ~8 (cartes cours carrousel, cartes devoirs, fiches à revoir, « voir plus » x2) | « N cours », « N exercices » par cours, x/y par devoir, échéance | 0 | 2 | 3 (frôle 4) |
| Inscription élève | élève (public) | GET/POST /student-signup | student_registrations/new, _form, _class_picker, _step_alerts | 2 + étapes | ~8 | 0 | ~9 (code 6 car., DRENA, établissement, niveau, classe, nom, prénom, genre, contact, PIN, confirmation PIN) | 4-6 (assistant en étapes) | 3 |
| Choix de classe | élève sans classe | GET/POST /students/classroom/new | student_classroom_choices/new | 1 | ~4 | 0 | 4 sélecteurs en cascade | 5 | 2 |
| Changement de classe | élève | GET /students/classroom/change, /confirm, POST | student_classroom_changes/new, confirm | 3 | ~6 | 0 | 4 sélecteurs + confirmation | 6 | 2 |
| Rejoindre par lien | élève | GET/POST /c/:code | joins/new, _classroom_preview | 2-3 | 3 | 0 | 0-1 | 1 | 1 |
| Vérif. code classe | élève | GET /classroom-codes/:code | classroom_codes (frame) | 1 | 1 | 0 | 0 | 1 | 1 |
| Archive de l'élève | élève | GET /students/archive | student_archives/show, _month, _result_row | 3 (résumé, résultats par mois, classes) | « voir plus » x2 | compteur d'exercices terminés (gros), note /20 sur chaque ligne, dates | 0 | 1 | 3 |
| Devoir assigné (lecture) | élève | GET /students/classroom/devoirs/:sheet | student_assigned_sheets/show + catalog/courses/sheets/_paper, _sheet | 1 feuille de N exercices | ~3 | x/y réussis | 0 | 3 | 2 |
| Devoir assigné (remplir) | élève | …/:sheet/remplir | student_assigned_sheets/fill + sheets/_exercise, _question, _choice | N exercices | ~4 | x/y, points | N champs | 4 | 3 |
| Liste des cours | élève | GET /courses | catalog/courses/index (264 l.), _page, _course_card, _course_group_title | 1 (recherche) + 1 carte par leçon, dépliables | 17 (recherche, filtre, 1 carte = 1 lien + « Voir les N fiches » + « Plus ») | « N leçons », badge « commencé », coche « fait » | 1 (recherche) | 2 (matière → leçon) | 2 |
| Page d'un cours (leçon) | élève | GET /courses/:slug | catalog/courses/show, _next_exercise, _revision_sheet + revision_sheets/_sheet, _prepare_sheets + sheets/_card | 5 (en-tête, prochain exercice, fiche de révision par notion avec 4-5 encadrés chacune, interros, devoirs) | ~6 + 1 « Je m'entraîne » par notion | x/y réussis par feuille, numéros de notions | 0 + formulaires Je m'entraîne | 3 | 4 |
| Feuille de la leçon (lecture) | élève | GET /courses/:c/feuilles/:sheet | catalog/prepare_sheets/show, _sheet | 1 | ~3 | x/y | 0 | 3 | 2 |
| Feuille de la leçon (remplir) | élève | …/remplir | prepare_sheets/fill + courses/sheets/_paper (121 l.), _exercise (95 l.), _question (73 l.) | N exercices | ~4 | x/y, points | N champs | 4 | 3 |
| Notion (essential) | élève | GET /courses/:c/essentials/:slug | aucune vue : redirection 301 vers la leçon | 0 | 0 | 0 | 0 | 0 | 1 |
| Fiche (ancienne adresse) | élève | GET /courses/:c/fiche | redirection 301 | 0 | 0 | 0 | 0 | 0 | 1 |
| Je m'entraîne (practice check) | élève | POST /courses/:c/notions/:s/practice_check | catalog/practice_checks/show, _question, _result | 1 par notion (dans la fiche) | 2 (Vérifier, Correction) | verdict par question | 1 par question (~11) | 2 | 2 |
| Exercice (aperçu) | élève | GET /exercises/:id | assessment/exercises/show (153 l.), _card, _solution, sheet_kinds/* | 4 (en-tête, énoncé, questions, pied d'actions) | 3 (Commencer ou Reprendre, Recommencer) | « N questions », barème en points, meilleure note /20 | 0 (lecture) | 2 | 3 |
| Copie en cours | élève | GET /sessions/:id | assessment/exercise_sessions/show (148 l.), kinds/* | 1 énoncé repliable + 1 carte par question | 17 (Rendre, indice, Revoir l'énoncé…) | compteur « x/N répondues », points par question | 34 (1 à n par question) | 1 + N réponses | 3 (inhérent à la tâche) |
| Envoi de la copie | élève | POST /sessions/:id/copy | exercise_copies (redirection vers résultat) | 0 | 0 | 0 | 0 | 1 | 1 |
| Vérifier ma réponse (feuille) | élève | POST /exercises/:id/sheet_check | sheet_checks (Turbo Stream) | 0-1 | 1 | verdict | 0 | 1 | 1 |
| Indice | élève | POST /exercise_sessions/:id/hints | assessment/hints/_hint | 1 | 0 | 0 | 0 | 1 | 1 |
| Résultat de session | élève | GET /sessions/:id/result | session_results/show (181 l.), _badge, _progress, _gap_outcome, _question_review, kinds/*_review | 6 (récap, à revoir, progrès, fiche à revoir, énoncé, correction détaillée) | 5 (Refaire, Retour, Refaire sur la notion, Ouvrir la notion, ancres des questions faibles) | note /20, % (côté non-propriétaire), maîtrise, « x/N justes », points gagnés/total, phrase de progrès avec 3 notes (première, meilleure, actuelle), seuil en note | 0 | 1 | 5 |
| Image de question | élève | GET /images/questions/:id | ressource | 0 | 0 | 0 | 0 | 0 | 1 |
| Compréhension (classe) | enseignant uniquement | `assessment/comprehension/*` (partials) | _section 96 l., _badge_boxes, _badge_counts, _circle, _student_row | hors élève | hors élève | hors élève | 0 | hors élève | hors périmètre (voir audit enseignant) |
| Annonces reçues | élève | GET /announcements | communication/inboxes/show, messages/_card, _carousel | 1 liste de cartes | 1 « Rétablir » par carte écartée + pagination | 0 | 0 | 1 | 2 |
| Carrousel d'annonces (accueil) | élève | partial de l'accueil | messages/_carousel | 1 | 1 par carte (+ audio) | 0 | 0 | 0 | 1 |
| Profil élève | élève | GET /profile (+ name, contact, pin, photo) | identity/profiles/show, _student, _student_information, _student_row, profile_names/contacts/pins/photos | 2 (identité, informations) | 23 (changer photo, nom, contact, PIN, thème, déconnexion…) | 0 | 1 à 3 par modale | 2 | 2 |

### Enseignant

| Écran | Rôle | Route | Vue | Blocs | Actions | Chiffres | Champs | Clics | Charge |
|---|---|---|---|---|---|---|---|---|---|
| Accueil enseignant | ens. | `/teachers` (teacher_home) | classroom/teacher_homes/show + 7 partials (~295 l.) | 6-7 (bandeau, carrousel classes, grille niveaux, annonces, « Cette semaine », Historique, collègues en attente) | ~12 (lien par carte classe, copier code x N, 1 bulle par niveau, WhatsApp, 1 lien par ligne x N) | par carte : élèves, assignations, 1-4 pastilles de badge, code ; par ligne : x/y faits, retard, **moyenne /20** (historique) | 0 | 1 (carte classe) ; 2 pour assigner | **4** |
| Menu enseignant | ens. | `/teachers/menu` | classroom/teacher_menus/show + shared account_panel | 1 | ~8 (panneau compte) | 0 | 0 | 1 | 1 |
| Page d'une classe | ens. | `/classrooms/:id` | classrooms/show + header, session_days, link, assigned_exercises, gaps, roster (~290 l.) | 6 (en-tête, jours de séance, lien d'inscription, exercices assignés, fiches à revoir, élèves) | ~20 (menu lien, WhatsApp, copier, modifier jours, N cartes exercice, N lignes élève, recherche, 5 puces badge, « Voir les suivants ») | par élève : « 9 faits sur 18 », **« Moyenne 15/20 · Or »**, « Fait seul (7 j) », **dernier score %**, lien résultat ; badges de filtre x5 ; compteur | 1 (recherche) | 2 pour voir un élève | **5** |
| Fiche élève | ens. | `/classrooms/:id/students/:sid` | classroom_students/show + identity, summary, assignments, self_practice, manage (~190 l.) | 5 | ~10 + 2 par devoir (exercice, meilleur essai) + code PIN + retirer | « x faits sur y », retard, **« Moyenne n/20 · badge »**, pastilles par palier, par devoir : **note /20**, tendance, nb de sessions ; entraînement libre : **score %** x N | 0 (1 form POST code, 1 modale retrait) | 2-3 | **4** |
| Cours de la classe | ens. | `/classrooms/:id/courses/:slug` | classroom_courses/show + _revision_sheet, _prepare_sheets, _notion_gaps | 3 (carte cours, fiche de révision, fiches à préparer) + 1 aside par notion | ~10 (assigner par notion/fiche, fiches imprimables) | nb d'élèves en lacune par notion | 0 | 2-3 | 3 |
| Fiche à préparer (impression) | ens. | `/classrooms/:id/courses/:slug/feuilles/:sheet` | classroom_prepare_sheets/show | 1 | 2 (assigner/imprimer) | 0 | 0 | 1 | 1 |
| Suivi d'un devoir | ens. | `/classrooms/:id/assignments/:aid` | assignment_follow_ups/show + assessment/comprehension/_section, _badge_boxes (~145 l.) | 5 (en-tête, copies, progression, 5 cases badge, prochaine étape, questions) | ~10 + 1 par copie + 5 cases + « voir l'exercice » | progression x/y, retard, 5 compteurs de badge, **« première / meilleure note /20 » par copie**, **taux de réussite par question (barre, x/y)** | 0 | 1 depuis la classe | **4** |
| Assigner (modale jours) | ens. | `/classrooms/:id/assignments/new` | assignments/new | 1 modale | 3 | « prochaine séance : date » | 6 cases jour | 3 (Assigner, jours, valider) | 2 |
| Bouton Assigner / Retirer | ens. | partial `assignments/_toggle` (3 variantes : normal, compact, feuille) | assignments/_toggle (69 l.) | 0 | 1-2 | 0 | 0 | 1 | 2 (logique dense, 3 variantes de rendu) |
| Création en lot d'assignations | ens. | `POST …/assignment_batches` | assignment_batches/create.turbo_stream | 0 | 0 | 0 | 0 | 0 | 1 |
| Jours de séance (modale) | ens. | `/classrooms/:id/session_days/edit` | session_days/edit | 1 modale | 2 | 0 | 6 cases jour | 3 | 1 |
| Lien d'inscription | ens. | `PATCH …/link` | classroom_links/update.turbo_stream + classrooms/_link | 1 | 4 (WhatsApp, copier, menu, changer) | 0 | 0 | 1 | 2 |
| Aperçu d'un code de classe | élève/public | `/classroom-codes/:code` | classroom_codes/show | 1 | 0 | 0 | 0 | 0 | 1 |
| Inscription élève par code/lien | élève (hors périmètre) | `/student-signup` | student_registrations/new, _form (140 l.), _class_picker (82 l.), _step_alerts | 2 | ~13 | 0 | 7 (code, classe, nom, prénom, contact, PIN, confirmation) | 5+ | 3 |
| Archive élève | élève (hors périmètre) | `/students/archive` | student_archives/show (85 l.) + _month, _result_row | 3 | ~4 | compteur d'exercices terminés, résultats par mois | 0 | 1 | 2 |
| Changer de classe | élève (hors périmètre) | `/students/classroom/change` | student_classroom_changes/new + confirm (113 l.) | 3 | ~6 | 0 | 2 | 3 | 2 |
| Choix des classes enseignées | ens. | `/teachers/classrooms` (teacher_classrooms) | teaching_selections/index + _level_group | 1 | 1 « Terminer » + une case par classe | 0 | n cases (une par classe de l'école) | n+1 | 2 |
| Teachings (cocher/décocher) | ens. | `POST|DELETE …/teaching` | teachings/_toggle, _counter, 2 streams | 0 | 1 | compteur de classes | 1 | 1 | 1 |
| Catalogue (liste des cours) | ens. | `/courses` | catalog/courses/index (264 l.) + _teacher_header, _teacher_course, _page, _essential_row (~330 l. côté ens.) | 3-4 (en-tête+recherche, puces de matière, cours avec leurs notions imbriquées) | ~10 + 1 lien par cours + 1 lien par notion (liste imbriquée) | « n cours » (total) | 1 recherche + 0-1 sélecteurs (filtres cachés pour l'ens. sauf recherche) | 2 pour ouvrir un cours | **3 (frôle 4)** |
| Fiche d'un cours | ens. | `/courses/:slug` | catalog/courses/show + _revision_sheet, _prepare_sheets | 3 | ~10 (assigner par notion/fiche à chaque classe) | 0 | 0 | 2-3 | 3 |
| Mes annonces (liste) | ens. | `/announcements/mine` | authored_messages/index + _row | 1 liste | ~3 par ligne (menu d'actions) + « Nouvelle » | statut, dates | 0 | 1 | 2 |
| Créer/modifier une annonce | ens. | `/announcements/mine` (new/edit) | authored_messages/new|edit + **_form (156 l.)** | 1 formulaire, ~7 sections (titre, texte, classes, thème, illustration, image, audio) | 3 (annuler, brouillon, publier) | 2 compteurs de caractères | **8-9** (titre, texte, case par classe, thème x5, illustration x4+N, image, audio, retirer image/audio) | 6 min. (écran + remplir + publier) | **4** |
| Modération | team / direction (pas ens.) | `/announcements/moderation` | moderations/index + _moderated_message | 1 liste + onglets | 3 | 0 | 1 (équipe) | 1 | 2 |
| Mes écoles | ens. | `/teachers/schools` | school/teacher_schools/index (91 l.) + _join_fields | 2 | ~6 (quitter, ajouter) | n/max écoles | 1-3 | 2 | 2 |
| Rejoindre une école | ens. | `/teachers/schools/join/:token` | school/teacher_school_joins/new | 1 | ~3 | 0 | 1-2 | 2 | 2 |
| Classes d'un niveau (sélecteur) | ens./élève | frame `picker_classrooms` | school/level_classrooms/index (55 l.) | 0 | 1 par classe | 0 | cases radio | 1 | 1 |
| Inscription enseignant | ens. | `/teacher-signup` | identity/teacher_registrations/new + _form (122) + _school_fields + _school_preview | 1 | ~9 | 0 | 7 (matière, nom, prénom, école/code, contact, PIN, confirmation) | 4+ | 3 |
| Profil enseignant | ens. | `/profile` | identity/profiles/show + _information (82 l.) | 2-3 | ~5 | 0 | 0 (lecture) | 1 | 2 |
| Mes matières | ens. | `/profile/materials` | identity/profile_materials/show (64) + edit | 1 | ~3 + « retirer » x N | 0 | n cases matière | 2 | 2 |
| Partials d'aide (profil élève affiché au parent/compte) | — | — | profiles/_student*, _student_row | — | — | — | — | — | hors périmètre ens. |

### École / direction

| Écran | Rôle | Route | Vue | Blocs | Actions | Chiffres | Champs | Clics | Charge |
|---|---|---|---|---|---|---|---|---|---|
| Accueil direction | Direction | GET /school-admin/classrooms | school_admin/classrooms/index (+_school_card, _levels, carousel, activities/_activity, student_searches/_form) | 4 cartes + bandeau arrivées (+ alertes) | ~9 fixes + 1 par niveau (≤7) + 1 par alerte + liens activité | 3 tuiles + 2 par niveau (taux pastille + « Faits seul 7 j ») = jusqu'à 17 | 1 (recherche élève) | 1 vers niveau, 2 vers classe | **4** |
| Page d'un niveau | Direction | GET /school-admin/levels/:slug | school_admin/levels/show (+_classroom_card, level_archive_menu, archives_toggle, signal_legend) | N cartes classe + légende | 1 ⋮ niveau + par classe : lien + ⋮ (3-4 items) | par classe : effectif, devoirs, % rendu, moyenne % + pastille (4N) | 0 | 2 depuis accueil → classe | **3 (frôle 4)** |
| Page d'une classe | Direction | GET /school-admin/classrooms/:public_id | school_admin/classrooms/show (+ classroom/classrooms/_link, _gaps, _roster_title, modales retrait) | 3 sections + 3 tuiles + tableau | lien : 5 (copier, WhatsApp, changer…) + recherche + par élève ⋮+modale + gaps | 3 tuiles (devoirs, % rendus, moyenne %) + 2 par élève (n/total, moyenne %) + compteurs gaps | 1 (recherche) | 3 depuis accueil | **4** |
| Recherche élève | Direction | GET /school-admin/students/search | student_searches/show + _form | 1 carte | 1 recherche + 1 lien/résultat | 1 compteur | 1 | 2 | **1** |
| Enseignants | Direction | GET /school-admin/teachers | teachers/index | 1 carte-tableau | 1 « Anciens » + ⋮ par ligne | 0 (compte dans sous-titre) | 0 | 1 (nav) | **2** |
| Retirer enseignant (modale) | Direction | GET /teachers/:id/removal | teachers/removal | 1 modale | 2 | 0 | 0 | +2 | **1** |
| Anciens enseignants | Direction | GET /teachers/departed | departed_teachers/index | 1 liste | 1 retour + 1 « Réintégrer » par ligne | 0 | 0 | 2 | **1** |
| Anciens élèves | Direction | GET /students/departed | departed_students/index | 1 carte-tableau | 1 recherche + retour | 2 colonnes chiffres (envoyés, moyenne %) par ligne + compteur | 1 | 2 depuis accueil (lien pied de carte) | **3** |
| Activité récente | Direction | GET /school-admin/activity (frame) | activities/_activity | 1 flux | 1 lien classe/événement | horodatages | 0 | 0 (inclus accueil) | **2** |
| Établissement | Direction | GET /school-admin/school | schools/show (+_link, shared/school_staff, shared/level_classrooms) | 3 cartes + notices | lien : copier, WhatsApp ; équipe : ⋮/retrait + places ; niveaux : −/+ ×(≈8-15 niveaux) + modales | par niveau : nb de classes (N) + places | 0 saisie, boutons +/- | 2 depuis accueil | **4** |
| Réglages classe (modale) | Direction | GET /school-admin/school/classroom-settings/:id/edit | classroom_settings/edit (+shared/classroom_settings_form) | 1 modale | 2 | plafond (1) | 2 (suffixe, plafond) | +3 (⋮ → Modifier) | **2** |
| Archiver/restaurer classe/niveau | Direction | PATCH/POST classroom-archivals, level-archivals | turbo_stream (menus ⋮ + modales) | — | confirmation | effectifs dans la modale | 0 | +2 | **1** |
| Retirer une direction | Direction | DELETE school/staff/:id | turbo_stream (⋮ dans school_staff) | — | confirmation | 0 | 0 | +2 | **1** |
| Inscription direction | Direction (visiteur) | GET school_staff_registrations/new | identity/school_staff_registrations/new + _form (+shared/staff_position_fieldset) | 1 carte, 5 fieldsets | 1 submit + lien connexion | 0 | **9** (nom, prénom, genre, tel, code école, fonction, PIN ×2) | 1 écran, 9 saisies | **3** |
| Choix établissements d'une DRENA | Visiteur | GET /drenas/:id/schools | school/drena_schools/index (frame) | 1 select | 0 | 0 | 1 | 1 | **1** |
| Niveaux d'un établissement | Élève (visiteur) | GET /schools/:id/levels | school/school_levels/index | 1 frame | 0 | 0 | 1 groupe de radios (≤7 pastilles) | 1 | **1** |
| Classes d'un niveau | Élève (visiteur) | GET /schools/:id/levels/:slug/classrooms | school/level_classrooms/index | 1 frame | 0 | badges « Complète » | 1 groupe radios (grille 2-4 col.) | 1 | **1** |
| Établissements de l'enseignant | Enseignant | GET /teachers/schools | school/teacher_schools/index (+_join_fields) | 2 (liste + carte ajout) | ≤3 quitter + 1 rejoindre | « n / MAX » | 2 selects | 2 | **2** |
| Rejoindre par lien | Enseignant | GET /teachers/schools/join/:token | school/teacher_school_joins/new | 1 carte | 2 | 0 | 0 | 1 | **1** |
| Établissement courant (switch) | Enseignant | PATCH /teachers/current-school | school/current_schools (redirige) | — | 1 | 0 | 0 | 1 | **1** |
| Garant (Je confirme) | Enseignant | POST /teachers/join-requests/:id/vouch | join_request_vouches/create.turbo_stream | — | 1 | 0 | 0 | 1 | **1** |
| Mon établissement | Élève | GET /students/school | school/student_schools/show | 1 carte | 1 retour | 0 | 0 | 1 | **1** |

### Équipe (a→i)

| Écran | Rôle | Route | Vue | Blocs | Actions | Chiffres | Champs | Clics | Charge |
|---|---|---|---|---|---|---|---|---|---|
| Accueil équipe | Équipe | GET /teams | homes/show (+_shortcuts, _recent_content, _deletion_requests, _archived_staff) | 2 cartes + 3 listes récentes + 2 bandeaux conditionnels | 7 boutons-raccourcis + 3 listes de liens + 1 bouton régions | 3 compteurs (DRENA/établiss./classes) | 0 | 1 vers toute tâche | 3 (frôle 4) |
| Pilotage (dashboard) | Équipe | GET /teams/dashboard | dashboards/show (+8 partials) | 7 cartes/blocs (filtres, 2 cartes de chiffres, niveaux, inscrits, tableau, recherche) | ~12 (4 périodes, select, valider, effacer, N liens DRENA, 2 recherches, pagination) | ≈60 à 100+ (9 tuiles période + taux de réussite %, 8 tuiles « maintenant », % par niveau, tableau 5 colonnes × N lignes) | 4 (période, DRENA, recherche école, recherche compte) | 2 à 4 | 5 |
| Croissance | Équipe | GET /teams/growth | growth/show | 5 cartes (K, 6 tuiles, parrains, classement écoles, en attente) | 3 liens + 4 puces de période | ≈30 (K en 5xl, formule, % conversion, 6 tuiles, listes) | 0 | 2 (lien accueil → écran) | 4 |
| Corrigé d'un cours | Équipe | GET /teams/courses/:slug/answer-key | answer_keys/show (+_practice) | 1 carte par exercice (N) | 0 | 1 + points par question, tolérance | 0 | 3 (accueil → cours → corrigé) | 3 |
| Imports : liste | Équipe | GET /teams/imports | imports/index (+_import_row) | 1 tableau + puces de filtre | menu « Nouveau » (kinds) + 5 puces + 1 lien/ligne | 3 compteurs/ligne (importés, ignorés, erreurs) | 0 | 2 | 3 (frôle 4) |
| Imports : nouveau (modal) | Équipe | GET /teams/imports/new?kind= | imports/new + kinds/_course_tree, _schools, _drenas, 7 _*_example | 1 modal + aide (accordéons) | 2 (annuler, envoyer) | limites (Mo, nb fichiers) | 1 fichier (multi) | 3 | 3 |
| Imports : rapport | Équipe | GET /teams/imports/:id | imports/show + _status, _counters, _files, _import_errors | 1 carte, états conditionnels | 0-1 | 3 compteurs + liste de détails + erreurs | 0 | 3 | 3 |
| Blog : liste | Équipe | GET /teams/blog | articles/index + _article_row | 1 tableau | 1 « Nouvel article » + menu ⋮ par ligne | total + « lectures » par ligne | 0 | 2 | 2 |
| Blog : nouveau/modifier | Équipe | GET /teams/blog/new, /:id/edit | articles/new, edit, _form, _edit_modal, _image_alt_row | 1 formulaire (modal) + panneau images | 5-6 (insérer image, retirer couv., annuler, enregistrer…) | compteur de caractères | ≈10 (titre, extrait, couverture+alt, corps riche, alt par image, signature) | 3 | 3 (frôle 4) |
| DRENA : liste | Équipe | GET /teams/drenas | drenas/index + _drena_row | 1 tableau 5 colonnes | 2 en-tête + ⋮ par ligne | 2 compteurs/ligne (établiss., classes) | 0 | 2 | 2 |
| DRENA : nouveau/modifier/suppression | Équipe | /teams/drenas/new, /:id/edit, /:id/deletion | drenas/new, edit, _form, deletion | modal | 2 | 0 | 2 (nom, slug) | 3 | 1 |
| Barème des classes | Équipe | GET /teams/classroom-plan | classroom_plans/show + _line_row, _totals | 1 tableau 4 col + totaux | ⋮ par ligne | 4 totaux + effectifs/ligne | 0 | 2 | 3 |
| Barème : ligne (modal) | Équipe | GET /teams/classroom-plan/:level/…/edit | classroom_plans/edit | modal | 2 | 1 plafond | 1 | 3 | 1 |
| Réglages classe (modal) | Équipe | /teams/schools/:id/classroom-settings/:id/edit | classroom_settings/edit | modal | 2 | plafond | 2 | 4 | 1 |
| Régénération de codes (modal) | Équipe | GET /teams/schools/code-regenerations/new | code_regenerations/new, _form | modal avec règles + recompte | 4 (annuler, confirmer, 2 liens d'année) | 1 compteur (à retaper) | 1 + 5 cachés | 3 | 2 |
| Recherche de compte | Équipe | GET /teams/accounts | account_lookups/show, _result | 1 recherche + 1 fiche | 3 (code d'accès, réinit. 2FA, supprimer) + frame demande de suppression | 0 | 1 téléphone | 2 | 3 (frôle 4) |
| Suppression de compte (modal) | Équipe | GET /teams/accounts/:id/deletion/new | account_deletions/new | modal | 2 | 0 | 1 | 4 | 1 |
| Demandes de suppression : liste | Équipe | GET /teams/deletion-requests | deletion_requests/index, _due | 1 liste | 1 lien/ligne | échéances | 0 | 2 | 2 |
| Demande de suppression : nouvelle/fiche | Équipe | …/accounts/:id/deletion-request(/new) | deletion_requests/new, show, _account_block | modal / bloc | 2-3 | 0 | 2 | 4 | 1 |
| Illustrations d'annonce | Équipe | GET /teams/announcement-illustrations | announcement_illustrations/index, _illustration | 1 carte d'ajout + 2 sections (équipe / base) | ⋮ par illustration + ajouter | 0 | 2 (nom, image) | 2 | 2 |
| Illustration : renommer | Équipe | …/:id/edit | announcement_illustrations/edit | modal | 2 | 0 | 1 | 3 | 1 |
| Cours : nouveau/modifier | Équipe | /teams/courses/new, /:slug/edit | courses/new, edit, _form | modal | 2 | 0 | ≈6 (nom, matière, niveau, série, contenu riche…) | 2 | 2 |
| Invitation équipe (modal) | Équipe | GET /teams/invitations/new | invitations/new, created, _created | modal | 2 | 0 | 2 (tél., rôle radio) | 3 | 2 |
| Pilotage — référentiel (hors A) | — | — | — | — | — | — | — | — | non couvert |

### Équipe (j→z)

| Écran | Rôle | Route | Vue | Blocs | Actions | Chiffres | Champs | Clics | Charge |
|---|---|---|---|---|---|---|---|---|---|
| Liste des établissements | équipe | GET /teams/schools | schools/index + _filters + _school_row + _codes_menu | 3 (en-tête, filtres, tableau) | ~9 en-tête/filtres + ⋮ par ligne (3) ; 2 menus + 1 modale | 2 compteurs/ligne + total ; 8 colonnes | 5 (recherche + 4 selects) | 1 pour ouvrir une fiche | 4 |
| Fiche établissement | équipe | GET /teams/schools/:id | schools/show + _header + _classroom_group + shared/level_classrooms + shared/school_staff + _archived_staff + _join_requests | 8 à 10 (en-tête+code, bloc « − n + », 1 section/niveau, direction, directions retirées, demandes, liste enseignants) | 25 à 40+ (en-tête ~8 dont menu ⋮ 6 items, 2 boutons copier ; − et + par ligne niveau ; ⋮ + copier lien par classe ; ⋮ par niveau) | 10+ (classes, élèves/classe, enseignants/classe, compteurs niveau, N lignes « − n + ») | 0 (formulaires dans modales) | 1 pour voir ; 3 pour ajouter/retirer une classe | 5 |
| Modifier établissement | équipe | GET /teams/schools/:id/edit (modale) | schools/edit + _form | 1 | 2 | 0 | 6 | 3 | 2 |
| Désactiver établissement | équipe | GET .../deactivation (modale) | schools/deactivation | 1 | 2 | 0 | 1 | 3 | 1 |
| Supprimer établissement | équipe | GET .../deletion (modale) | schools/deletion | 1 | 2 | 0 | 1 | 3 | 1 |
| Ajouter une classe | équipe | GET .../classrooms/new (modale) | school_classrooms/new + _form | 1 | 2 | 0 | 5 | 3 | 2 |
| Inviter la direction | équipe | GET .../staff-invitations/new | staff_invitations/new, _created, created | 1-2 | 3 | 0 | 3 | 4 | 2 |
| Poste d'un membre de direction | équipe | GET .../staff/:id/position/edit | school_staff_positions/edit | 1 | 3 | 0 | 2 | 3 | 1 |
| Retrait / restauration direction, régénération code, reset 2FA, archivage niveau, MAJ niveau-classes | équipe | PATCH/DELETE/POST (turbo_stream seul) | *.turbo_stream.erb | 0 | 0 | 0 | 0 | n/a | 1 |
| Niveaux (liste) | équipe | GET /teams/levels | levels/index + _level_row | 1 tableau | 1 + 2/ligne | 0 | 0 | 1 | 2 |
| Niveau nouveau / modifier | équipe | /teams/levels/new, /:slug/edit | levels/new, edit, _form | 1 | 2 | 0 | 2 | 3 | 1 |
| Séries (liste + matrice niveaux × séries) | équipe | GET /teams/series | series/index + _series_row + _matrix + level_series/_cell | 2 (liste, matrice) | 1 + 2/ligne + 1 bouton par case | 0 | 0 | 1 | 3 |
| Série nouvelle / modifier | équipe | /teams/series/new, /:slug/edit | series/new, edit, _form | 1 | 2 | 0 | 1 | 3 | 1 |
| Matières (liste) | équipe | GET /teams/materials | materials/index + _material_row | 1 tableau | 1 + 2/ligne | 0 | 0 | 1 | 2 |
| Matière nouvelle / modifier | équipe | /teams/materials/new, /:slug/edit | materials/new, edit, _form | 1 | 2 | 0 | 2 | 3 | 1 |
| Référentiel (hub) | équipe | GET /teams/referential | referentials/show + _summary | 2 (6 tuiles, carte « structure ») | 6 liens | 6 compteurs + niveaux/séries en pastilles | 0 | 2 pour entrer dans une sous-liste | 2 |
| Authoring catalogue (en-têtes enseignant) | équipe/enseignant | catalog.rb (cours, fiches) | catalog/courses/_teacher_header, _teacher_course, sheets/_teacher_bar | 1 | 2-3 | 0 | 0 | 1-2 | 1-2 |

### Transverse et public

| Écran | Rôle | Route | Vue | Blocs | Actions | Chiffres | Champs | Clics | Charge |
|---|---|---|---|---|---|---|---|---|---|
| Accueil public | visiteur | GET / | homepage/index (70 l.) + _role_modal | 1 feuille + photo | 2 CTA (+1 drapeau) + 7 pastilles matières (desktop) | 0 | 0 | 1 | 1 |
| Connexion | tous | GET /login | identity/sessions/new (62) | 1 carte | 1 submit + 2 liens (PIN oublié, inscription) | 0 | 2 (contact, PIN) | 1 | 1 |
| Invitation équipe/direction | invité | GET /invitations/:token | identity/invitations/show (104) | 1 carte + panneau gauche | 1 submit | 0 | 5 (nom, prénom, genre, PIN, confirm.) | 1 | 3 |
| Compte en attente | élève/direction sans école | GET /account/pending | identity/pending_accounts/show (47) | 1 état vide | 2-3 (rejoindre, archive, déconnexion) | 0 | 0-1 (code) | 1 | 2 |
| Second facteur (login) | équipe | GET /identity/second-factor/new | second_factors/new (45) | 1 carte | 1 submit + 2 liens | 0 | 1 code (+ secours) | 1 | 1 |
| Second facteur enrôlement + codes secours | équipe | /identity/second-factor/enrollment | second_factor_enrollments/new + backup_codes | 1 carte chacun | 1-3 | codes de secours (liste) | 1 | 2 | 2 |
| Réinit. PIN | tous | GET /identity/pin-reset/new | pin_resets/new (39) | 1 carte | 1 submit + 1 lien | 0 | 3-4 (contact, code, nouveau PIN, confirm.) | 1 | 2 |
| Photo de profil | tous | GET /profile/photo/edit (modal) | profile_photos/edit (50) | modale | 3-4 (choisir, valider, retirer, annuler) | 0 | 1 fichier | 2 | 1 |
| Profil non-élève | enseignant/direction/équipe | GET /profile | profiles/show (33) + _information (82) | 3 cartes (infos, Ambassadeur si >= seuil, sécurité) + thème | ~5 boutons (photo, nom, contact, PIN, thème) | 1 (nb parrainés si ambassadeur) | 0 (modales) | 2 | 3 |
| Profil élève | élève | GET /profile | profiles/_student + _student_identity/_information/_row | 2 cartes, 6 lignes | 1-2 liens | 0 | 0 | 1-2 | 1 |
| Modales profil (nom, contact, PIN, matières) | tous | /profile/{name,contact,pin,materials} | profile_names/contacts/pins/materials | modale | 2 chacune | « N sur 3 » (matières) | 2 / 1-2 / 3 / cases | 2-3 | 1-2 |
| Code de récupération PIN | direction/prof | POST /accounts/:id/pin-recovery-codes | pin_recovery_codes/_code (24) | 1 | 1 | 0 | 0 | 1 | 1 |
| Parrainage | enseignant | GET /teachers/invite | referrals/show + _invite (39) + _sponsor (25) | 1-2 cartes | 4 (WhatsApp, SMS, copier, partage natif) par carte | 1 compteur parrainés + badge Ambassadeur | 0 | 1-2 | 2 |
| Inscription enseignant | prof | GET /teacher-signup | teacher_registrations/new (85) + _form (122) + _school_fields + _school_preview | 3 fieldsets (école, vous, sécurité) | 1 submit + 2-4 liens | 0 | 8-10 (école, matière, nom, prénom, genre, contact, PIN, confirm., + champs école) | 1 (long) | 4 |
| Inscription direction | direction | GET /school-staff-signup | school_staff_registrations/new + _form (63) | 3 blocs | 1 submit + 3 liens | 0 | 7-8 | 1 | 3 |
| Pages niveaux | public | GET /niveaux | catalog/level_pages/index (44) | 1 liste | ~N liens niveaux | cours/niveau | 0 | 1 | 1 |
| Page niveau | public | GET /niveaux/:slug | level_pages/show (49) | 1 liste séries/matières | N liens | cours/série | 0 | 1 | 1 |
| Page série | public | GET /niveaux/:l/:s | series_pages/show (59) | 1 liste matières | N liens | cours | 0 | 1 | 1 |
| Page matière | public | GET /matieres/:slug | material_pages/show (64) + _page (38) | pastilles niveau + groupes | N liens + « Voir plus » | « N cours » partout | 0 | 1-2 | 2 |
| Pages légales (mission, confidentialité, CGU, CGV) | public | /mission etc. | communication/pages/_page (53) | 1 texte | 0-2 liens | 0 | 0 | 1 | 1 |
| Blog liste / article / retiré | public | /blog, /blog/:slug | articles/index (30), show (48), _article_card, gone | grille de cartes / 1 article | 1-2 | 0 | 0 | 1-2 | 1 |
| Aide | tous | GET /aide | help/show (32) + _questions (30) | 2 cartes (FAQ) | 1 lien | 0 | 0 | 1 | 1 |
| Annonces (boîte) | élève/direction | GET /announcements | inboxes/show (21) + messages/_carousel (40) + _card (79) | carrousel de cartes | lecture audio, « masquer », restaurer | 0 | 0 | 1 | 2 |
| Mes annonces | auteur | GET /announcements/mine | authored_messages/index + _row (47) | liste de lignes | 2 par ligne (modifier, retirer/archiver) | 0 | 0 | 1-2 | 2 |
| Nouvelle / modifier annonce | auteur | /announcements/new, /:id/edit | authored_messages/_form (156) | 1 form : titre, texte, portée, public, thème, 8+ illustrations, image, audio, date publication | 3 (annuler, brouillon, publier) | 2 compteurs de caractères | 11 + choix thème/illustration | 2-3 | 4 |
| Modération annonces | équipe | GET /announcements/moderation | moderations/index (41) + _moderated_message | liste | 1-2 par ligne | 0 | 1 filtre | 1-2 | 2 |
| Shell : en-tête + latérale + barre basse | tous rôles connectés | layouts/shell | shared/navigation/* | - | voir ci-dessous | quota matières/écoles | 0 | - | 3 |
| Panneau « Mon compte » (enseignant) | enseignant | menu / dialog | navigation/_account_panel (148) | nom + liste d'établissements (dès 2) + 4 entrées + thème + déconnexion | ~8-10 | « N sur 3 » x2 | 0 | 2 | 3 |

## Top 10 à simplifier

| # | ID | Écran | Rôle | Charge | Pourquoi (en une ligne) | Gravité | Effort |
|---|---|---|---|---|---|---|---|
| 1 | E-001 | Résultat de session | élève | 5 | 6 blocs, note /20 + % + maîtrise + x/N + points + progrès à 3 notes alors que la médaille est déjà là | P1 | M |
| 2 | E-002 | Page d'une classe | enseignant | 5 | 6 blocs, 5 données par ligne d'élève, gestion + suivi mélangés | P1 | M |
| 3 | E-003 | Pilotage | équipe | 5 | 7 blocs, 60 à 100+ chiffres, 2 recherches, annuaire de comptes | P1 | M à L |
| 4 | E-004 | Fiche établissement | équipe | 5 | 8-10 sections, 25-40 actions, « − n + » qui double les cartes de classes | P1 | L |
| 5 | E-005 | Accueil enseignant | enseignant | 4 | 6-7 sections, moyenne /20 dans l'Historique | P1 | M |
| 6 | E-006 | Page d'une classe | direction | 4 | 3 tuiles + tableau avec moyenne %, lien d'invitation en tête | P1 | M |
| 7 | E-007 | Accueil direction | direction | 4 | 4 cartes, ≈ 17 chiffres, 3 types de pastilles | P1 | M |
| 8 | E-008 | Fiche élève | enseignant | 4 | note /20 + tendance + sessions par devoir, score % en entraînement libre | P2 | S-M |
| 9 | E-009 | Suivi d'un devoir | enseignant | 4 | cases badge ET notes par copie ET taux par question | P2 | S |
| 10 | E-010 | Page d'un cours | élève | 4 | fiche + entraînement + interros + devoirs, « x/y réussis » | P2 | M |

Suivent (charge 4, hors top 10) : E-011 Établissement (direction), E-012 Croissance (équipe), E-013 Liste des établissements (équipe), E-014 Annonce (formulaire), E-015 Inscription enseignant.

## Ce que la médaille remplace (inventaire consolidé)

| Où | Chiffre actuel | Remplacé par |
|---|---|---|
| Élève — résultat de session | note /20, Score %, maîtrise (texte), x/N justes, points, progrès à 3 notes, seuil en /20 (`gap_outcome`) | un médaillon + « Encore 1 point pour l'Or » |
| Élève — accueil (historique), archive, aperçu d'exercice | note /20 par ligne, « Meilleure note /20 », barème en points | médaille de la session / meilleure médaille |
| Élève — leçon, devoirs, feuilles | « x/y réussis » | médaille par feuille ; médaille de leçon en en-tête |
| Enseignant — page de classe | « Moyenne n/20 · Or », « Dernier score n % », « Fait seul (7 j) » | médaille seule (la pastille existe) |
| Enseignant — fiche élève | moyenne /20, pastilles par palier, note /20 + tendance + sessions, score % | une médaille d'élève ; médaille + date par devoir |
| Enseignant — suivi de devoir | première/meilleure note /20 par copie ; taux par question | médaille de la meilleure tentative ; taux replié (indicateur de difficulté, non une note d'élève) |
| Enseignant — accueil, historique | moyenne /20 (`average_percent / 5`) | médaille de classe pour le devoir |
| Direction — classe, niveau, anciens élèves | moyenne % (tuile, colonne, carte) | médaille de classe / par élève |
| Direction — accueil, niveaux | pastille de taux de rendu à 3 seuils + « Faits seul 7 j » | médaille du niveau ; légende = les 4 médailles |
| Équipe — Pilotage, Croissance | taux de réussite % ; colonnes numériques ; badge « cible » | médaille de territoire (part d'élèves ≥ Argent) ; médaille d'étape de parrainage |
| Équipe — corrigé | points par question | rien (vestige de notation) |

À garder en chiffres : effectifs, places, plafonds, compteurs de gestion (ce ne sont pas des notes).
Clés I18n à retirer côté enseignant : `badge_grade`, `average_none`, `average` (classroom_students), `last_score`, `copy_summary`, `assessment.badges.grade`.

**Point de vigilance (décision du porteur, non tranchée ici)** : UDR-0057/0119/0131 et ADR-0106 fixent « note sur 20 partout ». Retirer les notes demande une UDR qui amende ces décisions, et la maîtrise (Acquis/Fragile/En difficulté, seuil 14/20) et le seuil de remédiation (10/20) restent calculés sur la note en interne : seul l'affichage change.

## Entrées détaillées (écrans de charge 4-5)

### E-001 — Résultat de session

- **Rôle** : élève · **Route** : `GET /sessions/:id/result` · **Vue** : `app/views/assessment/session_results/show.html.erb` (181 l.) + `_badge`, `_progress`, `_gap_outcome`, `_question_review`, `kinds/*_review` · **Charge** : 5 · **Gravité** : P1 · **Effort** : M


- **Tâche principale de l'élève** : savoir si j'ai réussi, puis refaire ou continuer.
- **Ce qui encombre** : 14 fichiers. Six blocs sur un écran. La note /20, le « Score X % » (côté non-propriétaire), le tableau de maîtrise, « x/N justes » et les « points » disent tous la même chose. À cela s'ajoutent la phrase de progrès avec 3 notes (`first`, `best`, `current`), le bloc « fiche à revoir » avec une consigne exprimée en note (`gap_outcome`, seuil `REMEDIATION_THRESHOLD`), la liste des numéros faibles, l'énoncé repliable et la correction question par question avec en plus un bloc « Correction » séparé. Deux colonnes sur ordinateur, avec un côté collant.
- **Essentiel** : le badge Bronze/Argent/Or/Diamant (déjà présent, `_badge`), la phrase d'encouragement, un seul bouton principal (Refaire si échec, sinon Continuer), la correction par question.
- **À retirer** : tuile « Note /20 », tuile « Score % », tuile « x/N justes », bloc `session_points`, `_progress` (3 notes), la consigne en /20 de `_gap_outcome`.
- **À replier** : correction détaillée (un `details` par question, ouvert sur les fausses), énoncé, « à revoir ».
- **À déplacer** : « Refaire sur la notion » et « Ouvrir la notion » passent dans un seul bouton « Revoir la notion » sous le badge.
- **Ce que la médaille remplace** : tout le haut (3 à 4 tuiles chiffrées + progrès + consigne) devient le médaillon, avec le texte « Argent obtenu » ou « Encore 1 point pour l'Or ». La maîtrise (Acquis/Fragile/En difficulté) double déjà le palier ; la supprimer.

```
+---------------------------+
|        ( MÉDAILLE )       |
|      ARGENT  Nouveau !    |
|  « Bravo, tu progresses » |
|  [ Continuer ]  (principal)|
|  Refaire (lien secondaire)|
+---------------------------+
| ▸ Revoir la notion (1)    |
| ▸ Correction (6 questions)|  <- replié, fausses ouvertes
+---------------------------+
```

- **Gravité** : P1. **Effort** : M (la maîtrise et la note sont aussi lues par des tests et par l'accueil ; les textes I18n changent).
- **Parcours** : un seul chemin, mais l'écran est multi-tâches (bilan, diagnostic, remédiation, correction, relance).

### E-002 — Page d'une classe (enseignant)

- **Rôle** : enseignant · **Route** : `GET /classrooms/:id` · **Vue** : `app/views/classroom/classrooms/show.html.erb` + `_header`, `_session_days`, `_link`, `_assigned_exercises`, `_gaps`, `_roster` (≈ 290 l.) · **Charge** : 5 · **Gravité** : P1 · **Effort** : M


**Tâche principale** : voir où en est ma classe (qui a du mal, qui a fini) et agir (assigner, ouvrir un élève).

**Ce qui encombre**
- 6 blocs empilés (ou 2 colonnes dès lg) : en-tête, jours de séance, lien d'inscription (WhatsApp + copier + menu + modale « changer le lien »), exercices assignés (cartes), fiches à revoir, liste d'élèves.
- Chaque ligne d'élève porte 5 données : « 9 faits sur 18 · 1 en retard », « Moyenne 15/20 · Or », « Fait seul (7 j) », « Dernier score 80 % » et « Voir le résultat ». Plus 2 en-têtes de colonnes à info-bulle.
- Le tout se double d'une rangée de 5 puces de filtre (Tous, Bronze, Argent, Or, Diamant, Pas encore) en plus d'une recherche.
- Gestion de la classe (lien, jours de séance) mélangée au suivi pédagogique.

**Essentiel** : la liste d'élèves avec un seul état par élève, les exercices en cours, un accès à l'assignation.

**À retirer/replier/déplacer**
- Replier « Lien d'inscription » et « Jours de séance » dans un menu « Gérer la classe » (rarement utilisés ; le code est déjà sur la carte de l'accueil).
- Retirer « Dernier score % » + lien « Voir le résultat » de la ligne (le résultat est dans la fiche élève).
- Retirer « Moyenne /20 » et « Fait seul (7 j) » de la ligne ; « Fait seul » devient un détail de la fiche.
- Garder « x faits sur y » (en retard en couleur) + médaille.
- Fiches à revoir : replier en un compteur cliquable (« 3 notions à revoir »).

**Ce que la médaille remplace** : « Moyenne 15/20 · Or » -> médaille Or seule ; « Dernier score 80 % » -> supprimé ; la pastille de ligne existe déjà (BADGE_PILL), il suffit d'enlever le texte « Moyenne n/20 ». Les 5 puces de filtre sont déjà des médailles.

```
┌ ← Mes classes ─────────────── CM2 A · 2026 ┐
│ [ Gérer la classe ▾ ]  (lien, jours)        │
│ 🔎 Chercher un élève                        │
│ [Tous][🥉][🥈][🥇][💎][Pas encore]          │
│ ─────────────────────────────────────────── │
│ (o) Awa K.        9/18  ⚠1           🥇     │
│ (o) Moussa D.     12/18              🥈     │
│ (o) Fatou S.      3/18  ⚠4        Pas enc.  │
│ ─────────────────────────────────────────── │
│ Devoirs en cours (3)   >                    │
│ Notions à revoir (3)   >                    │
└─────────────────────────────────────────────┘
```

**Gravité** : P1 (écran le plus consulté après l'accueil). **Effort** : M (retirer des colonnes = S ; menu « Gérer » + replis = M ; les clés I18n `badge_grade`, `average_none` et les tests d'ids `progress_`, `self_practice_`, `badge_` sont à ajuster). **Parcours/multi-tâches** : oui, écran multi-tâches (gérer la classe + suivre + assigner + chercher).

### E-003 — Pilotage

- **Rôle** : équipe · **Route** : `GET /teams/dashboard` · **Vue** : `app/views/teams/dashboards/show.html.erb` + 8 partials · **Charge** : 5 · **Gravité** : P1 · **Effort** : M (retrait) à L (version maîtrise)

- Tâche principale du rôle équipe : savoir en un coup d'œil si l'usage décolle et où intervenir (quelle DRENA/école est à la traîne), puis aller à l'école concernée.
- Ce qui encombre : 7 blocs empilés ; 17 chiffres de tête (9 période, 8 « maintenant ») + taux de réussite en % + 2 infobulles ; part des élèves par niveau avec barres et % ; 5 colonnes numériques par DRENA puis par école ; 2 formulaires de recherche (école, compte) plus un filtre DRENA et 4 puces de période. C'est un écran multi-tâches : pilotage, annuaire de comptes, recherche d'école, suivi d'inscriptions.
- Essentiel : périodes, filtre DRENA, 4 chiffres d'adoption (inscrits, élèves actifs, classes, écoles actives), liste DRENA/écoles, lien vers l'école.
- À retirer ou replier : détail app_openers (4 lignes Android), couverture des écoles (3 sous-chiffres), part par niveau, dernières inscriptions, recherche de compte (déjà couverte par `/teams/accounts`) ; replier tout sous « Plus de détails ».
- Médaille/badge : le « taux de réussite moyen » (%) devient la médaille dominante du territoire (Bronze/Argent/Or/Diamant) ; par DRENA ou école, remplacer la colonne « élèves actifs » et le % par une pastille médaille de maîtrise (ex. part d'élèves ayant au moins Argent). Les compteurs d'effectifs restent en chiffres bruts (ce ne sont pas des notes) mais passent de 5 colonnes à 2.
- Version simplifiée :
```
Pilotage            [Année | Trimestre | 30 j]   [DRENA ▾]
+-------------------------------------------------+
| 1 240 inscrits   860 actifs   Maîtrise : (Or)   |
+-------------------------------------------------+
| DRENA / École            Actifs     Maîtrise    |
| Abidjan 1                 410        (Argent)   |
| Abidjan 2                 280        (Bronze)   |
| ...                                  [voir ▸]   |
+-------------------------------------------------+
[+ Détails : niveaux, inscrits récents, appareils]
```
- Parcours : 2-4 clics (période → DRENA → école) ; trop de blocs avant d'atteindre la liste.

### E-004 — Fiche établissement

- **Rôle** : équipe · **Route** : `GET /teams/schools/:id` · **Vue** : `app/views/teams/schools/show.html.erb` + `_header` (124 l.), `_classroom_group`, `shared/level_classrooms`, `shared/school_staff`, `_archived_staff`, `_join_requests` · **Charge** : 5 · **Gravité** : P1 · **Effort** : L

Tâche principale de l'équipe : vérifier qu'un établissement est actif, que sa direction est en place et que ses classes/enseignants sont rattachés ; au besoin inviter la direction ou valider un enseignant.
Mesures : 8-10 sections empilées en 2 colonnes (lg:grid-cols-main-aside). _header seul : 124 lignes, 1 carte, 5 boutons, 2 modales, menu ⋮ de 6 entrées, 2 boutons « copier », 1 lien d'invitation, bloc code + date de rotation + indice + info-bulle. Bloc « − n + » : 1 ligne par niveau × série, 2 boutons + 1 compteur par ligne. Puis 1 section par niveau, avec badges de comptes, menu d'archivage de niveau, et pour chaque classe : lien, menu ⋮ (archiver/restaurer/modifier), élèves, enseignants, bouton « copier lien ». Colonne droite : direction, directions retirées, demandes en attente, liste enseignants avec matières + badge « secondaire ».
Ce qui encombre : (1) le bloc « − n + » ET les cartes de classes disent la même chose (nombre de classes par niveau) ; (2) le bloc code d'établissement (code + date + indice + lien + 2 boutons copier) occupe un tiers de l'en-tête ; (3) les deux mécanismes de copie de lien (établissement, chaque classe) ; (4) listes « directions retirées » et « archives » rarement utiles ; (5) menu ⋮ avec action destructive admin mélangée aux actions courantes.
Essentiel : nom, statut, code (copier), demandes d'enseignants en attente (action), direction (inviter/retirer), liste des classes.
À retirer/replier/déplacer : replier par défaut les sections par niveau (une ligne : niveau + n classes) et ne déplier qu'à la demande ; fusionner « − n + » avec la ligne de niveau (une seule vérité) ; replier « Directions retirées » et « Archives » ; déplacer le lien d'invitation et la date de rotation dans un volet « Code et liens » replié ; garder « Demandes en attente » en tête (seule action urgente).
Médaille/badge : aucun score à remplacer. Un seul badge d'état (Actif / À compléter / Désactivé) peut résumer « code distribué + direction nommée + >= 1 classe », ce qui remplace statut + info-bulle + avertissements inactifs. Les compteurs élèves/enseignants par classe passent dans le détail de la classe.
Schéma simplifié :
```
< Établissements
[EPP Cocody]  Actif ●   DRENA Abidjan 2      [+ Classe] [⋮]
Code 4821  [Copier]   (Liens et codes ▾)
------------------------------------------------------------
! 2 enseignants en attente   [Valider] [Refuser]
Direction : M. Koné  [Retirer]   (+ Inviter)
Classes (12)
  ▸ CP1 · 3 classes      ▸ CE1 · 2 classes   ...   (repliés)
Enseignants (9)   [liste compacte]    ▸ Archives (3)
```
Gravité : P1 (écran le plus consulté du rôle, surchargé mais fonctionnel). Effort : L (7 partials, Turbo Streams multiples, tests système). Parcours : multi-tâches (code, direction, classes, enseignants, demandes) ; ajouter/retirer une classe = 3 clics (ouvrir fiche, +/−, confirmer).

### E-005 — Accueil enseignant

- **Rôle** : enseignant · **Route** : `GET /teachers` · **Vue** : `app/views/classroom/teacher_homes/show.html.erb` + 7 partials (≈ 295 l.) · **Charge** : 4 · **Gravité** : P1 · **Effort** : M


**Tâche principale** : ouvrir ma classe, voir ce qui est en retard.

**Ce qui encombre** : 6-7 sections (bandeau, carrousel de cartes classe, grille « niveaux/cours », annonces, « Cette semaine », « Historique »). Chaque carte de classe : nb d'élèves, nb d'assignations, 1 à 4 pastilles de badge, code + copier. « Cette semaine » : une barre + « x/y faits » + badge « en retard/à faire » par ligne. L'Historique affiche en plus une **moyenne /20** par exercice (calculée `average_percent / 5`) alors que « x/y faits » dit déjà la participation.

**Essentiel** : les classes (cartes) ; les devoirs qui demandent une action (en retard).

**À retirer/replier/déplacer** : retirer la moyenne /20 de l'Historique (garder « 12/18 faits ») ; replier l'Historique sous « Voir l'historique » ; déplacer la grille de niveaux/« Inviter » vers l'onglet Cours (elle double le menu) ; sur la carte, garder élèves + code, ôter « n assignations ».

**Médaille** : remplacer la moyenne /20 de l'Historique par la médaille de la classe pour ce devoir (calculée au même seuil `MASTERY_THRESHOLD`) ; les pastilles de la carte sont déjà des médailles.

```
┌ [ Mes classes  ◄  CM2 A | CM2 B | + ] ┐
│  CM2 A · 24 élèves · 🥇5 🥈8 🥉6      │
│  Code AB12CD [copier]                 │
├ À suivre cette semaine ───────────────┤
│  Fractions · 9/18 faits  ⚠ en retard  │
│  Conjugaison · 14/18 faits            │
└ Voir l'historique >───────────────────┘
```

**Gravité** : P1 (porte d'entrée). **Effort** : M. **Parcours/multi-tâches** : écran multi-tâches (suivi + cours + annonces + invitation).

### E-006 — Page d'une classe (direction)

- **Rôle** : direction · **Route** : `GET /school-admin/classrooms/:public_id` · **Vue** : `app/views/school_admin/classrooms/show.html.erb` (142 l.) · **Charge** : 4 · **Gravité** : P1 · **Effort** : M

- **Tâche principale** : voir quels élèves de cette classe ont besoin d'aide / où en est la classe, et retrouver un élève.
- **Ce qui encombre** : 3 tuiles de chiffres (devoirs, % rendus, moyenne % + infobulles) ; tableau 4 colonnes (élève, rendus n/total, moyenne %, ⋮) ; ⋮ + modale de retrait par élève (N modales dans le DOM) ; bloc lien d'invitation (copier/WhatsApp/changer, 5 actions) au-dessus de tout ; liste des « fiches à revoir » dont le sous-titre cite une note /20 (`grade_on_20(PASS_THRESHOLD)`) ; légende « — non calculé » + infobulles ; recherche live + bouton + état d'erreur.
- **Essentiel** : nom de l'élève, son niveau de maîtrise, le signal « à revoir », accès à l'élève.
- **À retirer/replier/déplacer** : moyenne % (colonne et tuile) ; « rendus n/total » à replier en détail ; lien d'invitation vers l'écran Établissement/enseignant (déjà là-bas) ou en bas replié ; retrait élève dans un menu secondaire ; recherche seulement si > 15 élèves.
- **Remplaçable par médaille/badge** : tuile moyenne -> médaille de classe (Bronze/Argent/Or/Diamant) ; colonne moyenne -> badge par élève ; sous-titre « seuil /20 » des fiches à revoir -> « niveau Bronze à atteindre ».
```
[← 6e]  6e A · 28 élèves                [Médaille classe: Argent]
Fiches à revoir : 3 (replié ▸)
-----------------------------------------
Élève            Médaille    ⋮
Awa K.  [nouveau] Or
Koffi N.          Bronze  ⚠ à revoir
...
[Inviter des élèves ▸ replié]  [Chercher ▸ si >15]
```
- **Parcours/multi-tâches** : écran multi-tâches (suivre + inviter + retirer + chercher). Accès : accueil -> niveau -> classe = 3 clics.

### E-007 — Accueil direction

- **Rôle** : direction · **Route** : `GET /school-admin/classrooms` · **Vue** : `app/views/school_admin/classrooms/index.html.erb` + `_school_card`, `_levels`, `activities/_activity` · **Charge** : 4 · **Gravité** : P1 · **Effort** : M

- **Tâche principale** : savoir « mon établissement va-t-il bien ? » et aller à la classe qui pose problème.
- **Ce qui encombre** : 4 cartes empilées ; carte Établissement : 3 chiffres + alertes + recherche + 2 liens ; bulles niveaux avec pastille de taux de rendu, « Faits seul (7 j) : N » sous chaque bulle (jusqu'à 7), légende des seuils ; carousel d'annonces ; flux d'activité (3 types d'événements, groupé par jour) ; bandeau d'arrivées. Environ 17 chiffres + 9 actions.
- **Essentiel** : alertes (ou « rien à signaler »), niveaux -> classes, recherche élève.
- **À retirer/replier/déplacer** : « Faits seul (7 j) » ; légende des seuils ; 3 chiffres d'effectif (déjà dans Établissement) ; activité récente -> page dédiée (lien) ; annonces conservées seulement si non lues ; bandeau d'arrivées fusionné avec les alertes.
- **Remplaçable par médaille/badge** : pastille de taux de rendu par niveau -> médaille du niveau ; légende de 3 seuils -> légende des 4 médailles (déjà connues) ; « rien à signaler » reste.
```
Bonjour Mme Diallo
[ Collège X — rien à signaler ✓ ]      (alertes sinon)
Niveaux :  (6e 🥈) (5e 🥇) (4e 🥉) (3e 🥈)   -> clic = classes
[Chercher un élève ____ ]
Établissement · Anciens élèves · Activité récente (liens)
```
- **Parcours** : tâche principale en 3 clics (accueil -> niveau -> classe). Écran multi-tâches (tableau de bord + recherche + flux + annonces).

### E-008 — Fiche élève (enseignant)

- **Rôle** : enseignant · **Route** : `GET /classrooms/:id/students/:sid` · **Vue** : `app/views/classroom/classroom_students/show.html.erb` + `_identity`, `_summary`, `_assignments`, `_self_practice`, `_manage` (≈ 190 l.) · **Charge** : 4 · **Gravité** : P2 · **Effort** : S-M


**Tâche principale** : comprendre où en est UN élève et lui donner de quoi progresser.

**Ce qui encombre** : 5 blocs ; résumé (« x faits sur y », « Moyenne n/20 · badge », pastilles par palier) ; liste de devoirs avec, par ligne : exercice, matière, échéance, **note /20 + médaille**, date, tendance, nb de sessions, lien « meilleur essai » ; liste d'entraînement libre avec **score %** par ligne + lien ; carte de gestion (code PIN, retirer).

**Essentiel** : l'état par devoir et une médaille globale ; l'action PIN/retirer, repliée.

**À retirer/replier/déplacer** : retirer « Moyenne n/20 » et les pastilles par palier du résumé (une seule médaille de l'élève) ; sur chaque devoir, ôter note /20, nb de sessions et tendance (garder médaille + date) ; entraînement libre : remplacer le score % par la médaille du meilleur essai ou par un simple compteur ; déplacer « Gestion » (PIN, retrait) dans un menu « … ».

**Médaille** : `grade_label(best)` -> `comprehension_trophy` seul ; « Moyenne 15/20 » -> médaille de classe de l'élève.

```
┌ ← CM2 A ──────────────────────────────┐
│ (o) Awa K.            médaille : 🥇   │
│ 9 faits sur 18 · ⚠1                   │
│ ───────────────────────────────────── │
│ Fractions        échu 12/11      🥇   │
│ Conjugaison      à faire        —     │
│ Entraînement libre (7 j)   4 fois  >  │
│                           [ … Gérer ] │
└───────────────────────────────────────┘
```

**Gravité** : P2. **Effort** : S-M (suppressions de colonnes, helper `grade_label` partagé avec d'autres écrans, tests à ajuster). **Parcours** : pas trop long (2-3 clics).

### E-009 — Suivi d'un devoir

- **Rôle** : enseignant · **Route** : `GET /classrooms/:id/assignments/:aid` · **Vue** : `app/views/classroom/assignment_follow_ups/show.html.erb` + `assessment/comprehension/_section`, `_badge_boxes` (≈ 145 l.) · **Charge** : 4 · **Gravité** : P2 · **Effort** : S


**Tâche principale** : savoir qui n'a pas fini et qui n'a pas compris cet exercice.

**Ce qui encombre** : sur un seul écran 4 couches : progression x/y, 5 cases de badge avec compteur, bloc « prochaine étape », liste des copies avec « première note /20 / meilleure note /20 », puis **taux de réussite par question** (barre + x/y) pour chaque question. Les cases badge ET les notes par copie disent deux fois la même chose.

**Essentiel** : progression, 5 cases badge (déjà des médailles, filtrent la liste), liste élèves avec leur médaille, une « prochaine étape ».

**À retirer/replier/déplacer** : retirer « première / meilleure note » (garder médaille ou « Pas encore ») ; replier le détail par question sous « Voir par question » ; garder la barre de progression globale.

**Médaille** : notes /20 par copie -> médaille de la meilleure tentative. Les cases badge sont déjà le bon modèle.

```
┌ ← CM2 A ──────────────────────────────┐
│ Fractions · éch. 12/11   [Voir]       │
│ ███████░░░ 9/18 faits      ⚠ 3 retard │
│ [Pas enc. 9][🥉2][🥈4][🥇2][💎1]      │
│ ➜ Prochaine étape : reprendre n°3     │
│ Awa K.          🥇                    │
│ Moussa D.       🥈                    │
│ ▸ Voir par question                   │
└───────────────────────────────────────┘
```

**Gravité** : P2. **Effort** : S (replis + suppression de notes). **Parcours** : écran dense mais mono-tâche.

### E-010 — Page d'un cours (leçon)

- **Rôle** : élève · **Route** : `GET /courses/:slug` · **Vue** : `app/views/catalog/courses/show.html.erb` + `_next_exercise`, `_revision_sheet`, `_prepare_sheets`, `sheets/_card` (≈ 1 140 l. au total) · **Charge** : 4 · **Gravité** : P2 · **Effort** : M


- **Tâche principale** : apprendre la leçon puis s'entraîner (« Je m'entraîne », interros, devoirs).
- **Ce qui encombre** : l'écran empile en-tête (badges matière/niveau + role_actions), carte « prochain exercice », fiche de révision complète (5 encadrés par notion : Retiens, Méthode, Figure, Exemple, Piège, plus « Je m'entraîne » avec un formulaire), puis deux sections de cartes de feuilles (interros, devoirs) avec « x/y réussis ». 1142 lignes de vues pour le cours. Page longue, trois activités sur une page (lire, s'entraîner, passer une interro/devoir).
- **Essentiel** : le « prochain exercice », la fiche de révision (c'est le contenu), l'accès aux feuilles.
- **À replier** : fiche par notion repliée avec « Voir tout » (coupure `revision-more` existe déjà) ; les deux sections de feuilles en une seule « S'évaluer ».
- **À déplacer** : les compteurs « x/y réussis » par feuille.
- **Ce que la médaille remplace** : `x/y réussis` par feuille devient une médaille par feuille (Bronze à Diamant), ce qui évite le compteur. Une médaille par leçon en en-tête remplace « commencé / fait ».
- **Schéma**

```
< Cours
Fractions  [Maths][6e]       🏅 Argent
[ Prochain exercice  → ]
Fiche de révision
 ▸ 1. Additionner      (replié, ouvert sur la notion à revoir)
 ▸ 2. Comparer
S'évaluer
 [Interro 1 🥈] [Interro 2 —] [Devoir 1 🥇]
```

- **Gravité** : P2. **Effort** : M.

### E-011 — Établissement (direction)

- **Rôle** : direction · **Route** : `GET /school-admin/school` · **Vue** : `app/views/school_admin/schools/show.html.erb` + `_link`, `shared/school_staff`, `shared/level_classrooms` · **Charge** : 4 · **Gravité** : P2 · **Effort** : M

- **Tâche principale** : inviter un enseignant / une direction ; vérifier l'équipe.
- **Ce qui encombre** : 3 blocs de natures différentes (lien d'invitation, équipe avec fonctions et places, structure : stepper −/+ par niveau, souvent ≥ 8 lignes avec modale de retrait par ligne) ; avis de rang ; avis d'inactivité.
- **Essentiel** : lien d'invitation (copier / WhatsApp), liste de l'équipe.
- **À retirer/replier/déplacer** : « classes par niveau » (structure, geste rare, début d'année) -> sous-page « Structure » ; places par code -> replié ; modales de retrait par ligne -> une seule modale chargée à la demande (comme teachers/removal).
- **Médaille/badge** : aucun chiffre de maîtrise ici ; rien à remplacer (les compteurs sont de gestion, pas de performance).
```
Collège X (public)
[ Lien d'invitation  [Copier] [WhatsApp] ]
Équipe (4)   Prénom N. – Directeur ⋮ ...
[Gérer les classes par niveau ›]  (page séparée)
```
- **Parcours** : 2 clics, mais écran multi-tâches (inviter + équipe + structure).

### E-012 — Croissance

- **Rôle** : équipe · **Route** : `GET /teams/growth` · **Vue** : `app/views/teams/growth/show.html.erb` (112 l.) · **Charge** : 4 · **Gravité** : P2 · **Effort** : S

- Tâche principale : savoir si le parrainage fait croître la base et relancer les établissements en attente.
- Ce qui encombre : coefficient viral K en 5xl avec formule (invitations/utilisateur, % conversion, cible, ambition), 6 tuiles dont deux obscures (cycle viral en jours, élèves/enseignant), 3 infobulles, 2 classements (parrains, écoles), liste des demandes en attente : 5 cartes et ≈30 chiffres. Écran de métriques produit sans lien avec la maîtrise.
- Essentiel : K avec badge « cible atteinte », nombre d'inscriptions parrainées, liste des écoles en attente (action).
- À retirer ou replier : 4 tuiles sur 6, classement des parrains, formule détaillée, cohort note ; tout sous un repli « Détail du parrainage ».
- Médaille/badge : le badge « cible » existant (success/warning) peut devenir une médaille d'étape de croissance (Bronze → Diamant selon K) ; supprime la lecture du chiffre.
- Version simplifiée :
```
Croissance            [7 j | 30 j | 90 j]
+------------------------------------+
| Parrainage : (Argent)  cible 1,0   |
| 42 inscriptions parrainées         |
+------------------------------------+
| En attente (3) : Collège X · Lycée Y |
+------------------------------------+
[+ Détail : conversion, cycle, classements]
```
- Parcours : 2 clics, écran déjà mono-tâche mais surchargé de chiffres.

### E-013 — Liste des établissements

- **Rôle** : équipe · **Route** : `GET /teams/schools` · **Vue** : `app/views/teams/schools/index.html.erb` (88 l.) + `_filters`, `_school_row`, `_codes_menu` · **Charge** : 4 · **Gravité** : P2 · **Effort** : M

Tâche principale : retrouver un établissement (ou en importer). 
Mesures : page_header avec 3 contrôles (Importer, menu Classes à 2 entrées, menu Codes admin) + modale de génération ; barre de filtres à 5 champs (recherche + DRENA + type + cycle + statut) + 2 boutons ; tableau 8 colonnes (établissement, DRENA, type, cycle, statut, classes, enseignants, actions) ; ⋮ par ligne (3 entrées).
Ce qui encombre : filtres à 5 champs affichés d'emblée alors que la recherche texte suffit le plus souvent ; colonnes type et cycle quasi constantes ; 2 menus d'actions de masse dans l'en-tête qui coexistent avec l'import.
Essentiel : recherche, nom, statut, DRENA, nombres de classes et d'enseignants (pour repérer les établissements vides).
À retirer/replier/déplacer : filtres secondaires (type, cycle, DRENA) dans « Filtres ▾ » ; fusionner type + cycle dans le sous-titre du nom ; déplacer « Classes » (génération, barème) et « Codes » (régénération de masse) dans un unique menu « Actions groupées » réservé admin.
Médaille/badge : le statut est déjà un badge ; une pastille « établissement vide / à compléter » remplace les deux colonnes de compteurs, qui passent en infobulle.
Schéma simplifié :
```
Établissements (1 240)            [Importer] [Actions groupées ▾]
[ Rechercher... ]  [Filtres ▾]
Établissement        DRENA          Statut    
EPP Cocody           Abidjan 2      ● Actif        >
CEG Yopougon         Abidjan 3      ◐ À compléter  >
```
Gravité : P2. Effort : M. Parcours : 1 clic pour ouvrir une fiche (bon) ; la page cumule recherche, import et opérations de masse (multi-tâches léger).

### E-014 — Créer / modifier une annonce

- **Rôle** : enseignant (selon l'audit enseignant), direction, équipe · **Route** : `/announcements/new`, `/announcements/:id/edit` · **Vue** : `app/views/communication/authored_messages/_form.html.erb` (156 l.) · **Charge** : 4 · **Gravité** : P2 · **Effort** : S (repli `<details>`) à M

- Tâche principale : un enseignant/direction/équipe publie une annonce (titre + texte + à qui).
- Encombre : 11 champs sur un seul formulaire. Titre, texte, portée (national/école), public (2 jeux de radios), thème (palette), 8+ illustrations (plus celles de l'équipe), image, audio (avec « retirer » x2), date de publication programmée, 2 compteurs de caractères, 3 boutons.
- Essentiel : titre, texte, public, publier.
- À replier (« Personnaliser », fermé par défaut) : thème, illustration, image, audio, date programmée, portée. Brouillon : le conserver mais en lien discret.
- Médaille/badge : sans objet (aucune note).
- Schéma :
```
[Nouvelle annonce]
Titre ____________ (24/60)
Message __________ (0/280)
Pour : (o) Mes élèves ( ) Tous
[v Personnaliser : image, son, illustration, date]   <- replié
[Annuler]            [Publier]    (Brouillon: lien texte)
```
- Gravité P2 (rôles qui écrivent peu : l'enseignant n'a déjà plus accès, CA-K1) ; effort M ; écran multi-tâches (rédaction + mise en forme + média + planification).

### E-015 — Inscription enseignant

- **Rôle** : enseignant (visiteur) · **Route** : `GET /teacher-signup` · **Vue** : `app/views/identity/teacher_registrations/_form.html.erb` (122 l.) + `new`, `_school_fields`, `_school_preview` · **Charge** : 4 · **Gravité** : P2 · **Effort** : M

- Tâche principale : créer son compte enseignant et rejoindre son établissement.
- Encombre : 3 fieldsets (école, vous, sécurité) pour 8-10 champs sur une page : école (+ aperçu + champs école), matière, nom, prénom, genre, contact, PIN, confirmation PIN, compteur de correspondance PIN, case CGU/confidentialité.
- Essentiel : école, matière, nom, contact, PIN (4 chiffres).
- À retirer/déplacer : confirmation du PIN (valider par montrage/œil `reveal` déjà présent), genre (déplacer vers le profil, facultatif), prénom fusionnable avec nom (une ligne « Nom et prénoms »).
- Médaille/badge : sans objet.
- Schéma :
```
[Créer mon compte enseignant]
Mon établissement  [ choisir v ]
Ma matière         [ choisir v ]
Mon nom et prénom  [__________]
Mon téléphone      [__________]
Mon code secret    [____] (voir)
[ Créer mon compte ]  <CGU, confidentialité>
```
- Gravité P2 ; effort M (wizard 2 étapes possible : L) ; parcours long (1 page, 10 champs sur mobile = ~4 écrans de défilement).

## Écrans de charge 3 qui frôlent le 4 (à surveiller)

- **Élève** : Ma classe (6 blocs, carrousel de cours qui double la page Cours), Accueil (note /20 par ligne d'historique + « Refaire »), Archive (gros compteur + note par ligne), Aperçu d'exercice (« Meilleure note /20 », barème), Copie en cours (inhérent à la tâche).
- **Enseignant** : Catalogue `/courses` (vue unique pour 4 rôles, ≈ 15 branches), Fiche d'un cours / Cours de la classe (≈ 10 boutons « Assigner » répétés par classe).
- **Direction** : Page d'un niveau (4 chiffres × N classes), Anciens élèves (moyenne %), Inscription direction (9 champs).
- **Équipe** : Accueil (7 raccourcis), Liste des imports (8 colonnes), Formulaire d'article (≈ 10 champs), Recherche de compte (actions destructrices), Séries (liste + matrice).
- **Transverse** : Invitation équipe/direction (5 champs), Profil non-élève, Panneau « Mon compte » enseignant (≈ 10 actions), Inscription direction.

## Parcours trop longs et écrans multi-tâches

- **Assigner un exercice** (enseignant) : accueil → Cours → liste → cours → notion → modale jours → valider = **6-7 clics**. Piste : « Assigner à… » directement depuis la carte de classe.
- **Direction → classe** : accueil → niveau → classe = 3 clics ; Pilotage équipe → école = 2 à 4 clics après 7 blocs.
- **Inscription** enseignant / direction : 8-10 champs sur une page (≈ 4 écrans de défilement sur téléphone).
- **Multi-tâches** : page de classe enseignant et direction (gérer + suivre + inviter + chercher), accueil enseignant (suivi + cours + annonces + invitation), Pilotage (pilotage + annuaire de comptes + recherche d'école), fiche établissement (code + direction + classes + enseignants + demandes), résultat de session (bilan + diagnostic + remédiation + correction + relance).

## Constats annexes

- Le corrigé d'un cours (`teams/answer_keys/show`) affiche les points par question : vestige de notation à retirer.
- `catalog/courses/index` (264 l.) sert 4 rôles : extraire une vue enseignant.
- Les écrans de la partie « transverse » et de l'équipe (référentiel, CRUD) n'ont aucune note : la médaille n'y sert à rien ; le gain est de réduire les blocs.

## Ordre de traitement proposé pour demain

1. **Décision préalable (porteur, 5 min)** : valider « la médaille remplace les notes à l'affichage » et l'UDR qui amende UDR-0057/0119/0131 et ADR-0106. Sans elle, ne toucher que les replis (lots 3, 5, 6).
2. **Lot A — retirer les notes qui doublent la médaille (S, gain maximal)** : E-009 (suivi de devoir), E-008 (fiche élève), puis la ligne d'élève de E-002 (supprimer « Moyenne n/20 » et « Dernier score % »). Helpers déjà là.
3. **Lot B — E-001 résultat de session** : médaillon + un bouton principal + correction repliée (écran élève le plus vu).
4. **Lot C — accueils** : E-005 (retirer la moyenne /20 et replier l'historique), E-007 (retirer « Faits seul », légende en médailles), note /20 de l'accueil élève.
5. **Lot D — page de classe** : E-002 (menu « Gérer la classe », fiches à revoir en compteur) puis E-006 (moyenne % → médaille).
6. **Lot E — équipe, replis seuls** : E-012 (S), E-013 (M), E-003 en version « retrait + repli » (M) ; E-004 (L) à planifier sur un chantier propre.
7. **Lot F — formulaires** : E-014 (repli « Personnaliser », S), E-015 et inscription direction (retirer confirmation du PIN et genre, M).
8. **Plus tard** : E-010 (médaille par feuille), E-011 (page « Structure »), extraction de `courses/index` enseignant, parcours « Assigner » en 2 clics.

Chaque lot : une session, un commit, tests des fichiers touchés + `bin/system-changed`, captures 390 px et ordinateur envoyées au porteur.

## Annexe — captures et mesures DOM (jeu standard, local)

15 écrans capturés à 390 px et 1280 px (30 PNG, **non commités**, hors dépôt). Base de développement locale uniquement. « Cartes » = heuristique sur classes CSS ; « nombres » incluent dates et identifiants. **Seules 3 captures ont été regardées** (Ma classe élève, accueil enseignant, suivi de devoir) ; les autres descriptions viennent des mesures.

| Écran (390 px) | Liens/boutons | Cartes | Nombres | Hauteur |
|---|---|---|---|---|
| Fiche établissement (équipe) | 176 | 89 | 211 | 13 499 px |
| Accueil enseignant | 105 | 87 | 230 | 1 102 px |
| Page de classe enseignant | 50 | 11 | 126 | 3 858 px |
| Page de classe direction | 51 | 7 | 93 | 4 845 px |
| Suivi d'un devoir | 48 | 6 | 82 | 4 298 px |
| Ma classe (élève) | 25 | 98 | 56 | 3 353 px |
| Activité école (direction) | 10 | 0 | 39 | 4 544 px (13 282 px à 1280) |
| Résultat de session | 8 | 9 | 30 | 3 343 px |
| Croissance (équipe) | 16 | 10 | 25 | 1 830 px |
| Accueil élève | 16 | 2 | 10 | 1 069 px |

Observations visuelles : accueil enseignant = carrousel de classes + grille de 14 niveaux en icônes identiques + 105 liens ; Ma classe élève = 10 cartes « Prépare interros » identiques à répéter ; suivi de devoir = liste de 35 lignes « Pas encore fait » répétitives (à regrouper en un compteur) ; la fiche établissement fait ≈ 13 500 px sur téléphone, ce qui confirme E-004 ; l'activité école (13 282 px sur ordinateur) n'avait pas été notée charge 4 par les agents et mérite un plafond de lignes ou une pagination (nouveau constat, P2, S).
